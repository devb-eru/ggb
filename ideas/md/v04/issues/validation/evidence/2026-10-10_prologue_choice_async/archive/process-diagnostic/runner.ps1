param([Parameter(Mandatory)][ValidateSet('seed','resume','verify_response')][string]$Phase,[Parameter(Mandatory)][ValidateSet('p3_journal','p4_father','P1_EXIT','P6_SLEEP')][string]$Mode,[Parameter(Mandatory)][ValidateSet('ko_KR','en_US')][string]$Locale,[Parameter(Mandatory)][string]$SharedProfile,[Parameter(Mandatory)][string]$EnginePath,[Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$EvidencePath,[ValidateRange(1,1800)][int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
$profile=[IO.Path]::GetFullPath($SharedProfile)
if(-not ($profile+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Profile must be isolated TEMP'}
if($Phase -eq 'seed' -and (Test-Path -LiteralPath $profile)){throw 'Seed requires new profile'}
if($Phase -ne 'seed' -and -not (Test-Path -LiteralPath $profile)){throw 'Resume requires seeded profile'}
function Get-Corpus{
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence|Out-Null
$source=Get-Corpus
$dir=Join-Path $project ('__history_async_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir|Out-Null
foreach($name in @('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_choice_async_audit.gd','notebook_prologue_choice_process_audit.gd','notebook_prologue_choice_process_audit.tscn')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $dir}
$stdout=Join-Path $evidence 'run.out.log';$stderr=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $profile 'appdata';$env:LOCALAPPDATA=Join-Path $profile 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force|Out-Null
    $version=(& $engine --headless --version|Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $argsList=@('--headless','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_prologue_choice_process_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored',('--choice-phase='+$Phase),('--choice-mode='+$Mode),('--choice-locale='+$Locale))
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ('Focused PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{profile=$profile;phase=$Phase;mode=$Mode;locale=$Locale;completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');
        engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();
        runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();
        base_harness_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_history_async_audit.gd')).Hash.ToLowerInvariant();
        parent_harness_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_prologue_async_audit.gd')).Hash.ToLowerInvariant();
        choice_harness_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_prologue_choice_async_audit.gd')).Hash.ToLowerInvariant();
        harness_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_prologue_choice_process_audit.gd')).Hash.ToLowerInvariant();
        scene_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_prologue_choice_process_audit.tscn')).Hash.ToLowerInvariant();
        source_corpus=$source;source_unchanged=(($source|ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus)|ConvertTo-Json -Depth 6 -Compress));
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)){throw 'Native/script/source failure'}
    $lines=@(Get-Content -LiteralPath $stdout)
    if(@($lines|Where-Object {$_ -ceq 'PROLOGUE_CHOICE_PROCESS_SMOKE:PASS'}).Count -ne 1){throw 'PASS marker missing'}
    $summary=@($lines|Where-Object {$_.StartsWith('PROLOGUE_CHOICE_PROCESS_AUDIT: ')})
    if($summary.Count -ne 1){throw 'Ambiguous result'}
    $result=$summary[0].Substring('PROLOGUE_CHOICE_PROCESS_AUDIT: '.Length)|ConvertFrom-Json
    if(-not $result.ok -or @($result.errors).Count -ne 0 -or $result.phase -cne $Phase -or $result.mode -cne $Mode -or $result.locale -cne $Locale){throw 'Process result mismatch'}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.result.json'),($result|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
    [pscustomobject]@{phase=$Phase;mode=$Mode;locale=$Locale;checks=$result.checks;native=$child.ExitCode}|ConvertTo-Json
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
