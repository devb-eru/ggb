param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [string]$Prefix = '2026-10-10_gallery_future_final',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
function Assert-That([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Canonical($Value) { $Value | ConvertTo-Json -Depth 40 -Compress }
function Assert-Cases($Result) {
    Assert-That ($Result.schema_version -eq 1 -and $Result.suite_id -ceq 'gallery-future' -and $Result.ok -and @($Result.errors).Count -eq 0) 'Invalid focused status'
    $expected = @{}
    foreach ($locale in @('ko-KR','en-US')) {
        foreach ($branch in @('REALITY','STAY')) {
            foreach ($field in @('gallery_version','checksum')) {
                $versions = if ($field -ceq 'gallery_version') { @('2','999','future','1','true','false','<null>','[1]','{ "value": 1 }','1.5') } else { @('1','true','false','<null>','[1]','{ "value": 1 }') }
                $candidates = if ($field -ceq 'gallery_version') { @('main','temporary') } else { @('main') }
                foreach ($version in $versions) {
                    foreach ($candidate in $candidates) {
                        foreach ($action in @('read','list','capture')) {
                            $expected["$locale/$branch/$field/$version/$candidate/$action"] = @{field=$field;candidate=$candidate;action=$action}
                        }
                    }
                }
            }
            foreach ($kind in @('fresh','current_temporary','damaged_temporary')) { $expected["$locale/$branch/$kind"] = @{kind=$kind} }
        }
    }
    Assert-That ($expected.Count -eq 324 -and @($Result.cases).Count -eq 324 -and $Result.required_cases -eq 324 -and $Result.checks -eq 3155) 'Independent denominator mismatch'
    $seen = @{}
    foreach ($case in $Result.cases) {
        Assert-That ($expected.ContainsKey($case.key) -and -not $seen.ContainsKey($case.key) -and $case.passed) 'Missing, duplicate, unexpected or failed case'
        $seen[$case.key] = $true
        $row = $expected[$case.key]
        if ($row.ContainsKey('kind')) {
            Assert-That ($case.kind -ceq $row.kind -and @($case.files.PSObject.Properties).Count -eq 2) 'Invalid current-format control'
        } else {
            Assert-That ($case.field -ceq $row.field -and $case.candidate -ceq $row.candidate -and $case.action -ceq $row.action) 'Header scenario identity mismatch'
            Assert-That ((Canonical $case.before_files) -ceq (Canonical $case.after_files)) 'Original files changed'
            if ($row.action -ceq 'capture' -or ($row.action -ceq 'read' -and $row.candidate -ceq 'main')) {
                $error = if ($row.field -ceq 'gallery_version') { 'gallery_version' } else { 'gallery_checksum' }
                Assert-That ($case.result -ceq $error) 'Typed error missing'
            }
        }
    }
}
function Assert-Receipt([string]$Stem, [string]$Mode, [string]$Marker) {
    $receipt = Get-Content -LiteralPath (Join-Path $EvidencePath ($Stem + '.run.json')) -Raw | ConvertFrom-Json
    Assert-That ($receipt.mode -ceq $Mode -and $receipt.completed -and $receipt.exit_code -eq 0 -and $receipt.require_authored -and -not $receipt.expected_failure -and $receipt.source_unchanged) 'Invalid native receipt'
    foreach ($pair in @(@('out.log','stdout_sha256'),@('err.log','stderr_sha256'))) {
        Assert-That ((Get-FileHash -LiteralPath (Join-Path $EvidencePath ($Stem + '.' + $pair[0]))).Hash -ieq $receipt.($pair[1])) 'Native log bytes differ'
    }
    foreach ($pair in @(@('game/scripts/systems/ending_gallery_store.gd','store_sha256'),@('scripts/run_notebook_gallery_future_audit.ps1','runner_sha256'))) {
        Assert-That ((Get-FileHash -LiteralPath (Join-Path $Root $pair[0])).Hash -ieq $receipt.($pair[1])) 'Current executable source differs'
    }
    Assert-That ((Canonical $receipt.source_corpus) -ceq (Canonical $script:Corpus)) 'Stale script corpus'
    $lines = @(Get-Content -LiteralPath (Join-Path $EvidencePath ($Stem + '.out.log')))
    Assert-That (@($lines | Where-Object { $_ -ceq $Marker }).Count -eq 1) 'Exact native PASS missing'
    Assert-That (-not (Select-String -LiteralPath (Join-Path $EvidencePath ($Stem + '.out.log')),(Join-Path $EvidencePath ($Stem + '.err.log')) -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Native script error'
    return $receipt
}
[string[]]$paths = @(Get-ChildItem -LiteralPath (Join-Path $Root 'game/scripts') -Filter '*.gd' -Recurse -File | ForEach-Object { $_.FullName })
[Array]::Sort($paths, [StringComparer]::Ordinal)
$game = (Resolve-Path -LiteralPath (Join-Path $Root 'game')).Path
$rows = foreach ($path in $paths) { 'res://' + $path.Substring($game.Length + 1).Replace('\','/') + "`t" + (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).ToLowerInvariant() } finally { $sha.Dispose() }
$script:Corpus = [ordered]@{basis='res://scripts/**/*.gd';file_count=$paths.Count;sha256=$hash}
Assert-That ($paths.Count -eq 264) 'Unexpected script count'
$receipt = Assert-Receipt $Prefix 'gallery-future' 'NOTEBOOK_GALLERY_FUTURE_SMOKE:PASS'
foreach ($pair in @(@('scripts/tests/notebook_gallery_future_audit.gd','harness_sha256'),@('scripts/tests/notebook_gallery_future_audit.tscn','scene_sha256'))) {
    Assert-That ((Get-FileHash -LiteralPath (Join-Path $Root $pair[0])).Hash -ieq $receipt.($pair[1])) 'Focused test source differs'
}
$summaries = @(Get-Content -LiteralPath (Join-Path $EvidencePath ($Prefix + '.out.log')) | Where-Object { $_.StartsWith('NOTEBOOK_GALLERY_FUTURE_AUDIT: ') })
Assert-That ($summaries.Count -eq 1) 'Focused raw summary missing'
$result = $summaries[0].Substring('NOTEBOOK_GALLERY_FUTURE_AUDIT: '.Length) | ConvertFrom-Json
$saved = Get-Content -LiteralPath (Join-Path $EvidencePath ($Prefix + '.result.json')) -Raw | ConvertFrom-Json
Assert-That ((Canonical $saved) -ceq (Canonical $result)) 'Derived summary differs from raw'
Assert-That ((Canonical $result.source_corpus) -ceq (Canonical $script:Corpus) -and $result.harness_sha256 -ceq $receipt.harness_sha256 -and $result.store_sha256 -ceq $receipt.store_sha256) 'Focused source identity differs'
Assert-That ((Get-FileHash -LiteralPath (Join-Path $Root 'game/data/development/checkpoints.json')).Hash -ieq $result.checkpoint_sha256) 'Checkpoint changed'
Assert-Cases $result
$guard = Get-Content -LiteralPath (Join-Path $EvidencePath '2026-10-10_gallery_future_source_guard.json') -Raw | ConvertFrom-Json
Assert-That (@($guard.files).Count -eq 316) 'Source/data guard denominator differs'
foreach ($row in $guard.files) {
    Assert-That ((Get-FileHash -LiteralPath (Join-Path $Root $row.path)).Hash -ieq $row.sha256) 'Source/data manifest differs'
}
foreach ($pair in @(@('migration','NOTEBOOK_MIGRATION_SMOKE: PASS'),@('developer','DEVELOPER_CHECKPOINT_SMOKE: PASS'),@('query','NOTEBOOK_QUERY_SMOKE: PASS'))) {
    $other = Assert-Receipt ($Prefix + '_' + $pair[0]) $pair[0] $pair[1]
    Assert-That ($other.engine_sha256 -ceq $receipt.engine_sha256) 'Regression engine differs'
}
foreach ($before in @('before','checksum_before')) {
    $stem = '2026-10-10_gallery_future_' + $before
    $prior = Get-Content -LiteralPath (Join-Path $EvidencePath ($stem + '.run.json')) -Raw | ConvertFrom-Json
    Assert-That ($prior.completed -and $prior.exit_code -eq 1 -and $prior.require_authored) 'Before-fix run is not a native failure'
    foreach ($pair in @(@('out.log','stdout_sha256'),@('err.log','stderr_sha256'),@('_harness.gd','harness_sha256'))) {
        $name = if ($pair[0].StartsWith('_')) { $stem + $pair[0] } else { $stem + '.' + $pair[0] }
        Assert-That ((Get-FileHash -LiteralPath (Join-Path $EvidencePath $name)).Hash -ieq $prior.($pair[1])) 'Before-fix evidence bytes differ'
    }
    $store = if ($before -ceq 'before') { '2026-10-10_gallery_future_before_store.gd' } else { '2026-10-10_gallery_future_version_patch_store.gd' }
    Assert-That ((Get-FileHash -LiteralPath (Join-Path $EvidencePath $store)).Hash -ieq $prior.store_sha256) 'Before-fix store differs'
    Assert-That ($prior.store_sha256 -cne $receipt.store_sha256) 'Before-fix source is incorrectly latest'
}
$negative = 0
if ($SelfTest) {
    foreach ($mutate in @(
        { param($r) $r.cases = @($r.cases | Select-Object -Skip 1) },
        { param($r) $r.cases[1] = $r.cases[0] },
        { param($r) $r.cases[0].after_files.'unrelated.txt' = 'changed' },
        { param($r) $r.cases[0].result = '' },
        { param($r) $r.cases[0].passed = $false }
    )) {
        $bad = (Canonical $result) | ConvertFrom-Json
        & $mutate $bad
        $rejected = $false
        try { Assert-Cases $bad } catch { $rejected = $true }
        Assert-That $rejected 'Negative audit mutation accepted'
        $negative += 1
    }
}
[ordered]@{ok=$true;cases=324;checks=3155;native_runs=4;source_corpus=$script:Corpus;original_files_preserved=$true;negative_checks=$negative;actual_input=$false;all_producers=$false} | ConvertTo-Json -Depth 6
