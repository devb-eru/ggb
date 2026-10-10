param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('gallery-future','query','migration','developer')][string]$Mode = 'gallery-future',
    [switch]$ExpectFailure,
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
if ($ExpectFailure -and $Mode -ne 'gallery-future') { throw 'Expected failure only applies to the focused reproduction' }
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$evidence = [IO.Path]::GetFullPath($EvidencePath)
if (-not ($project + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Use a TEMP isolated project' }
if (-not ($evidence + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use a new TEMP evidence directory' }
New-Item -ItemType Directory -Path $evidence | Out-Null
$arguments = @('--headless','--path',('"'+$project+'"'))
$harnessSha = $null
$sceneSha = $null
function Get-ScriptCorpus([string]$Root) {
    [string[]]$paths = @(Get-ChildItem -LiteralPath (Join-Path $Root 'scripts') -Filter '*.gd' -Recurse -File | ForEach-Object { $_.FullName })
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $rows = foreach ($path in $paths) {
        'res://' + $path.Substring($Root.Length + 1).Replace('\','/') + "`t" + (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).ToLowerInvariant() } finally { $sha.Dispose() }
    [ordered]@{basis='res://scripts/**/*.gd';file_count=$paths.Count;sha256=$hash}
}
$sourceCorpus = Get-ScriptCorpus $project
if ($Mode -eq 'gallery-future') {
    $testDir = Join-Path $project ('__gallery_future_audit_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $testDir | Out-Null
    foreach ($file in @('notebook_gallery_future_audit.gd','notebook_gallery_future_audit.tscn')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$file)) -Destination $testDir }
    $harnessSha = (Get-FileHash -LiteralPath (Join-Path $testDir 'notebook_gallery_future_audit.gd')).Hash.ToLowerInvariant()
    $sceneSha = (Get-FileHash -LiteralPath (Join-Path $testDir 'notebook_gallery_future_audit.tscn')).Hash.ToLowerInvariant()
    $arguments += ('"' + (Join-Path $testDir 'notebook_gallery_future_audit.tscn') + '"')
}
$arguments += @('--','--ggb-dev-notebook-v2','--notebook-require-authored')
if ($Mode -eq 'query') { $arguments += '--notebook-query-smoke' }
if ($Mode -eq 'migration') { $arguments += '--notebook-migration-smoke' }
if ($Mode -eq 'developer') { $arguments += '--developer-checkpoint-smoke' }
$stdout = Join-Path $evidence ($Mode + '.out.log')
$stderr = Join-Path $evidence ($Mode + '.err.log')
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $started = [DateTime]::UtcNow.ToString('o')
    $child = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ($Mode + ': PID=' + $child.Id + ' evidence=' + $evidence)
    $finished = $child.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) { $child.Kill(); $child.WaitForExit() }
    $receipt = [ordered]@{schema_version=1;mode=$Mode;completed=$finished;exit_code=$child.ExitCode;require_authored=$true;expected_failure=$ExpectFailure.IsPresent;
        started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();
        harness_sha256=$harnessSha;scene_sha256=$sceneSha;runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();
        source_corpus=$sourceCorpus;source_unchanged=(($sourceCorpus | ConvertTo-Json -Compress) -ceq ((Get-ScriptCorpus $project) | ConvertTo-Json -Compress));
        store_sha256=(Get-FileHash -LiteralPath (Join-Path $project 'scripts/systems/ending_gallery_store.gd')).Hash.ToLowerInvariant();
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.run.json')), ($receipt|ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    if (-not $receipt.source_unchanged) { throw 'Runtime script corpus changed during execution' }
    if (-not $finished -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) { throw 'Timeout or script error' }
    $marker = switch ($Mode) { 'gallery-future' {'NOTEBOOK_GALLERY_FUTURE_SMOKE:'} 'query' {'NOTEBOOK_QUERY_SMOKE: '} 'migration' {'NOTEBOOK_MIGRATION_SMOKE: '} 'developer' {'DEVELOPER_CHECKPOINT_SMOKE: '} }
    $expected = if ($ExpectFailure) { 'FAIL' } else { 'PASS' }
    $lines = @(Get-Content -LiteralPath $stdout)
    if (@($lines | Where-Object { $_ -ceq ($marker+$expected) }).Count -ne 1 -or
        (-not $ExpectFailure -and $child.ExitCode -ne 0) -or ($ExpectFailure -and $child.ExitCode -ne 1)) { throw 'Native status or exact expected marker differs' }
    if ($Mode -eq 'gallery-future') {
        $summaries = @($lines|Where-Object {$_.StartsWith('NOTEBOOK_GALLERY_FUTURE_AUDIT: ')})
        if ($summaries.Count -ne 1) { throw 'Missing focused summary' }
        $result = $summaries[0].Substring('NOTEBOOK_GALLERY_FUTURE_AUDIT: '.Length)|ConvertFrom-Json
        if ($result.harness_sha256 -cne $harnessSha -or $result.store_sha256 -cne $receipt.store_sha256 -or @($result.cases).Count -ne 324 -or
            ($result.ok -eq $ExpectFailure.IsPresent)) { throw 'Focused summary does not prove expected result' }
        [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.result.json')), ($result|ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        [pscustomobject]@{mode=$Mode;exit_code=$child.ExitCode;cases=$result.cases.Count;checks=$result.checks;failed_cases=@($result.cases|Where-Object {-not $_.passed}).Count;source_corpus=$result.source_corpus} | ConvertTo-Json -Depth 5
    } else { $lines | Where-Object {$_ -match 'CHECKS:|SMOKE:|ASSERTIONS:|COVERAGE:'} }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
