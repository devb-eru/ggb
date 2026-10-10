param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$TemplateRoot,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('build','startup','probe')][string]$Mode = 'build',
    [string]$ExecutablePath,
    [string]$ProbeScene,
    [ValidateSet('ko-KR','en-US')][string]$Locale = 'ko-KR',
    [ValidateRange(1,7200)][int]$TimeoutSeconds = 1200
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'godot_windows_template_policy.ps1')
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
function Under-Temp([string]$Path) {
    if (-not ([IO.Path]::GetFullPath($Path)+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)) {throw 'Use isolated TEMP paths'}
}
function Sha([string]$Path) {(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
Under-Temp $engine;Under-Temp $project;Under-Temp $TemplateRoot;Under-Temp $evidence
if (Test-Path -LiteralPath $evidence) {throw 'Use a new evidence directory'}
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {throw 'Project required'}
$version=(& $engine --headless --version|Out-String).Trim()
if ($LASTEXITCODE -ne 0) {throw 'Cannot read runtime version'}
$templates=Get-GodotWindowsTemplateDirectory -TemplateRoot $TemplateRoot -RuntimeVersion $version -Configuration release
$paths=@(Get-ChildItem -LiteralPath $project -File -Recurse|Where-Object {$_.FullName -notlike ($project+'\.godot\*')}|ForEach-Object FullName)
[Array]::Sort($paths,[StringComparer]::Ordinal)
$rows=@($paths|ForEach-Object {$_.Substring($project.Length+1).Replace('\','/')+"`t"+(Sha $_)})
[IO.Directory]::CreateDirectory($evidence)|Out-Null
$appdata=Join-Path $evidence 'appdata'
$localdata=Join-Path $evidence 'localappdata'
[IO.Directory]::CreateDirectory($appdata)|Out-Null
[IO.Directory]::CreateDirectory($localdata)|Out-Null
$targetTemplates=Join-Path $appdata ('Godot/export_templates/'+(Split-Path -Leaf $templates))
[IO.Directory]::CreateDirectory((Split-Path -Parent $targetTemplates))|Out-Null
Copy-Item -LiteralPath $templates -Destination $targetTemplates -Recurse
$receipt=[ordered]@{schema_version=1;mode=$Mode;locale=$Locale;engine_version=$version;engine_sha256=(Sha $engine);template_version=(Get-Content (Join-Path $templates 'version.txt') -Raw).Trim();template_sha256=(Sha (Join-Path $templates 'windows_release_x86_64.exe'));runner_sha256=(Sha $PSCommandPath);source_rows=$rows;steps=@()}
function Run-Native([string]$Id,[string]$Exe,[string[]]$Arguments) {
    $stdout=Join-Path $evidence ($Id+'.out.log')
    $stderr=Join-Path $evidence ($Id+'.err.log')
    $started=[DateTime]::UtcNow.ToString('o')
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Exe
    $start.WorkingDirectory=$evidence
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $start.Environment['APPDATA']=$appdata
    $start.Environment['LOCALAPPDATA']=$localdata
    foreach ($argument in $Arguments) {$start.ArgumentList.Add($argument)}
    $child=[Diagnostics.Process]::Start($start)
    $out=$child.StandardOutput.ReadToEndAsync()
    $err=$child.StandardError.ReadToEndAsync()
    Write-Output ($Id+': PID='+$child.Id+' evidence='+$evidence)
    $finished=$false
    try {
        $finished=$child.WaitForExit($TimeoutSeconds*1000)
        if (-not $finished) {$child.Kill();$child.WaitForExit()}
    } finally {
        if (-not $child.HasExited) {$child.Kill();$child.WaitForExit()}
        [IO.File]::WriteAllText($stdout,$out.GetAwaiter().GetResult(),[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderr,$err.GetAwaiter().GetResult(),[Text.UTF8Encoding]::new($false))
        $receipt.steps+=@{id=$Id;pid=$child.Id;arguments=$Arguments;executable_sha256=(Sha $Exe);completed=$finished;exit_code=$child.ExitCode;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');stdout_sha256=(Sha $stdout);stderr_sha256=(Sha $stderr)}
        $child.Dispose()
    }
    $step=$receipt.steps[-1]
    if (-not $step.completed -or $step.exit_code -ne 0 -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -Quiet)) {throw ('Native release step failed: '+$Id)}
}
try {
    if ($Mode -eq 'build') {
        Run-Native 'import' $engine @('--headless','--path',$project,'--editor','--import')
        $exe=Join-Path $evidence 'GGB_release.exe'
        Run-Native 'export' $engine @('--headless','--path',$project,'--export-release','Windows Desktop Debug',$exe)
    } else {
        $exe=(Resolve-Path -LiteralPath $ExecutablePath).Path
        Under-Temp $exe
        $empty=Join-Path $evidence 'empty'
        [IO.Directory]::CreateDirectory($empty)|Out-Null
        $args=@('--headless','--path',$empty,'--main-pack',[IO.Path]::ChangeExtension($exe,'.pck'))
        if ($Mode -eq 'startup') {
            Run-Native 'startup' $exe ($args+@('--quit-after','90','--','--ggb-dev-notebook-v2','--foundation-smoke','--dev-jump=CREDITS_REALITY'))
            $log=Get-Content -LiteralPath (Join-Path $evidence 'startup.out.log') -Raw
            if ($log -notmatch 'GGB title bootstrap initialized\.' -or $log -match 'FOUNDATION_SMOKE: PASS|GGB development full mode') {throw 'Release entry/debug gate mismatch'}
        } else {
            $probe=(Resolve-Path -LiteralPath $ProbeScene).Path
            Under-Temp $probe
            $receipt.probe_scene_sha256=Sha $probe
            $receipt.probe_script_sha256=Sha (Join-Path (Split-Path -Parent $probe) 'windows_release_probe.gd')
            Run-Native 'probe' $exe ($args+@($probe,'--','--ggb-dev-notebook-v2','--foundation-smoke','--dev-jump=CREDITS_REALITY',('--release-probe-locale='+$Locale)))
            $raw=@(Get-Content -LiteralPath (Join-Path $evidence 'probe.out.log')|Where-Object {$_.StartsWith('WINDOWS_RELEASE_PROBE: ')})
            if ($raw.Count -ne 1) {throw 'Release probe summary missing'}
            $result=$raw[0].Substring('WINDOWS_RELEASE_PROBE: '.Length)|ConvertFrom-Json
            [IO.File]::WriteAllText((Join-Path $evidence 'probe.result.json'),($result|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
            if (-not $result.ok -or $result.debug_build -ne $false -or $result.locale -cne $Locale -or @($result.errors).Count) {throw 'Release probe failed'}
        }
    }
    $pack=[IO.Path]::ChangeExtension($exe,'.pck')
    if (-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath $pack)) {throw 'EXE/PCK missing'}
    $receipt.exe_sha256=Sha $exe
    $receipt.pack_sha256=Sha $pack
    $receipt.exe_bytes=(Get-Item -LiteralPath $exe).Length
    $receipt.pack_bytes=(Get-Item -LiteralPath $pack).Length
    $receipt.source_unchanged= -not @($paths|Where-Object {($_.Substring($project.Length+1).Replace('\','/')+"`t"+(Sha $_)) -cnotin $rows}).Count
    if (-not $receipt.source_unchanged) {throw 'Product source changed'}
    $receipt.ok=$true
} catch {$receipt.ok=$false;$receipt.failure=$_.Exception.Message;throw} finally {
    [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.run.json')),($receipt|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
}
$receipt|Select-Object mode,ok,exe_sha256,pack_sha256,source_unchanged|ConvertTo-Json
