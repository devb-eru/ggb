param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [string]$Prefix = '2026-10-10_463_final',
    [string[]]$Modes = @('import','final','campaign-v2','campaign-ordinary','pack','pack-foundation'),
    [switch]$SelfTest,
    [switch]$Gallery
)
$ErrorActionPreference = 'Stop'
$script:Checks = 0
function Assert-That([bool]$Condition, [string]$Message) {
    $script:Checks++
    if (-not $Condition) { throw $Message }
}
function Corpus([string]$Directory, [string]$Filter, [string]$Game) {
    [string[]]$paths = @(Get-ChildItem -LiteralPath $Directory -Recurse -File -Filter $Filter | ForEach-Object {$_.FullName})
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $rows = foreach ($path in $paths) { 'res://' + $path.Substring($Game.Length + 1).Replace('\','/') + "`t" + (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).ToLowerInvariant() } finally {$sha.Dispose()}
    return @{file_count=$paths.Count;sha256=$hash}
}
function Valid-Receipt($Receipt, [string]$Mode, [string]$Engine, [string]$Runner, $Scripts, $Data, [string]$OutHash, [string]$ErrHash) {
    $strict = $Mode -in @('final','campaign-v2','producer-contract','prologue-surfaces','migration','query','host')
    return $Receipt.schema_version -is [long] -and $Receipt.schema_version -eq 1 -and
        $Receipt.mode -ceq $Mode -and $Receipt.completed -is [bool] -and $Receipt.completed -and
        $Receipt.exit_code -is [long] -and $Receipt.exit_code -eq 0 -and
        $Receipt.source_unchanged -is [bool] -and $Receipt.source_unchanged -and
        $Receipt.require_authored -is [bool] -and $Receipt.require_authored -eq $strict -and
        $Receipt.notebook_v2 -is [bool] -and $Receipt.notebook_v2 -eq $strict -and
        $Receipt.engine_sha256 -ceq $Engine -and $Receipt.runner_sha256 -ceq $Runner -and
        $Receipt.source_corpus.file_count -eq $Scripts.file_count -and $Receipt.source_corpus.sha256 -ceq $Scripts.sha256 -and
        $Receipt.data_corpus.file_count -eq $Data.file_count -and $Receipt.data_corpus.sha256 -ceq $Data.sha256 -and
        $Receipt.stdout_sha256 -ceq $OutHash -and $Receipt.stderr_sha256 -ceq $ErrHash
}
if ($SelfTest) {
    $corpus = @{file_count=1;sha256='corpus'}
    $r = @{schema_version=[long]1;mode='final';completed=$true;exit_code=[long]0;source_unchanged=$true;require_authored=$true;notebook_v2=$true;engine_sha256='engine';runner_sha256='runner';source_corpus=$corpus;data_corpus=$corpus;stdout_sha256='out';stderr_sha256='err'}
    Assert-That (Valid-Receipt $r 'final' 'engine' 'runner' $corpus $corpus 'out' 'err') 'Valid control rejected'
    foreach ($pair in @(@('exit_code',[long]1),@('completed',$false),@('require_authored',$false),@('notebook_v2',$false),@('mode','campaign-ordinary'),@('engine_sha256','other'),@('runner_sha256','other'),@('stdout_sha256','other'),@('source_unchanged',$false))) {
        $copy = $r.Clone(); $copy[$pair[0]] = $pair[1]
        Assert-That (-not (Valid-Receipt $copy 'final' 'engine' 'runner' $corpus $corpus 'out' 'err')) ('Invalid receipt accepted: '+$pair[0])
    }
    [pscustomobject]@{ok=$true;checks=$script:Checks;negative_cases=9}|ConvertTo-Json
    exit 0
}
$game = (Resolve-Path -LiteralPath (Join-Path $Root 'game')).Path
$scripts = Corpus (Join-Path $game 'scripts') '*.gd' $game
$data = Corpus (Join-Path $game 'data') '*' $game
Assert-That ($scripts.file_count -eq 264 -and $data.file_count -eq 52) 'Unexpected product corpus'
$asset = Get-Content -LiteralPath (Join-Path $EvidencePath ($Prefix+'_official_asset.json')) -Raw|ConvertFrom-Json
$guard = Get-Content -LiteralPath (Join-Path $EvidencePath ($Prefix+'_source_guard.json')) -Raw|ConvertFrom-Json
Assert-That (@($guard.files).Count -eq 640 -and $guard.base_commit -ceq $asset.base_commit) 'Original source denominator/commit differs'
foreach ($row in $guard.files) {
    $path = Join-Path $Root $row.path
    Assert-That ((Get-Item -LiteralPath $path).Length -eq $row.bytes -and (Get-FileHash -LiteralPath $path).Hash -ieq $row.sha256) ('Original source differs: '+$row.path)
}
$engine = $guard.engine_sha256
Assert-That ($engine -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00' -and $guard.zip_sha256 -ceq 'e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90' -and $asset.executable_sha256 -ceq $engine -and $asset.download_sha256 -ceq $guard.zip_sha256 -and $asset.official_digest -ceq ('sha256:'+$guard.zip_sha256)) 'Candidate engine identity differs'
$runs = @(); $traces = @(); $pack = $null
foreach ($mode in $Modes) {
    $stem = Join-Path $EvidencePath ($Prefix+'_'+$mode)
    $r = Get-Content -LiteralPath ($stem+'.run.json') -Raw|ConvertFrom-Json
    $runnerPath = if ($mode -in @('import','final','campaign-v2','campaign-ordinary','pack','pack-foundation')) { Join-Path $EvidencePath ($Prefix+'_runner_v1.ps1') } else { Join-Path $Root 'scripts/run_notebook_candidate_compatibility.ps1' }
    $runner = (Get-FileHash -LiteralPath $runnerPath).Hash.ToLowerInvariant()
    $outHash = (Get-FileHash -LiteralPath ($stem+'.out.log')).Hash.ToLowerInvariant()
    $errHash = (Get-FileHash -LiteralPath ($stem+'.err.log')).Hash.ToLowerInvariant()
    Assert-That (Valid-Receipt $r $mode $engine $runner $scripts $data $outHash $errHash) ('Native receipt differs: '+$mode)
    $strict = $mode -in @('final','campaign-v2','producer-contract','prologue-surfaces','migration','query','host')
    foreach ($flag in @('--ggb-dev-notebook-v2','--notebook-require-authored','--notebook-producer-trace')) {
        Assert-That (($flag -in $r.arguments) -eq $strict) ('Actual strict/rollout arguments differ: '+$mode)
    }
    $out = [IO.File]::ReadAllText($stem+'.out.log'); $err = [IO.File]::ReadAllText($stem+'.err.log')
    Assert-That (-not (($out+"`n"+$err) -match 'SCRIPT ERROR|Parse Error|Compile Error|(?m)^ERROR:')) ('Native error: '+$mode)
    Assert-That ($out -match 'Godot Engine v4\.6\.3\.stable\.official\.7d41c59c4') ('Actual version missing: '+$mode)
    $lines = @($out -split '\r?\n')
    $marker = switch ($mode) {
        'final' {'NOTEBOOK_FINAL_SMOKE: PASS'}
        'campaign-v2' {'FULL_CAMPAIGN_SMOKE: PASS'}
        'campaign-ordinary' {'FULL_CAMPAIGN_SMOKE: PASS'}
        'pack-foundation' {'FOUNDATION_SMOKE: PASS'}
        'prologue-surfaces' {'NOTEBOOK_PROLOGUE_SURFACES_SMOKE: PASS'}
        'migration' {'NOTEBOOK_MIGRATION_SMOKE: PASS'}
        'query' {'NOTEBOOK_QUERY_SMOKE: PASS'}
        'host' {'NOTEBOOK_HOST_SMOKE: PASS'}
    }
    if ($marker) { Assert-That (@($lines|Where-Object {$_ -ceq $marker}).Count -eq 1) ('Exact PASS missing: '+$mode) }
    if ($mode -eq 'producer-contract') {
        $summaries = @($lines|Where-Object {$_.StartsWith('NOTEBOOK_PRODUCER_CONTRACT_SMOKE: PASS ')})
        Assert-That ($summaries.Count -eq 1) 'Writer summary missing'
        $summary = $summaries[0].Substring('NOTEBOOK_PRODUCER_CONTRACT_SMOKE: PASS '.Length)|ConvertFrom-Json
        Assert-That ($summary.ok -is [bool] -and $summary.ok -and @($summary.errors).Count -eq 0 -and $summary.strict_requested -is [bool] -and $summary.strict_requested -and $summary.assertions -eq 45) 'Writer summary failed or strict request missing'
    }
    # The campaign runner emits PASS but does not publish a runtime tuple report.
    if ($mode -in @('final','prologue-surfaces')) {
        $traceLines = @($lines|Where-Object {$_.StartsWith('NOTEBOOK_RUNTIME_AUDIT: ')})
        Assert-That ($traceLines.Count -eq 1) ('Runtime trace missing: '+$mode)
        $trace = $traceLines[0].Substring('NOTEBOOK_RUNTIME_AUDIT: '.Length)|ConvertFrom-Json
        Assert-That ($trace.ok -and $trace.suite_ok -and @($trace.errors).Count -eq 0 -and $trace.source_corpus.sha256 -ceq $scripts.sha256 -and $trace.source_corpus.file_count -eq $scripts.file_count) 'Runtime trace status/source differs'
        Assert-That (@($trace.catalog_fingerprints.PSObject.Properties).Count -eq 29 -and $trace.required_branch_coverage -ceq 'NOT_AUDITED' -and $null -eq $trace.excluded_ui_count -and $null -eq $trace.new_unmapped_count) 'Trace scope/catalog denominator differs'
        foreach ($prop in $trace.catalog_fingerprints.PSObject.Properties) {
            Assert-That ((Get-FileHash -LiteralPath (Join-Path $game $prop.Name.Substring(6))).Hash -ieq $prop.Value) 'Runtime catalog differs'
        }
        $traces += @{mode=$mode;observed_tuples=@($trace.tuples).Count;sampled_entry_classes=$trace.sampled_entry_classes;required_branch_coverage=$trace.required_branch_coverage}
    }
    if ($mode -eq 'pack') { Assert-That ($r.pack_bytes -gt 0 -and $r.pack_sha256 -match '^[a-f0-9]{64}$') 'PCK missing'; $pack=$r }
    if ($mode -eq 'pack-foundation') {
        Assert-That ($null -ne $pack -and $r.pack_sha256 -ceq $pack.pack_sha256 -and $r.pack_bytes -eq $pack.pack_bytes -and '--main-pack' -in $r.arguments) 'PCK identity or standalone invocation differs'
    }
    $runs += @{mode=$mode;exit_code=$r.exit_code;completed=$r.completed;runner_sha256=$runner}
}
if ($Gallery) {
    $stem = Join-Path $EvidencePath ($Prefix+'_gallery')
    $r = Get-Content -LiteralPath ($stem+'.run.json') -Raw|ConvertFrom-Json
    Assert-That ($r.mode -ceq 'gallery-future' -and $r.completed -and $r.exit_code -eq 0 -and $r.require_authored -and -not $r.expected_failure -and $r.source_unchanged -and $r.engine_sha256 -ceq $engine -and $r.source_corpus.sha256 -ceq $scripts.sha256 -and $r.source_corpus.file_count -eq $scripts.file_count) 'Focused candidate receipt differs'
    foreach ($pair in @(@('out.log','stdout_sha256'),@('err.log','stderr_sha256'))) {
        Assert-That ((Get-FileHash -LiteralPath ($stem+'.'+$pair[0])).Hash -ieq $r.($pair[1])) 'Focused native bytes differ'
    }
    foreach ($pair in @(@('scripts/run_notebook_gallery_future_audit.ps1','runner_sha256'),@('scripts/tests/notebook_gallery_future_audit.gd','harness_sha256'),@('scripts/tests/notebook_gallery_future_audit.tscn','scene_sha256'),@('game/scripts/systems/ending_gallery_store.gd','store_sha256'))) {
        Assert-That ((Get-FileHash -LiteralPath (Join-Path $Root $pair[0])).Hash -ieq $r.($pair[1])) 'Focused executable source differs'
    }
    $lines = @(Get-Content -LiteralPath ($stem+'.out.log'))
    Assert-That (@($lines|Where-Object {$_ -ceq 'NOTEBOOK_GALLERY_FUTURE_SMOKE:PASS'}).Count -eq 1) 'Focused exact PASS missing'
    Assert-That (-not (Select-String -LiteralPath ($stem+'.out.log'),($stem+'.err.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -Quiet)) 'Focused native error'
    $summaries = @($lines|Where-Object {$_.StartsWith('NOTEBOOK_GALLERY_FUTURE_AUDIT: ')})
    Assert-That ($summaries.Count -eq 1) 'Focused raw summary missing'
    $result = $summaries[0].Substring('NOTEBOOK_GALLERY_FUTURE_AUDIT: '.Length)|ConvertFrom-Json
    $saved = Get-Content -LiteralPath ($stem+'.result.json') -Raw|ConvertFrom-Json
    Assert-That (($saved|ConvertTo-Json -Depth 40 -Compress) -ceq ($result|ConvertTo-Json -Depth 40 -Compress)) 'Focused saved summary differs from raw'
    Assert-That ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 3155 -and $result.required_cases -eq 324 -and @($result.cases).Count -eq 324 -and $result.source_corpus.sha256 -ceq $scripts.sha256 -and $result.harness_sha256 -ceq $r.harness_sha256 -and $result.store_sha256 -ceq $r.store_sha256) 'Focused result status/source differs'
    Assert-That ((Get-FileHash -LiteralPath (Join-Path $game 'data/development/checkpoints.json')).Hash -ieq $result.checkpoint_sha256) 'Focused checkpoint differs'
    $expected = @{}
    foreach ($locale in @('ko-KR','en-US')) { foreach ($branch in @('REALITY','STAY')) {
        foreach ($field in @('gallery_version','checksum')) {
            $values = if ($field -eq 'gallery_version') {@('2','999','future','1','true','false','<null>','[1]','{ "value": 1 }','1.5')} else {@('1','true','false','<null>','[1]','{ "value": 1 }')}
            $candidates = if ($field -eq 'gallery_version') {@('main','temporary')} else {@('main')}
            foreach ($value in $values) {foreach ($candidate in $candidates) {foreach ($action in @('read','list','capture')) {$expected["$locale/$branch/$field/$value/$candidate/$action"]=$true}}}
        }
        foreach ($kind in @('fresh','current_temporary','damaged_temporary')) {$expected["$locale/$branch/$kind"]=$true}
    }}
    Assert-That ($expected.Count -eq 324) 'Independent focused denominator differs'
    $seen = @{}
    foreach ($case in $result.cases) {
        Assert-That ($expected.ContainsKey($case.key) -and -not $seen.ContainsKey($case.key) -and $case.passed) 'Missing, duplicate, unexpected or failed focused case'
        $seen[$case.key]=$true
        if ($null -ne $case.before_files) {
            Assert-That (($case.before_files|ConvertTo-Json -Depth 20 -Compress) -ceq ($case.after_files|ConvertTo-Json -Depth 20 -Compress)) 'Focused original file changed'
        }
    }
    $runs += @{mode='gallery-future';exit_code=$r.exit_code;completed=$r.completed;conditions=324;checks=3155}
}
[pscustomobject]@{ok=$true;checks=$script:Checks;base_commit=$guard.base_commit;source_corpus=$scripts;data_corpus=$data;original_files=640;runs=$runs;traces=$traces;scope='Specified automated compatibility runs only; not engine adoption, exhaustive producer branches, physical input or performance acceptance.'}|ConvertTo-Json -Depth 9
