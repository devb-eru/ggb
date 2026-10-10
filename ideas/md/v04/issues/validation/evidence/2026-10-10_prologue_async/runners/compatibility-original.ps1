param([Parameter(Mandatory)][string]$EnginePath,[Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('prologue','cursor_seed','cursor_reload')][string]$Mode='prologue',[string]$SharedProfile='',
    [ValidateRange(1,1800)][int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
function Get-Corpus{
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence|Out-Null
$profile=$evidence
if($Mode -ne 'prologue'){
    if([string]::IsNullOrEmpty($SharedProfile)){throw 'Cursor pair needs explicit shared TEMP profile'}
    $profile=[IO.Path]::GetFullPath($SharedProfile)
    if(-not ($profile+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Shared profile outside TEMP'}
    if($Mode -eq 'cursor_seed' -and (Test-Path -LiteralPath $profile)){throw 'Seed needs new shared profile'}
    if($Mode -eq 'cursor_reload' -and -not (Test-Path -LiteralPath $profile)){throw 'Reload needs seeded shared profile'}
}
$source=Get-Corpus
$out=Join-Path $evidence 'run.out.log';$err=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $profile 'appdata';$env:LOCALAPPDATA=Join-Path $profile 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force|Out-Null
    $argsList=@('--headless','--path',('"'+$project+'"'),'--','--ggb-dev-notebook-v2','--notebook-require-authored')
    if($Mode -eq 'prologue'){$argsList+='--notebook-prologue-smoke'}else{$argsList+=@('--notebook-prologue-presentation-smoke',('--cursor-phase='+$(if($Mode -eq 'cursor_seed'){'seed'}else{'reload'})))}
    $version=(& $engine --headless --version|Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ($Mode+' PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{mode=$Mode;completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');
        engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();
        source_corpus=$source;source_unchanged=(($source|ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus)|ConvertTo-Json -Depth 6 -Compress));
        profile=$profile;stdout_sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $err).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)){throw 'Native/script/source failure'}
    $lines=@(Get-Content -LiteralPath $out)
    $marker=if($Mode -eq 'prologue'){'NOTEBOOK_PROLOGUE_SMOKE: PASS'}else{'NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'}
    $passed=if($Mode -eq 'prologue'){@($lines|Where-Object {$_.StartsWith($marker+' ')})}else{@($lines|Where-Object {$_ -ceq $marker})}
    if($passed.Count -ne 1){throw 'Exact PASS missing'}
    $lines|Where-Object {$_ -match 'CHECKS:|SMOKE:|^NOTEBOOK_PROLOGUE_RESULT:'}
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
