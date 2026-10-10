param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [switch]$SelfTest
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$checks=0
function Require([bool]$Condition,[string]$Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
function CorpusHash($Rows) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(@($Rows) -join "`n"))).ToLowerInvariant() } finally { $sha.Dispose() }
}
function Check-Result($Result,[bool]$Before) {
    Require ($Result.schema_version -eq 1 -and $Result.suite_id -ceq 'gallery-layout') 'Result schema/suite'
    Require ($Result.ok -eq (-not $Before) -and $Result.required_cases -eq 48 -and @($Result.cases).Count -eq 48) 'Result denominator/status'
    Require ($Result.checks -eq 670 -and @($Result.errors).Count -eq $(if ($Before) {144} else {0})) 'Assertion/error denominator'
    $expected=@()
    foreach ($branch in @('REALITY','STAY')) {
        foreach ($locale in @('ko-KR','en-US')) {
            foreach ($scale in @('1','2')) {
                foreach ($view in @('list','detail','comparison')) {
                    foreach ($action in @('open','refresh')) { $expected+= "$branch/$locale/$scale/$view/$action" }
                }
            }
        }
    }
    $keys=@($Result.cases|ForEach-Object key)
    Require (@($keys|Sort-Object -Unique).Count -eq 48 -and -not @(Compare-Object $keys $expected).Count) 'Missing, duplicate, or unexpected case'
    foreach ($case in $Result.cases) {
        $open=$case.key.EndsWith('/open')
        Require ($case.passed -eq (-not $Before) -and $case.rows -eq 14) ('Case state '+$case.key)
        Require ($case.expected_page -eq 2 -and $case.expected_preview -eq 14 -and $case.expected_comparison -eq $(if ($open) {4} else {6})) 'Independent expected counts'
        Require ($case.calls.page -eq $(if ($Before) {3} else {2}) -and $case.calls.preview -eq $(if ($Before) {23} else {14}) -and
            $case.calls.comparison -eq $(if ($Before) {if ($open) {5} else {7}} else {if ($open) {4} else {6}})) ('Measured counts '+$case.key)
        if ($Before) {
            foreach ($suffix in @(' constructs only restored list',' renders each row once',' constructs basket once')) {
                Require (@($Result.errors|Where-Object {$_ -ceq ($case.key+$suffix)}).Count -eq 1) 'Unexpected behavioral failure in baseline'
            }
        }
    }
}
function Check-Receipt($Receipt,[string]$Label,[string]$Mode,[bool]$Before) {
    Require ($Receipt.schema_version -eq 1 -and $Receipt.mode -ceq $Mode -and $Receipt.completed -eq $true -and $Receipt.require_authored -eq $true) 'Receipt completion/mode'
    Require ($Receipt.expected_failure -eq $Before -and $Receipt.exit_code -eq $(if ($Before) {1} else {0})) 'Receipt native status'
    Require ($Receipt.source_unchanged -eq $true -and $Receipt.data_unchanged -eq $true) 'Runtime corpus mutation'
    Require ($Receipt.engine_version -ceq '4.7.2.stable.steam.ed1daf0bf' -and $Receipt.engine_sha256 -ceq '12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38') 'Engine identity'
    foreach ($kind in @('source','data')) {
        $corpus=$Receipt.($kind+'_corpus')
        Require ($corpus.file_count -eq $(if ($kind -eq 'source') {264} else {4}) -and @($corpus.rows).Count -eq $corpus.file_count -and
            @($corpus.rows|Sort-Object -Unique).Count -eq $corpus.file_count -and (CorpusHash $corpus.rows) -ceq $corpus.sha256) 'Corpus denominator/hash'
    }
    Require ($Receipt.runner_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'run_notebook_gallery_layout_audit.ps1'))) 'Runner provenance'
    Require ($Receipt.stdout_sha256 -ceq (Sha (Join-Path $root ($Label+'.out.log'))) -and $Receipt.stderr_sha256 -ceq (Sha (Join-Path $root ($Label+'.err.log')))) 'Raw log hash'
    Require (-not (Select-String -LiteralPath (Join-Path $root ($Label+'.out.log')),(Join-Path $root ($Label+'.err.log')) -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Raw script errors'
    $marker=switch ($Mode) { 'layout' {'NOTEBOOK_GALLERY_LAYOUT_SMOKE:'} 'query' {'NOTEBOOK_QUERY_SMOKE: '} 'host' {'NOTEBOOK_HOST_SMOKE: '} }
    $expected=$marker+$(if ($Before) {'FAIL'} else {'PASS'})
    Require (@(Get-Content -LiteralPath (Join-Path $root ($Label+'.out.log'))|Where-Object {$_ -ceq $expected}).Count -eq 1) 'Exact raw marker'
    if ($Mode -eq 'layout') {
        Require ($Receipt.harness_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/notebook_gallery_layout_audit.gd')) -and
            $Receipt.scene_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/notebook_gallery_layout_audit.tscn'))) 'Fixture provenance'
        $result=Get-Content -LiteralPath (Join-Path $root ($Label+'.result.json')) -Raw|ConvertFrom-Json
        $raw=@(Get-Content -LiteralPath (Join-Path $root ($Label+'.out.log'))|Where-Object {$_.StartsWith('NOTEBOOK_GALLERY_LAYOUT_AUDIT: ')})
        Require ($raw.Count -eq 1) 'Raw summary count'
        $parsed=$raw[0].Substring('NOTEBOOK_GALLERY_LAYOUT_AUDIT: '.Length)|ConvertFrom-Json
        Require (($parsed|ConvertTo-Json -Depth 20 -Compress) -ceq ($result|ConvertTo-Json -Depth 20 -Compress)) 'Saved/raw result agreement'
        Check-Result $result $Before
    }
}
$receipts=@{}
foreach ($label in @('before','after','query','host')) {
    $receipts[$label]=Get-Content -LiteralPath (Join-Path $root ($label+'.run.json')) -Raw|ConvertFrom-Json
    Check-Receipt $receipts[$label] $label $(if ($label -in @('before','after')) {'layout'} else {$label}) ($label -eq 'before')
}
foreach ($label in @('after','query','host')) {
    Require ($receipts[$label].source_corpus.sha256 -ceq $receipts.after.source_corpus.sha256 -and
        $receipts[$label].data_corpus.sha256 -ceq $receipts.before.data_corpus.sha256) 'Regression/source cohort mismatch'
}
$delta=@(Compare-Object @($receipts.before.source_corpus.rows) @($receipts.after.source_corpus.rows))
Require ($delta.Count -eq 2 -and @($delta|Where-Object {$_.InputObject -notlike 'res://scripts/systems/notebook_gallery_host.gd*'}).Count -eq 0) 'Product delta is not just gallery host'
Require ((Sha (Join-Path $root 'before_host.gd')) -ceq ($receipts.before.source_corpus.rows|Where-Object {$_ -like 'res://scripts/systems/notebook_gallery_host.gd*'}).Split("`t")[1]) 'Baseline source proof'
$game=Join-Path (Split-Path -Parent $PSScriptRoot) 'game'
foreach ($kind in @('source','data')) {
    foreach ($row in $receipts.after.($kind+'_corpus').rows) {
        $parts=$row.Split("`t")
        Require ($parts.Count -eq 2 -and $parts[0].StartsWith('res://') -and $parts[0] -notmatch '\.\.') 'Safe source path'
        Require ((Sha (Join-Path $game $parts[0].Substring(6))) -ceq $parts[1]) 'Current product source differs from tested source'
    }
}
$dataGuard=Get-Content -LiteralPath (Join-Path $root 'full_data_guard.json') -Raw|ConvertFrom-Json
Require ($dataGuard.base_commit -ceq 'a6e87b11cb5bd278ea2bb7d65ca978a53dd77ada' -and $dataGuard.file_count -eq 52 -and @($dataGuard.rows).Count -eq 52 -and
    @($dataGuard.rows|Sort-Object -Unique).Count -eq 52 -and (CorpusHash $dataGuard.rows) -ceq $dataGuard.sha256 -and $dataGuard.isolated_source_unchanged -eq $true) 'Full data archive guard'
foreach ($row in $dataGuard.rows) {
    $parts=$row.Split("`t")
    Require ($parts.Count -eq 2 -and $parts[0].StartsWith('res://data/') -and $parts[0] -notmatch '\.\.') 'Safe data path'
    Require ((Sha (Join-Path $game $parts[0].Substring(6))) -ceq $parts[1]) 'Current full data differs from base archive'
}
$negative=@()
if ($SelfTest) {
    foreach ($kind in @('missing_case','duplicate_case','false_count','hide_error','native_status','log_hash')) {
        try {
            if ($kind -in @('native_status','log_hash')) {
                $copy=$receipts.after|ConvertTo-Json -Depth 20|ConvertFrom-Json
                if ($kind -eq 'native_status') {$copy.exit_code=1} else {$copy.stdout_sha256='0'*64}
                Check-Receipt $copy 'after' 'layout' $false
            } else {
                $copy=Get-Content -LiteralPath (Join-Path $root 'after.result.json') -Raw|ConvertFrom-Json
                switch ($kind) {
                    'missing_case' {$copy.cases=@($copy.cases|Select-Object -Skip 1)}
                    'duplicate_case' {$copy.cases[1].key=$copy.cases[0].key}
                    'false_count' {$copy.cases[0].calls.preview=23}
                    'hide_error' {$copy.errors=@('unexpected failure')}
                }
                Check-Result $copy $false
            }
            throw ('Accepted malformed evidence: '+$kind)
        } catch {
            if ($_.Exception.Message.StartsWith('Accepted malformed evidence:')) { throw }
            $negative+=@{id=$kind;rejected=$true;reason=$_.Exception.Message}
        }
    }
}
[ordered]@{ok=$true;checks=$checks;receipts=4;focused_cases=48;source_before=$receipts.before.source_corpus.sha256;source_after=$receipts.after.source_corpus.sha256;runtime_dialogue_files=4;runtime_dialogue_sha256=$receipts.after.data_corpus.sha256;full_data_files=52;full_data_sha256=$dataGuard.sha256;negative=$negative}|ConvertTo-Json -Depth 6
