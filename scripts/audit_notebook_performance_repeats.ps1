#requires -Version 7.0
param([Parameter(Mandatory)][string]$EvidencePath,[string]$PackPath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Require([bool]$Ok,[string]$Message) {$script:checks++;if (-not $Ok) {throw $Message}}
function Sha([string]$Path) {(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
function Json($Value) {ConvertTo-Json -InputObject $Value -Depth 60 -Compress}
function Stats([double[]]$Values) {
    $sorted=@($Values|Sort-Object)
    return @{count=$Values.Count;first=$Values[0];mean=($Values|Measure-Object -Average).Average;maximum=$sorted[-1];p95=$sorted[[math]::Ceiling(0.95*$sorted.Count)-1]}
}
function SameStats($Actual,$Expected) {
    if ($null -eq $Actual -or $Actual.count -ne $Expected.count) {return $false}
    foreach ($key in @('first','mean','maximum','p95')) {if ([math]::Abs([double]$Actual[$key]-[double]$Expected[$key]) -gt 0.000001) {return $false}}
    return $true
}
$source=Get-Content -LiteralPath (Join-Path $root 'source.json') -Raw|ConvertFrom-Json -AsHashtable
$manifest=Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json -AsHashtable
$summary=Get-Content -LiteralPath (Join-Path $root 'measurements/summary.json') -Raw|ConvertFrom-Json -AsHashtable
$inputs=@{
    'NB-PERF-N2000'=@{sha256='36c759a9acefd01de48d56323353afb7a1b139a2a6cf31b42328257282e57e64';normal=2000;protected=6;legacy=0;bookmarks=0;comparison=3;long_documents=0;long_document_utf8_bytes=0;utf8_bytes=1815265}
    'NB-PERF-L10000'=@{sha256='cb640d6a7d1956b796f09a9c8b8be6b7758f2e098b4c71841474e47560c624a8';normal=2000;protected=6;legacy=10000;bookmarks=0;comparison=3;long_documents=0;long_document_utf8_bytes=0;utf8_bytes=5434278}
    'NB-PERF-P2001'=@{sha256='f9c81734eb11029e6b101e41a6d65405d3a04f0f685bec23a138b214e79259bc';normal=2001;protected=2001;legacy=0;bookmarks=50;comparison=12;long_documents=0;long_document_utf8_bytes=0;utf8_bytes=3692933}
    'NB-PERF-LONG'=@{sha256='baf4573daa580deb030810e47865583c84a6833cfacbbf46a7bd5e0d61972207';normal=1980;protected=26;legacy=0;bookmarks=0;comparison=3;long_documents=20;long_document_utf8_bytes=32768;utf8_bytes=2472815}
}
Require ($source.head -ceq '18a8841f4f6ef879ffc87ab558deab8cced1a963' -and $source.product_files -eq 640) 'Exact baseline source'
Require ($source.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Exact official candidate engine'
$retainedPack=if ($PackPath) {$PackPath} else {$source.pack}
Require ((Sha $retainedPack) -ceq $source.pack_sha256) 'Retained measured PCK hash'
Require ($source.rows.Count -eq 640) 'Original product manifest size'
foreach ($row in $source.rows) {
    $parts=$row.Split("`t")
    Require ($parts.Count -eq 2 -and (Sha (Join-Path $repo $parts[0])) -ceq $parts[1]) 'Staged product equals measured source'
}
Require ((Sha (Join-Path $repo 'scripts/measure_notebook_performance.ps1')) -ceq $source.runner_sha256) 'Measured runner source'
foreach ($name in @('import','pack')) {
    $r=Get-Content -LiteralPath (Join-Path $root ('build/'+$name+'.run.json')) -Raw|ConvertFrom-Json -AsHashtable
    Require ($r.completed -eq $true -and $r.exit_code -eq 0 -and $r.pid -gt 0) 'Completed native build step'
    Require ($r.name -ceq $name -and ($r.args -contains $(if ($name -eq 'import') {'--import'} else {'--export-pack'}))) 'Required actual build arguments'
}
Require (Test-Path -LiteralPath (Join-Path $root 'device.json')) 'Device context retained'

function ValidateBundle($s,$files) {
    Require ($s.format_version -eq 1 -and $s.acceptance -ceq 'MEASUREMENT_ONLY' -and $s.device_class -ceq 'NOT_CLASSIFIED' -and $s.renderer -ceq 'headless') 'No unsupported hardware/input acceptance claim'
    Require ($s.sampling_complete -eq $true -and $s.requested_cold -eq 20 -and $s.requested_warm -eq 100 -and $s.requested_lifecycle_cycles -eq 0 -and $s.profiling_mode -ceq 'STANDARD' -and $s.failed_runs.Count -eq 0) 'Required complete sampling configuration'
    Require ($s.percentile -ceq 'nearest rank ceil(0.95*n)' -and $s.engine_sha256.ToLowerInvariant() -ceq $source.engine_sha256 -and $s.pack_sha256.ToLowerInvariant() -ceq $source.pack_sha256) 'Percentile and executed binary provenance'
    Require ($s.not_covered -contains 'OS input/IME' -and $s.not_covered -contains 'warm UI input p95' -and $s.not_covered -contains '50 open/close RAM recovery') 'Unmeasured contracts stay explicit'
    Require ($files.Count -eq 489) 'Exact raw evidence file count'
    $seenFiles=@{}
    foreach ($row in $files) {
        Require ($row.path -notmatch '(^/|\\|\.\.)' -and -not $seenFiles.ContainsKey($row.path)) 'Unique contained evidence path'
        $seenFiles[$row.path]=$true
        $path=Join-Path $root $row.path
        Require ((Get-Item -LiteralPath $path).Length -eq $row.bytes -and (Sha $path) -ceq $row.sha256) 'Raw evidence bytes and hash'
    }
    Require ($s.runs.Count -eq 160 -and $s.groups.Count -eq 8) 'Exactly 160 processes and eight groups'
    $seenRuns=@{}
    foreach ($run in $s.runs) {
        Require (-not $seenRuns.ContainsKey($run.name)) 'Unique cold process name'
        $seenRuns[$run.name]=$run
    }
    $seenGroups=@{}
    $fixtureHashes=@{}
    foreach ($group in $s.groups) {
        $id=$group.fixture+'-'+$group.locale
        Require ($group.fixture -in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG') -and $group.locale -in @('ko-KR','en-US') -and -not $seenGroups.ContainsKey($id) -and $group.cold_runs -eq 20) 'Unique required fixture and locale'
        $seenGroups[$id]=$true
        $metrics=@{}
        $peaks=[Collections.Generic.List[double]]::new()
        for ($cold=0;$cold -lt 20;$cold++) {
            $name=$id+'-'+$cold
            Require ($seenRuns.ContainsKey($name)) 'Every required cold process is present'
            $run=$seenRuns[$name]
            Require ($run.functional_pass -eq $true -and $run.exit_code -eq 0 -and $run.failure -ceq '' -and $run.process_id -gt 0 -and $run.wall_seconds -gt 0 -and $run.peak_working_set_bytes -gt 0) 'Actual native completion and result'
            $base='measurements/'+$name+'/'
            foreach ($file in @('stdout.log','stderr.log','result.json')) {Require ($seenFiles.ContainsKey($base+$file)) 'Raw per-process evidence exists'}
            $saved=Get-Content -LiteralPath (Join-Path $root ($base+'result.json')) -Raw|ConvertFrom-Json -AsHashtable
            Require ((Json $saved) -ceq (Json $run)) 'Summary process equals original result file'
            $raw=Get-Content -LiteralPath (Join-Path $root ($base+'stdout.log')) -Raw
            $err=Get-Content -LiteralPath (Join-Path $root ($base+'stderr.log')) -Raw
            Require ($err -notmatch 'SCRIPT ERROR:|Parse Error:|Compilation failed|Failed loading resource:|(?m)^ERROR:') 'No hidden native script failure'
            $lines=@($raw -split "`n"|Where-Object {$_.StartsWith('NOTEBOOK_PERF_RESULT: ')})
            Require ($lines.Count -eq 1) 'Exactly one native result'
            $native=$lines[0].Substring('NOTEBOOK_PERF_RESULT: '.Length)|ConvertFrom-Json -AsHashtable
            Require ((Json $native) -ceq (Json $run.result)) 'Saved metrics equal native output'
            $r=$run.result
            $warm=if ($cold -eq 0) {100} else {0}
            Require ($r.ok -eq $true -and $r.errors.Count -eq 0 -and $r.locale -ceq $group.locale -and $r.warm_iterations -eq $warm -and $r.engine -ceq '4.6.3-stable (official)' -and $r.display -ceq 'headless' -and $r.acceptance -ceq 'MEASUREMENT_ONLY') 'Actual locale, engine and iteration count'
            Require ($r.manifest.fixture_id -ceq $group.fixture -and $r.manifest.seed -ceq 'ggb-notebook-perf-v1' -and $r.manifest.sha256 -match '^[0-9a-f]{64}$') 'Fixed input identity'
            $input=$inputs[$group.fixture]
            Require ($r.manifest.sha256 -ceq $input.sha256) 'Exact independently fixed fixture hash'
            foreach ($field in @('normal','protected','legacy')) {Require ($r.manifest.counts[$field] -eq $input[$field]) 'Required record class denominator'}
            foreach ($field in @('bookmarks','comparison','long_documents','long_document_utf8_bytes','utf8_bytes')) {Require ($r.manifest[$field] -eq $input[$field]) 'Required input sizes and references'}
            if ($fixtureHashes.ContainsKey($group.fixture)) {Require ($fixtureHashes[$group.fixture] -ceq $r.manifest.sha256) 'Same input across cold processes and locales'} else {$fixtureHashes[$group.fixture]=$r.manifest.sha256}
            foreach ($metric in @('fixture_build_ms','fixture_parse_ms','query_open_ms','first_page_model_ms','panel_present_ms','model_to_panel_ms','first_search_ui_ms','search_index_cpu_total_ms','search_index_max_batch_ms','search_index_body_ms','search_index_fields_ms')) {Require (@($r.timings_ms[$metric]).Count -eq 1 -and $r.timings_ms.ContainsKey($metric)) 'One cold metric per process'}
            foreach ($metric in @('warm_page_model_ms','warm_facets_model_ms','warm_search_match_model_ms','warm_search_miss_model_ms','warm_search_hidden_model_ms','warm_search_long_model_ms','two_materials_model_ms','append_prune_ms','durable_save_ms','slot_inspect_after_write_ms')) {Require (($warm -eq 0 -and -not $r.timings_ms.ContainsKey($metric)) -or @($r.timings_ms[$metric]).Count -eq $warm) 'Warm counts are actual requested samples'}
            foreach ($metric in @($r.timings_ms.Keys|Sort-Object)) {
                if (-not $metrics.ContainsKey($metric)) {$metrics[$metric]=[Collections.Generic.List[double]]::new()}
                foreach ($value in $r.timings_ms[$metric]) {
                    Require ([double]::IsFinite([double]$value) -and [double]$value -ge 0) 'Finite nonnegative milliseconds'
                    $metrics[$metric].Add([double]$value)
                }
            }
            $peaks.Add([double]$run.peak_working_set_bytes)
        }
        Require ($metrics.Count -eq $group.statistics_ms.Count) 'No missing aggregate metrics'
        foreach ($metric in @($metrics.Keys|Sort-Object)) {Require (SameStats $group.statistics_ms[$metric] (Stats $metrics[$metric].ToArray())) 'Independently recomputed nearest-rank statistics'}
        Require (SameStats $group.peak_process_working_set (Stats $peaks.ToArray())) 'Peak memory statistics'
    }
    return $true
}
[void](ValidateBundle $summary $manifest.files)
$negative=@()
if ($SelfTest) {
    foreach ($id in @('sampling_count','missing_cold','duplicate_process','wrong_p95','native_failure','raw_hash')) {
        $s=(Json $summary)|ConvertFrom-Json -AsHashtable
        $f=(Json $manifest.files)|ConvertFrom-Json -AsHashtable
        switch ($id) {
            'sampling_count' {$s.requested_warm=3}
            'missing_cold' {$s.runs=@($s.runs|Select-Object -Skip 1)}
            'duplicate_process' {$s.runs[1].name=$s.runs[0].name}
            'wrong_p95' {$s.groups[0].statistics_ms.durable_save_ms.p95+=100}
            'native_failure' {$s.runs[0].exit_code=1}
            'raw_hash' {$f[0].sha256='0'*64}
        }
        $rejected=$false
        try {[void](ValidateBundle $s $f)} catch {$rejected=$true;$reason=$_.Exception.Message}
        Require $rejected 'Invalid evidence bundle must fail'
        $negative+=@{id=$id;rejected=$rejected;reason=$reason}
    }
}
[ordered]@{ok=$true;checks=$checks;processes=160;groups=8;cold_per_group=20;warm_per_group=100;acceptance='MEASUREMENT_ONLY';negative=$negative}|ConvertTo-Json -Depth 6
