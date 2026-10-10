param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1,1800)][int]$TimeoutSeconds=1200,
    [switch]$Baseline
)
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
$dir=Join-Path $project ('__reset_owner_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$names=@('notebook_history_async_audit.gd','notebook_reset_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_surface_async_audit.gd','notebook_prologue_natural_async_audit.gd','notebook_reset_ui_audit.gd','notebook_reset_owner_audit.gd','notebook_reset_owner_audit.tscn')
$harnesses=@()
foreach($name in $names){
    $destination=Join-Path $dir $name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $destination
    Copy-Item -LiteralPath $destination -Destination (Join-Path $evidence $name)
    $harnesses+=@{name=$name;sha256=(Get-FileHash -LiteralPath $destination).Hash.ToLowerInvariant()}
}
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $evidence 'runner.ps1')
$argsList=@('--headless','--verbose','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_reset_owner_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored')
if($Baseline){$argsList+='--reset-owner-baseline'}
$stdout=Join-Path $evidence 'run.out.log';$stderr=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $evidence 'appdata';$env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $version=(& $engine --headless --version | Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ('Reset owner PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{baseline=[bool]$Baseline;completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;source_corpus=$source;source_unchanged=(($source | ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress));stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    $lines=@(Get-Content -LiteralPath $stdout)
    $summary=@($lines | Where-Object {$_.StartsWith('RESET_OWNER_AUDIT: ')})
    if($summary.Count -eq 1){
        $result=$summary[0].Substring('RESET_OWNER_AUDIT: '.Length) | ConvertFrom-Json
        [IO.File]::WriteAllText((Join-Path $evidence 'run.result.json'),($result | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    }
    if(-not $finished -or $null -eq $child.ExitCode -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|Leaked instance|resources still in use|Orphan StringName' -Quiet)){throw 'Native/script/source/lifetime failure; raw evidence preserved'}
    $count=if($Baseline){12}else{136}
    if($summary.Count -ne 1 -or @($lines | Where-Object {$_ -ceq 'RESET_OWNER_SMOKE:PASS'}).Count -ne 1 -or -not $result.ok -or $result.required_cases -ne $count -or @($result.cases).Count -ne $count){throw 'Result/denominator mismatch'}
    [pscustomobject]@{checks=$result.checks;cases=$result.cases.Count;native=$child.ExitCode}
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
