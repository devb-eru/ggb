param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1,1800)][int]$TimeoutSeconds=1200,
    [switch]$Async,
    [switch]$Baseline,
    [ValidateSet('original','flip_only')][string]$BaselineKind='original'
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
$dir=Join-Path $project ('__sheet_disclosure_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir|Out-Null
$harnesses=@()
foreach($name in @('notebook_sheet_disclosure_audit.gd','notebook_sheet_disclosure_audit.tscn')){
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
    $arguments=@('--headless','--verbose','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_sheet_disclosure_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--notebook-require-authored')
    if($Async){$arguments+='--ggb-dev-notebook-async'}
    $started=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ('SHEET_DISCLOSURE PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $unchanged=[string]::Join("`n",$source) -ceq [string]::Join("`n",(Get-Corpus 'scripts' '*.gd'))
    $dataUnchanged=[string]::Join("`n",$data) -ceq [string]::Join("`n",(Get-Corpus 'data' '*'))
    $receipt=@{completed=$finished;exit_code=$child.ExitCode;pid=$child.Id;arguments=$arguments;async=[bool]$Async;baseline=[bool]$Baseline;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;source_corpus=@{file_count=$source.Count;rows=$source};data_corpus=@{file_count=$data.Count;rows=$data};source_unchanged=$unchanged;data_unchanged=$dataUnchanged;stdout_sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $err).Hash.ToLowerInvariant()}
    $receipt.baseline_kind=$BaselineKind
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or -not $unchanged -or -not $dataUnchanged -or (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet)){throw 'Script/lifetime/source failure; raw evidence retained'}
    $summaries=@(Get-Content -LiteralPath $out|Where-Object {$_.StartsWith('NOTEBOOK_SHEET_DISCLOSURE_AUDIT: ')})
    if($summaries.Count -ne 1){throw 'Ambiguous disclosure result'}
    $result=$summaries[0].Substring('NOTEBOOK_SHEET_DISCLOSURE_AUDIT: '.Length)|ConvertFrom-Json
    $snapshots=@(Get-ChildItem -LiteralPath (Join-Path $evidence 'appdata') -Directory -Recurse -Filter '__test_nb_sheet_disclosure_evidence')
    if($snapshots.Count -ne 1){throw 'Native snapshot directory missing or ambiguous'}
    Copy-Item -LiteralPath $snapshots[0].FullName -Destination (Join-Path $evidence 'snapshots') -Recurse
    [IO.File]::WriteAllText((Join-Path $evidence 'result.json'),($result|ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
    if(@($result.cases).Count -ne 12){throw 'Disclosure case denominator mismatch'}
    if($Baseline){
        $failed=@($result.cases|Where-Object {-not $_.ok})
        if($child.ExitCode -ne 1 -or $result.ok){throw 'Expected baseline failure absent'}
        if($BaselineKind -eq 'flip_only'){
            if($failed.Count -ne 8 -or @($failed|Where-Object {$_.id -notmatch '^(c5_|j3_skip/)'}).Count){throw 'Flip-only control does not isolate the expected eight source/memory failures'}
        }elseif($failed.Count -ne 12 -or @($result.errors|Where-Object {$_.check -ceq 'j3_flip_page: displayed line failed to persist'}).Count -ne 6){throw 'Original baseline did not reproduce the recorded flip-page barrier'}
    }elseif($null -eq $child.ExitCode -or $child.ExitCode -ne 0 -or -not $result.ok -or @($result.errors).Count){throw 'Disclosure candidate failed'}
    [pscustomobject]@{checks=$result.checks;cases=$result.cases.Count;errors=@($result.errors).Count;native=$child.ExitCode;baseline=[bool]$Baseline;async=[bool]$Async}|ConvertTo-Json
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
