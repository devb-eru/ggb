param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('focused','migration','host')][string]$Mode = 'focused',
    [ValidateRange(1,1800)][int]$TimeoutSeconds = 900
)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$evidence = [IO.Path]::GetFullPath($EvidencePath)
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Use isolated TEMP project' }
if (-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use new TEMP evidence directory' }
function Get-Corpus {
    $rows = @(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    })
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
    [ordered]@{file_count=$rows.Count;sha256=$hash;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence | Out-Null
$source = Get-Corpus
$argsList = @('--headless','--path',('"'+$project+'"'))
$harness = $null
if ($Mode -eq 'focused') {
    $dir = Join-Path $project ('__save_preflight_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    foreach ($name in @('notebook_save_preflight_audit.gd','notebook_save_preflight_audit.tscn')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $dir
    }
    $harness = (Get-FileHash -LiteralPath (Join-Path $dir 'notebook_save_preflight_audit.gd')).Hash.ToLowerInvariant()
    $argsList += ('"'+(Join-Path $dir 'notebook_save_preflight_audit.tscn')+'"')
}
$argsList += @('--','--ggb-dev-notebook-v2','--notebook-require-authored')
if ($Mode -ne 'focused') { $argsList += $(switch ($Mode) { 'migration' {'--notebook-migration-smoke'} 'host' {'--notebook-host-smoke'} }) }
$stdout = Join-Path $evidence ($Mode+'.out.log')
$stderr = Join-Path $evidence ($Mode+'.err.log')
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA
$child = $null
try {
    $env:APPDATA = Join-Path $evidence 'appdata'; $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $version = (& $engine --headless --version | Out-String).Trim()
    $started = [DateTime]::UtcNow.ToString('o')
    $child = Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ($Mode+': PID='+$child.Id+' evidence='+$evidence)
    $finished = $child.WaitForExit($TimeoutSeconds*1000)
    if (-not $finished) { $child.Kill(); $child.WaitForExit() }
    $receipt = [ordered]@{mode=$Mode;completed=$finished;exit_code=$child.ExitCode;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');
        engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();
        runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harness_sha256=$harness;
        source_corpus=$source;source_unchanged=(($source|ConvertTo-Json -Depth 5 -Compress) -ceq ((Get-Corpus)|ConvertTo-Json -Depth 5 -Compress));
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.run.json')),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if (-not $receipt.source_unchanged -or -not $finished -or $child.ExitCode -ne 0 -or
        (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) { throw 'Timeout, native failure, script error, or source mutation' }
    $lines = @(Get-Content -LiteralPath $stdout)
    $marker = switch ($Mode) { 'focused' {'SAVE_PREFLIGHT_SMOKE:PASS'} 'migration' {'NOTEBOOK_MIGRATION_SMOKE: PASS'} 'host' {'NOTEBOOK_HOST_SMOKE: PASS'} }
    if (@($lines|Where-Object {$_ -ceq $marker}).Count -ne 1) { throw 'Exact PASS marker missing' }
    if ($Mode -eq 'focused') {
        $summaries = @($lines|Where-Object {$_.StartsWith('SAVE_PREFLIGHT_AUDIT: ')})
        if ($summaries.Count -ne 1) { throw 'Missing focused summary' }
        $result = $summaries[0].Substring('SAVE_PREFLIGHT_AUDIT: '.Length)|ConvertFrom-Json
        if (-not $result.ok -or @($result.measurements).Count -ne 48) { throw 'Focused denominator/result mismatch' }
        [IO.File]::WriteAllText((Join-Path $evidence 'focused.result.json'),($result|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
        Write-Output ('Focused checks='+$result.checks+' saves='+$result.measurements.Count)
    } else { $lines|Where-Object {$_ -match 'SMOKE:|CHECKS:|ASSERTIONS:'} }
} finally {
    if ($null -ne $child -and -not $child.HasExited) { $child.Kill(); $child.WaitForExit() }
    $env:APPDATA=$oldApp; $env:LOCALAPPDATA=$oldLocal
}
