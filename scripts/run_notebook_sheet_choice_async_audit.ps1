param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1,1800)][int]$TimeoutSeconds=900
)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
function Get-Corpus([string]$Directory,[string]$Filter){
    @(Get-ChildItem -LiteralPath (Join-Path $project $Directory) -Recurse -Filter $Filter -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
}
New-Item -ItemType Directory -Path $evidence|Out-Null
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $evidence 'runner.ps1')
$source=Get-Corpus 'scripts' '*.gd';$data=Get-Corpus 'data' '*'
$dir=Join-Path $project ('__sheet_choice_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir|Out-Null
$harnesses=@()
foreach($name in @('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_choice_async_audit.gd','notebook_sheet_choice_async_audit.gd','notebook_sheet_choice_async_audit.tscn')){
    $target=Join-Path $dir $name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $target
    Copy-Item -LiteralPath $target -Destination (Join-Path $evidence $name)
    $harnesses+=@{name=$name;sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()}
}
$out=Join-Path $evidence 'run.out.log';$err=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $evidence 'appdata';$env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA|Out-Null
    $arguments=@('--headless','--verbose','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_sheet_choice_async_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored')
    $started=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ('SHEET_CHOICE PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $unchanged=[string]::Join("`n",$source) -ceq [string]::Join("`n",(Get-Corpus 'scripts' '*.gd'))
    $dataUnchanged=[string]::Join("`n",$data) -ceq [string]::Join("`n",(Get-Corpus 'data' '*'))
    $receipt=@{completed=$finished;exit_code=$child.ExitCode;pid=$child.Id;arguments=$arguments;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;source_corpus=@{file_count=$source.Count;rows=$source};data_corpus=@{file_count=$data.Count;rows=$data};source_unchanged=$unchanged;data_unchanged=$dataUnchanged;stdout_sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $err).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $null -eq $child.ExitCode -or $child.ExitCode -ne 0 -or -not $unchanged -or -not $dataUnchanged -or (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet)){throw 'Native/script/lifetime/source failure; raw evidence retained'}
    $lines=@(Get-Content -LiteralPath $out)
    if(@($lines|Where-Object {$_ -ceq 'SHEET_CHOICE_ASYNC_SMOKE:PASS'}).Count -ne 1){throw 'PASS marker missing'}
    $summaries=@($lines|Where-Object {$_.StartsWith('SHEET_CHOICE_ASYNC_AUDIT: ')})
    if($summaries.Count -ne 1){throw 'Ambiguous result'}
    $result=$summaries[0].Substring('SHEET_CHOICE_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
    if(-not $result.ok -or $result.required_cases -ne 56 -or @($result.cases).Count -ne 56 -or @($result.errors).Count){throw 'Result or denominator failure'}
    [IO.File]::WriteAllText((Join-Path $evidence 'result.json'),($result|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    [pscustomobject]@{checks=$result.checks;cases=$result.cases.Count;native=$child.ExitCode;source_files=$source.Count;data_files=$data.Count}|ConvertTo-Json
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
