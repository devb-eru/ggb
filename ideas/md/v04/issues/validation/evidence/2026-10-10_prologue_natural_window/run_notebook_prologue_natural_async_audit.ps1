param([Parameter(Mandatory)][string]$EnginePath,[Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$EvidencePath,[ValidateRange(1,1800)][int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
function Get-Corpus {
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence | Out-Null
$source=Get-Corpus
$dir=Join-Path $project ('__natural_async_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$names=@('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_surface_async_audit.gd','notebook_prologue_natural_async_audit.gd','notebook_prologue_natural_async_audit.tscn')
$harnesses=@()
foreach($name in $names){
    $destination=Join-Path $dir $name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $destination
    $harnesses+= [ordered]@{name=$name;sha256=(Get-FileHash -LiteralPath $destination).Hash.ToLowerInvariant()}
}
$stdout=Join-Path $evidence 'focused.out.log'
$stderr=Join-Path $evidence 'focused.err.log'
$oldApp=$env:APPDATA
$oldLocal=$env:LOCALAPPDATA
$child=$null
try {
    $env:APPDATA=Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $version=(& $engine --headless --version | Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $argsList=@('--headless','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_prologue_natural_async_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored')
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ('Natural PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');engine_version=$version;
        engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();
        harnesses=$harnesses;source_corpus=$source;source_unchanged=(($source | ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress));
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'focused.run.json'),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)){throw 'Native/script/source failure'}
    $lines=@(Get-Content -LiteralPath $stdout)
    if(@($lines | Where-Object {$_ -ceq 'PROLOGUE_NATURAL_ASYNC_SMOKE:PASS'}).Count -ne 1){throw 'PASS marker missing'}
    $summary=@($lines | Where-Object {$_.StartsWith('PROLOGUE_NATURAL_ASYNC_AUDIT: ')})
    if($summary.Count -ne 1){throw 'Ambiguous result'}
    $result=$summary[0].Substring('PROLOGUE_NATURAL_ASYNC_AUDIT: '.Length) | ConvertFrom-Json
    if(-not $result.ok -or $result.required_cases -ne 14 -or @($result.cases).Count -ne 14){throw 'Result/denominator mismatch'}
    [IO.File]::WriteAllText((Join-Path $evidence 'focused.result.json'),($result | ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
    [pscustomobject]@{checks=$result.checks;cases=$result.cases.Count;native=$child.ExitCode} | ConvertTo-Json
} finally {
    if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()}
    $env:APPDATA=$oldApp
    $env:LOCALAPPDATA=$oldLocal
}
