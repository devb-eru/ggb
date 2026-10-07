param(
    [string[]]$TraceLogs = @(),
    [string]$GamePath = (Join-Path $PSScriptRoot '../game'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function New-OrdinalMap {
    return ,([System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal))
}

function Test-Integer($Value) {
    return $Value -is [int] -or $Value -is [long]
}

function Test-RunReceipt($Receipt, [string]$StdoutHash, [string]$StderrHash) {
    return $Receipt -is [System.Collections.IDictionary] -and (Test-Integer $Receipt.schema_version) -and $Receipt.schema_version -eq 1 -and
        $Receipt.completed -is [bool] -and $Receipt.completed -and (Test-Integer $Receipt.exit_code) -and $Receipt.exit_code -eq 0 -and
        $Receipt.stdout_sha256 -ceq $StdoutHash -and $Receipt.stderr_sha256 -ceq $StderrHash
}

function Test-RunText([string]$Stdout, [string]$Stderr) {
    if ($Stdout -notmatch '(?m)^NOTEBOOK_[A-Z0-9_]+_SMOKE: PASS\r?$' -or $Stdout -match 'SCRIPT ERROR|Parse Error|Compile Error') { return $false }
    foreach ($line in ($Stderr -split '\r?\n')) {
        if ($line -match '^(SCRIPT ERROR|ERROR:)' -and $line -cne 'ERROR: Failed to read the root certificate store.') { return $false }
    }
    return $true
}

function Merge-Reports($Reports, $Context) {
    $errors = [System.Collections.Generic.List[string]]::new()
    $tuples = New-OrdinalMap
    $samples = [System.Collections.Generic.List[object]]::new()
    foreach ($report in $Reports) {
        if ($report -isnot [System.Collections.IDictionary] -or -not (Test-Integer $report.schema_version) -or $report.schema_version -ne 1 -or
            $report.ok -isnot [bool] -or -not $report.ok -or $report.suite_ok -isnot [bool] -or -not $report.suite_ok -or
            $report.errors -isnot [array] -or $report.errors.Count -ne 0 -or $report.tuples -isnot [array] -or
            [string]::IsNullOrWhiteSpace($report.suite_id) -or
            ($report.tuple_fields -join ',') -cne 'producer,content,version,node,variant,segment,locale') {
            $errors.Add('INVALID_OR_FAILED_REPORT'); continue
        }
        $fingerprints = $report.catalog_fingerprints
        if ($fingerprints -isnot [System.Collections.IDictionary] -or $fingerprints.Count -ne $Context.fingerprints.Count) {
            $errors.Add('CATALOG_MANIFEST_MISMATCH'); continue
        }
        $mismatch = $false
        foreach ($path in $Context.fingerprints.Keys) {
            if ($fingerprints[$path] -cne $Context.fingerprints[$path]) { $mismatch = $true }
        }
        if ($mismatch) { $errors.Add('STALE_CATALOG_CORPUS'); continue }
        if ($report.source_corpus -isnot [System.Collections.IDictionary] -or $report.source_corpus.basis -cne 'res://scripts/**/*.gd' -or
            $report.source_corpus.sha256 -cne $Context.source_corpus.sha256 -or
            -not (Test-Integer $report.source_corpus.file_count) -or $report.source_corpus.file_count -ne $Context.source_corpus.file_count) {
            $errors.Add('STALE_SCRIPT_CORPUS'); continue
        }
        if ($report.sampled_entry_classes -isnot [System.Collections.IDictionary] -or
            @('authored','legacy','unmapped' | Where-Object { -not (Test-Integer $report.sampled_entry_classes[$_]) -or $report.sampled_entry_classes[$_] -lt 0 }).Count -ne 0 -or
            $report.required_branch_coverage -cne 'NOT_AUDITED' -or $null -ne $report.new_unmapped_count -or $null -ne $report.excluded_ui_count) {
            $errors.Add('INVALID_SAMPLE_COUNTS_OR_SCOPE'); continue
        }
        $samples.Add([ordered]@{suite=$report.suite_id;sampled_entry_classes=$report.sampled_entry_classes})
        foreach ($tuple in $report.tuples) {
            if ($tuple -isnot [array] -or $tuple.Count -ne 7 -or -not (Test-Integer $tuple[2]) -or $tuple[2] -lt 1) {
                $errors.Add('INVALID_RUNTIME_TUPLE'); continue
            }
            $key = "$($tuple[1])@$($tuple[2])"
            if (-not $Context.definitions.ContainsKey($key)) { $errors.Add('UNKNOWN_RUNTIME_CONTENT_VERSION'); continue }
            $row = $Context.definitions[$key]
            if ($tuple[0] -cne $row.producer_id -or $tuple[4] -cne $row.action_or_variant -or
                @($row.node_ids) -cnotcontains $tuple[3] -or @($row.visible_segment_ids) -cnotcontains $tuple[5] -or
                @('ko-KR','en-US') -cnotcontains $tuple[6]) {
                $errors.Add('RUNTIME_IDENTITY_MISMATCH'); continue
            }
            $tuples[($tuple | ConvertTo-Json -Compress)] = $tuple
        }
    }
    $observed = New-OrdinalMap
    foreach ($tuple in $tuples.Values) { $observed["$($tuple[1])@$($tuple[2]):$($tuple[5]):$($tuple[6])"] = $true }
    $producers = foreach ($number in 1..22) {
        $id = 'NP{0:D2}' -f $number
        $expected = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $Context.latest.Keys) {
            $row = $Context.definitions[$key]
            if ($row.producer_id -cne $id) { continue }
            foreach ($segment in $row.visible_segment_ids) {
                foreach ($locale in @('ko-KR','en-US')) { $expected.Add("${key}:${segment}:${locale}") }
            }
        }
        [ordered]@{
            producer=$id
            observed_route_tuples=@($tuples.Values | Where-Object { $_[0] -ceq $id }).Count
            latest_registered_segment_locale_count=$expected.Count
            observed_latest_segment_locale_count=@($expected | Where-Object { $observed.ContainsKey($_) }).Count
            missing_latest_segment_locales=@($expected | Where-Object { -not $observed.ContainsKey($_) } | Sort-Object)
            required_branch_coverage='NOT_AUDITED'
            new_unmapped_count=$null; excluded_ui_count=$null; legacy_count_by_producer=$null
        }
    }
    return [ordered]@{
        schema_version=1;ok=($errors.Count -eq 0);errors=@($errors);report_count=@($Reports).Count
        distinct_runtime_route_tuples=$tuples.Count;producers=@($producers)
        observed_tuples=@($tuples.Keys | Sort-Object | ForEach-Object { ,$tuples[$_] })
        sampled_entry_counts_by_report=@($samples)
        count_basis='Route tuple union; entry counts are not summed across reports or asserted to be new writes.'
        scope='Sampled committed archives only. Registered segment coverage is not exhaustive required-branch or excluded-UI coverage.'
    }
}

if ($SelfTest) {
    $definitions = New-OrdinalMap
    $definitions['ID@1'] = @{producer_id='NP19';action_or_variant='RULE';node_ids=@('NODE');visible_segment_ids=@('body')}
    $latest = New-OrdinalMap
    $latest['ID@1'] = $true
    $context = @{definitions=$definitions;latest=$latest;fingerprints=@{catalog=('a'*64)};source_corpus=@{file_count=1;sha256=('b'*64)}}
    $report = @'
{"schema_version":1,"suite_id":"fixture","suite_ok":true,"ok":true,"errors":[],"tuple_fields":["producer","content","version","node","variant","segment","locale"],"tuples":[["NP19","ID",1,"NODE","RULE","body","ko-KR"]],"sampled_entry_classes":{"authored":1,"legacy":0,"unmapped":0},"required_branch_coverage":"NOT_AUDITED","new_unmapped_count":null,"excluded_ui_count":null}
'@ | ConvertFrom-Json -AsHashtable
    $report.catalog_fingerprints = $context.fingerprints.Clone()
    $report.source_corpus = @{basis='res://scripts/**/*.gd';file_count=1;sha256=('b'*64)}
    $valid = Merge-Reports @($report,$report) $context
    if (-not $valid.ok -or $valid.distinct_runtime_route_tuples -ne 1 -or $valid.producers[18].missing_latest_segment_locales.Count -ne 1 -or
        $null -ne $valid.producers[18].new_unmapped_count -or $valid.sampled_entry_counts_by_report.Count -ne 2 -or
        $valid.observed_tuples.Count -ne 1 -or $valid.observed_tuples[0].Count -ne 7 -or $valid.producers[18].observed_route_tuples -ne 1) { throw 'Union or unknown-count contract failed' }
    foreach ($mutation in @('failed','schema','catalog','script','unknown','case','version','node','variant','segment','locale','shape','counts','scope')) {
        $copy = $report | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        switch ($mutation) {
            'failed' { $copy.suite_ok=$false }
            'schema' { $copy.schema_version=2 }
            'catalog' { $copy.catalog_fingerprints.catalog='stale' }
            'script' { $copy.source_corpus.sha256='stale' }
            'unknown' { $copy.tuples[0][1]='UNKNOWN' }
            'case' { $copy.tuples[0][1]='id' }
            'version' { $copy.tuples[0][2]=2 }
            'node' { $copy.tuples[0][3]='OTHER' }
            'variant' { $copy.tuples[0][4]='OTHER' }
            'segment' { $copy.tuples[0][5]='hidden' }
            'locale' { $copy.tuples[0][6]='other' }
            'shape' { $copy.tuples[0]=@('NP19') }
            'counts' { $copy.sampled_entry_classes.authored=-1 }
            'scope' { $copy.new_unmapped_count=0 }
        }
        if ((Merge-Reports @($copy) $context).ok) { throw "Mutation missed: $mutation" }
    }
    $receipt = @{schema_version=1;completed=$true;exit_code=0;stdout_sha256=('a'*64);stderr_sha256=('b'*64)}
    if (-not (Test-RunReceipt $receipt ('a'*64) ('b'*64))) { throw 'Valid receipt rejected' }
    foreach ($mutation in @('failed','incomplete','tampered','schema','boolean_exit')) {
        $copy = $receipt.Clone()
        switch ($mutation) {
            'failed' { $copy.exit_code=1 }
            'incomplete' { $copy.completed=$false }
            'tampered' { $copy.stdout_sha256='changed' }
            'schema' { $copy.schema_version=2 }
            'boolean_exit' { $copy.exit_code=$false }
        }
        if (Test-RunReceipt $copy ('a'*64) ('b'*64)) { throw "Receipt mutation missed: $mutation" }
    }
    $pass = 'NOTEBOOK_FIXTURE_SMOKE: PASS'
    if (-not (Test-RunText $pass 'ERROR: Failed to read the root certificate store.')) { throw 'Valid log rejected' }
    foreach ($stderr in @('SCRIPT ERROR: failed','ERROR: failed','ERROR: Parse Error')) {
        if (Test-RunText $pass $stderr) { throw 'Failed stderr accepted' }
    }
    if ((Test-RunText 'not a PASS marker' '') -or (Test-RunText ($pass + "`nSCRIPT ERROR: failed") '')) { throw 'Invalid stdout accepted' }
    'RUNTIME_UNION_SELF_TEST: PASS (deduplication, unknown counts, missing locale, 14 invalid reports, 5 invalid receipts, 5 invalid logs)'
    exit 0
}

if ($TraceLogs.Count -eq 0) { throw 'Explicit trace log paths are required' }
$game = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\','/')
$inventory = (& (Join-Path $PSScriptRoot 'audit_notebook_producer_inventory.ps1') -GamePath $game | Out-String) | ConvertFrom-Json -AsHashtable
if (-not $inventory.ok) { throw 'Catalog inventory failed' }
$definitions = New-OrdinalMap
$latest = New-OrdinalMap
$fingerprints = @{}
foreach ($file in $inventory.catalog_fingerprints) {
    $fingerprints[$file.catalog] = $file.sha256.ToLowerInvariant()
    $data = Get-Content -LiteralPath (Join-Path $game $file.catalog.Substring(6)) -Raw | ConvertFrom-Json -AsHashtable
    foreach ($id in $data.contents.Keys) {
        $versions = $data.contents[$id]
        $last = @($versions.Keys | ForEach-Object { [int]$_ } | Sort-Object -Descending)[0]
        foreach ($version in $versions.Keys) { $definitions["${id}@${version}"] = $versions[$version] }
        $latest["${id}@${last}"] = $true
    }
}
$scriptRows = New-OrdinalMap
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $game 'scripts') -Recurse -File -Filter '*.gd') {
    $path = 'res://' + $file.FullName.Substring($game.Length+1).Replace('\','/')
    $scriptRows[$path] = (Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()
}
$keys = [string[]]@($scriptRows.Keys)
[Array]::Sort($keys,[StringComparer]::Ordinal)
$wire = (@($keys | ForEach-Object { $_ + "`t" + $scriptRows[$_] }) -join "`n")
$sourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($wire))).ToLowerInvariant()
$context = @{definitions=$definitions;latest=$latest;fingerprints=$fingerprints;source_corpus=@{sha256=$sourceHash;file_count=$keys.Count}}
$reports = [System.Collections.Generic.List[object]]::new()
foreach ($path in $TraceLogs) {
    if ($path -notmatch '\.out\.log$') { throw 'Trace logs must have .out.log names with matching stderr and run receipt' }
    $stderr = $path -replace '\.out\.log$', '.err.log'
    $receiptPath = $path -replace '\.out\.log$', '.run.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
    if (-not (Test-RunReceipt $receipt (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() (Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant())) { throw 'Missing, failed, or altered run receipt' }
    $text = Get-Content -LiteralPath $path -Raw
    if (-not (Test-RunText $text (Get-Content -LiteralPath $stderr -Raw))) { throw 'PASS marker and error-free logs required (except known certificate-store warning)' }
    $found = 0
    foreach ($line in ($text -split '\r?\n')) {
        if (-not $line.StartsWith('NOTEBOOK_RUNTIME_AUDIT: ')) { continue }
        $reports.Add(($line.Substring('NOTEBOOK_RUNTIME_AUDIT: '.Length) | ConvertFrom-Json -AsHashtable))
        $found += 1
    }
    if ($found -eq 0) { throw 'No explicit runtime audit in log; totals alone are not coverage evidence' }
}
$result = Merge-Reports $reports $context
$result.source_corpus = $context.source_corpus
$result.catalog_fingerprints = $fingerprints
$result | ConvertTo-Json -Depth 30
if (-not $result.ok) { exit 1 }
