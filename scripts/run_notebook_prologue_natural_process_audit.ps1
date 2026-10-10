param([Parameter(Mandatory)][ValidateSet('seed','resume','verify')][string]$Phase,[Parameter(Mandatory)][ValidateSet('brush','water')][string]$Mode,[Parameter(Mandatory)][ValidateSet('ko_KR','en_US')][string]$Locale,[Parameter(Mandatory)][string]$SharedProfile,[Parameter(Mandatory)][string]$EnginePath,[Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$EvidencePath,[ValidateRange(1,1800)][int]$TimeoutSeconds=120)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$profile=[IO.Path]::GetFullPath($SharedProfile)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
foreach($path in @($project,$evidence,$profile)){if(-not ($path+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Use isolated TEMP paths'}}
if((Test-Path -LiteralPath $evidence) -or ($Phase -eq 'seed' -and (Test-Path -LiteralPath $profile)) -or ($Phase -ne 'seed' -and -not (Test-Path -LiteralPath $profile))){throw 'Evidence/profile phase conflict'}
function Get-Corpus {
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -File -Recurse | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence | Out-Null
$source=Get-Corpus
$dir=Join-Path $project ('__natural_process_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$harnesses=@()
foreach($name in @('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_surface_async_audit.gd','notebook_prologue_natural_async_audit.gd','notebook_prologue_natural_process_audit.gd','notebook_prologue_natural_process_audit.tscn')){
    $target=Join-Path $dir $name
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $target
    $harnesses+=[ordered]@{name=$name;sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()}
}
$out=Join-Path $evidence 'run.out.log'
$err=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA
$oldLocal=$env:LOCALAPPDATA
$child=$null
try {
    $env:APPDATA=Join-Path $profile 'appdata'
    $env:LOCALAPPDATA=Join-Path $profile 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    $version=(& $engine --headless --version | Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $argsList=@('--headless','--path',('"'+$project+'"'),('"'+(Join-Path $dir 'notebook_prologue_natural_process_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored',('--natural-phase='+$Phase),('--natural-mode='+$Mode),('--natural-locale='+$Locale))
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ('Natural '+$Mode+'/'+$Phase+' PID='+$child.Id)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{profile=$profile;phase=$Phase;mode=$Mode;locale=$Locale;completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');
        engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;
        source_corpus=$source;source_unchanged=(($source | ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress));
        stdout_sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $err).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)){throw 'Native/script/source failure'}
    $lines=@(Get-Content -LiteralPath $out)
    if(@($lines | Where-Object {$_ -ceq 'PROLOGUE_NATURAL_PROCESS_SMOKE:PASS'}).Count -ne 1){throw 'Exact PASS missing'}
    $summary=@($lines | Where-Object {$_.StartsWith('PROLOGUE_NATURAL_PROCESS_AUDIT: ')})
    if($summary.Count -ne 1){throw 'Ambiguous result'}
    $result=$summary[0].Substring('PROLOGUE_NATURAL_PROCESS_AUDIT: '.Length) | ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $evidence 'run.result.json'),($result | ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
    if(-not $result.ok -or @($result.errors).Count -or $result.phase -cne $Phase -or $result.mode -cne $Mode -or $result.locale -cne $Locale){throw 'Process result mismatch'}
    [pscustomobject]@{mode=$Mode;phase=$Phase;locale=$Locale;checks=$result.checks;native=$child.ExitCode} | ConvertTo-Json
} finally {
    if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()}
    $env:APPDATA=$oldApp
    $env:LOCALAPPDATA=$oldLocal
}
