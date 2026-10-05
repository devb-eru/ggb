param(
    [string]$GamePath = (Join-Path $PSScriptRoot '../game'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Measure-ProducerRows($Entries) {
    $errors = [System.Collections.Generic.List[string]]::new()
    $index = @{}
    $latest = @{}
    foreach ($entry in $Entries) {
        $key = "$($entry.id)@$($entry.version)"
        if ($index.ContainsKey($key)) { $errors.Add("$key DUPLICATE_VERSION"); continue }
        $index[$key] = $entry
        if (-not $latest.ContainsKey($entry.id) -or $entry.version -gt $latest[$entry.id]) { $latest[$entry.id] = $entry.version }
        $row = $entry.definition
        if ($row.producer_id -notmatch '^NP(0[1-9]|1[0-9]|2[0-2])$') { $errors.Add("$key INVALID_PRODUCER") }
        if ($row.mapping_status -ne 'AUTHORED_ID') { $errors.Add("$key NOT_AUTHORED") }
        foreach ($field in @('mapping_status', 'disclosure_owner', 'source_file', 'source_symbol')) {
            if ([string]::IsNullOrWhiteSpace($row[$field])) { $errors.Add("$key MISSING_$field") }
        }
        $segments = @($row.visible_segment_ids)
        if ($segments.Count -eq 0 -or @($segments | Sort-Object -Unique).Count -ne $segments.Count) { $errors.Add("$key INVALID_SEGMENTS") }
        foreach ($locale in @('ko-KR', 'en-US')) {
            foreach ($segment in (@('title', 'summary') + $segments)) {
                if ([string]::IsNullOrWhiteSpace($row.locales[$locale][$segment])) { $errors.Add("$key MISSING_${locale}:$segment") }
            }
        }
    }
    $producers = foreach ($number in 1..22) {
        $id = 'NP{0:D2}' -f $number
        $all = @($index.Values | Where-Object { $_.definition.producer_id -eq $id })
        $current = @($all | Where-Object { $_.version -eq $latest[$_.id] })
        [ordered]@{
            producer = $id
            authored_ids = @($all.id | Sort-Object -Unique).Count
            semantic_versions = $all.Count
            latest_versions = $current.Count
            latest_segments = [int](($current | ForEach-Object { @($_.definition.visible_segment_ids).Count } | Measure-Object -Sum).Sum)
            catalogs = @($all.catalog | Sort-Object -Unique)
            runtime_coverage = 'NOT_AUDITED'
            legacy_count = $null
            excluded_count = $null
            unmapped_runtime_count = $null
            unexecuted_required_branches = $null
        }
    }
    return [ordered]@{
        ok = ($errors.Count -eq 0); errors = @($errors)
        authored_ids = $latest.Count; semantic_versions = $index.Count
        missing_ko_fields = @($errors | Where-Object { $_ -like '* MISSING_ko-KR:*' }).Count
        missing_en_fields = @($errors | Where-Object { $_ -like '* MISSING_en-US:*' }).Count
        producers = @($producers)
        scope = 'Registered catalog metadata only; not runtime route coverage or save-file inventory.'
    }
}

if ($SelfTest) {
    $definition = @{
        producer_id='NP01'; mapping_status='AUTHORED_ID'; disclosure_owner='display'
        source_file='fixture.gd'; source_symbol='show'; visible_segment_ids=@('body')
        locales=@{'ko-KR'=@{title='title';summary='summary';body='body'};'en-US'=@{title='title';summary='summary';body='body'}}
    }
    $fixture = @(@{id='A';version=1;catalog='old';definition=$definition}, @{id='A';version=2;catalog='new';definition=$definition})
    $valid = Measure-ProducerRows $fixture
    if (-not $valid.ok -or $valid.authored_ids -ne 1 -or $valid.semantic_versions -ne 2 -or $valid.producers[0].latest_segments -ne 1 -or $null -ne $valid.producers[0].unmapped_runtime_count) { throw 'Valid inventory or unknown-count semantics failed' }
    $duplicate = Measure-ProducerRows ($fixture + $fixture[0])
    if ($duplicate.ok -or 'A@1 DUPLICATE_VERSION' -notin $duplicate.errors) { throw 'Duplicate version missed' }
    foreach ($mutation in @('producer', 'locale', 'segments', 'owner', 'mapping')) {
        $copy = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        switch ($mutation) {
            'producer' { $copy[0].definition.producer_id='NP99' }
            'locale' { $copy[0].definition.locales['en-US'].Remove('body') }
            'segments' { $copy[0].definition.visible_segment_ids=@('body','body') }
            'owner' { $copy[0].definition.disclosure_owner='' }
            'mapping' { $copy[0].definition.mapping_status='UNKNOWN' }
        }
        if ((Measure-ProducerRows $copy).ok) { throw "Mutation missed: $mutation" }
    }
    'PRODUCER_INVENTORY_SELF_TEST: PASS (valid versions, unknown counts, six invalid fixtures)'
    exit 0
}

$source = Get-Content -LiteralPath (Join-Path $GamePath 'scripts/systems/notebook_content.gd') -Raw
$declarations = [regex]::Matches($source, '(?m)^const CATALOGS := (\[[^\r\n]*\])\r?$')
if ($declarations.Count -ne 1) { throw 'Unsupported CATALOGS declaration; update inventory parser explicitly' }
# The declaration is a JSON-compatible literal array; never execute source code.
$catalogs = @($declarations[0].Groups[1].Value | ConvertFrom-Json)
if (@($catalogs | Sort-Object -Unique).Count -ne $catalogs.Count) { throw 'Duplicate registered catalog' }
$entries = [System.Collections.Generic.List[object]]::new()
$fingerprints = @()
foreach ($catalog in $catalogs) {
    if ($catalog -notmatch '^res://data/notebook/[A-Za-z0-9_]+\.json$') { throw "Unexpected catalog path: $catalog" }
    $data = Get-Content -LiteralPath (Join-Path $GamePath $catalog.Substring(6)) -Raw | ConvertFrom-Json -AsHashtable
    $fingerprints += [ordered]@{catalog=$catalog;sha256=(Get-FileHash -LiteralPath (Join-Path $GamePath $catalog.Substring(6))).Hash}
    foreach ($id in $data.contents.Keys) {
        foreach ($version in $data.contents[$id].Keys) {
            if ($version -notmatch '^[1-9][0-9]*$') { throw "Invalid semantic version: $id@$version" }
            $entries.Add(@{id=$id;version=[int]$version;catalog=$catalog;definition=$data.contents[$id][$version]})
        }
    }
}
$result = Measure-ProducerRows $entries
$result.registered_catalogs = $catalogs.Count
$result.catalog_fingerprints = $fingerprints
$result | ConvertTo-Json -Depth 20
if (-not $result.ok) { exit 1 }
