param(
    [Parameter(Mandatory)][ValidateSet('seed','resume','verify')][string]$Phase,
    [Parameter(Mandatory)][ValidateSet('p6','chapter','mirror','basement','bedroom','capsule','rest')][string]$Route,
    [Parameter(Mandatory)][ValidateSet('sleep_confirmed','player_committed','memory_committed','physical_reset_complete','morning_loaded','route_selected','complete','idle','wake')][string]$Point,
    [Parameter(Mandatory)][ValidateSet('prepared','promoted')][string]$Cut,
    [Parameter(Mandatory)][ValidateSet('ko_KR','en_US')][string]$Locale,
    [Parameter(Mandatory)][string]$SharedProfile,
    [Parameter(Mandatory)][string]$CasePath,
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1,1800)][int]$TimeoutSeconds=120
)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$profile=[IO.Path]::GetFullPath($SharedProfile)
$case=[IO.Path]::GetFullPath($CasePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
foreach($path in @($project,$evidence,$profile,$case)){
    if(-not ($path+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Use isolated TEMP paths'}
}
if((Test-Path -LiteralPath $evidence) -or ($Phase -eq 'seed' -and ((Test-Path -LiteralPath $profile) -or (Test-Path -LiteralPath $case))) -or ($Phase -ne 'seed' -and (-not (Test-Path -LiteralPath $profile) -or -not (Test-Path -LiteralPath (Join-Path $case 'cut.json'))))){throw 'Evidence/profile/case phase conflict'}
if(($Route -eq 'p6' -and $Point -eq 'wake') -or ($Route -eq 'rest' -and $Point -ne 'wake')){throw 'Unsupported persistence boundary'}
function Get-Corpus {
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -File -Recurse | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
function Get-Digest([string]$Path){if(Test-Path -LiteralPath $Path -PathType Leaf){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}else{''}}
New-Item -ItemType Directory -Path $evidence | Out-Null
if($Phase -eq 'seed'){New-Item -ItemType Directory -Path $case | Out-Null}
$cutBefore=Get-Digest (Join-Path $case 'cut.json')
$source=Get-Corpus
$dir=Join-Path $project ('__reset_process_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$harnesses=@()
foreach($name in @('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_surface_async_audit.gd','notebook_prologue_natural_async_audit.gd','notebook_reset_async_audit.gd','notebook_reset_ui_audit.gd','notebook_campaign_sleep_audit.gd','notebook_reset_process_audit.gd','notebook_reset_process_audit.tscn')){
    $target=Join-Path $dir $name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $target
    Copy-Item -LiteralPath $target -Destination (Join-Path $evidence $name)
    $harnesses+=[ordered]@{name=$name;sha256=Get-Digest $target}
}
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $evidence 'runner.ps1')
$out=Join-Path $evidence 'run.out.log'
$err=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA
$oldLocal=$env:LOCALAPPDATA
$child=$null
$terminated=$false
$finished=$false
$failure=''
$result=$null
try {
    $env:APPDATA=Join-Path $profile 'appdata'
    $env:LOCALAPPDATA=Join-Path $profile 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    $version=(& $engine --headless --version | Out-String).Trim()
    if($LASTEXITCODE -ne 0){throw 'Engine version failed'}
    $start=[DateTime]::UtcNow.ToString('o')
    $argsList=@('--headless','--verbose','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_reset_process_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored',('--reset-process-phase='+$Phase),('--reset-process-route='+$Route),('--reset-process-point='+$Point),('--reset-process-cut='+$Cut),('--reset-process-dir="'+$case+'"'),('--reset-process-locale='+$Locale))
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ('Reset process '+$Route+'/'+$Point+'/'+$Cut+'/'+$Phase+' PID='+$child.Id)
    if($Phase -eq 'seed'){
        $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while(-not $child.HasExited -and [DateTime]::UtcNow -lt $deadline){
            if((Test-Path -LiteralPath (Join-Path $case 'cut.json')) -and (Select-String -LiteralPath $out -Pattern '^RESET_PROCESS_CUT: ' -Quiet)){
                $result=Get-Content -LiteralPath (Join-Path $case 'cut.json') -Raw | ConvertFrom-Json
                if(-not $result.ok -or @($result.errors).Count -or $result.pid -ne $child.Id -or $result.phase -cne $Point -or $result.cut -cne $Cut){throw 'Cut receipt mismatch'}
                if($child.HasExited){throw 'Cut child exited before intentional termination'}
                $child.Kill()
                $child.WaitForExit()
                $terminated=$true
                $finished=$true
                break
            }
            Start-Sleep -Milliseconds 50
        }
        if(-not $terminated){throw 'Expected live persistence cut not reached'}
        if($null -eq $child.ExitCode -or $child.ExitCode -eq 0){throw 'Intentional termination must retain nonzero native exit'}
    }else{
        $finished=$child.WaitForExit($TimeoutSeconds*1000)
        if(-not $finished){throw 'Process recovery timeout'}
        if($null -eq $child.ExitCode -or $child.ExitCode -ne 0){throw 'Native recovery failed'}
        $lines=@(Get-Content -LiteralPath $out)
        if(@($lines | Where-Object {$_ -ceq 'RESET_PROCESS_SMOKE:PASS'}).Count -ne 1){throw 'Exact PASS missing'}
        $summaries=@($lines | Where-Object {$_.StartsWith('RESET_PROCESS_AUDIT: ')})
        if($summaries.Count -ne 1){throw 'Ambiguous process summary'}
        $result=$summaries[0].Substring('RESET_PROCESS_AUDIT: '.Length) | ConvertFrom-Json
        if(-not $result.ok -or @($result.errors).Count -or $result.phase -cne $Phase -or $result.route -cne $Route -or $result.point -cne $Point -or $result.cut -cne $Cut -or $result.locale -cne $Locale){throw 'Recovery result mismatch'}
        if((Get-Digest (Join-Path $case 'cut.json')) -cne $cutBefore){throw 'Immutable cut evidence changed'}
    }
    if(Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet){throw 'Script/native warning failure'}
    if(($source | ConvertTo-Json -Depth 6 -Compress) -cne ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress)){throw 'Product source changed during execution'}
}catch{
    $failure=$_.Exception.Message
}finally{
    if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{ok=($failure -eq '');failure=$failure;profile=$profile;case_path=$case;phase=$Phase;route=$Route;point=$Point;cut=$Cut;locale=$Locale;completed=$finished;terminated_by_runner=$terminated;pid=if($child){$child.Id}else{$null};exit_code=if($child){$child.ExitCode}else{$null};started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');
        engine_version=$version;engine_sha256=Get-Digest $engine;runner_sha256=Get-Digest $PSCommandPath;harnesses=$harnesses;source_corpus=$source;source_unchanged=(($source | ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress));
        stdout_sha256=Get-Digest $out;stderr_sha256=Get-Digest $err;cut_sha256=Get-Digest (Join-Path $case 'cut.json');details_sha256=Get-Digest (Join-Path $case ($Phase+'_details.json'));resumed_sha256=Get-Digest (Join-Path $case 'resumed_snapshot.json')}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if($null -ne $result){[IO.File]::WriteAllText((Join-Path $evidence 'run.result.json'),($result | ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))}
    $env:APPDATA=$oldApp
    $env:LOCALAPPDATA=$oldLocal
}
if($failure){throw $failure}
[pscustomobject]@{route=$Route;point=$Point;cut=$Cut;phase=$Phase;locale=$Locale;checks=$result.checks;terminated=$terminated;native=$receipt.exit_code} | ConvertTo-Json
