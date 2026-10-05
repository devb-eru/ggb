param(
    [string]$GamePath = (Join-Path $PSScriptRoot '../game'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Read-CatalogEntries($Data, [string]$Catalog) {
    if ($Data -isnot [System.Collections.IDictionary] -or ($Data.format_version -isnot [long] -and $Data.format_version -isnot [int]) -or $Data.format_version -ne 1 -or $Data.contents -isnot [System.Collections.IDictionary]) {
        throw "$Catalog INVALID_CATALOG_FORMAT"
    }
    foreach ($id in $Data.contents.Keys) {
        $versions = $Data.contents[$id]
        if ([string]::IsNullOrWhiteSpace($id) -or $versions -isnot [System.Collections.IDictionary] -or $versions.Count -eq 0) { throw "$Catalog INVALID_VERSION_MAP" }
        foreach ($version in $versions.Keys) {
            if ($version -notmatch '^[1-9][0-9]*$' -or $versions[$version] -isnot [System.Collections.IDictionary]) { throw "$Catalog INVALID_VERSION_ROW" }
            @{id=$id;version=[int]$version;catalog=$Catalog;definition=$versions[$version]}
        }
    }
}

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
            if ($row.locales -isnot [System.Collections.IDictionary] -or $row.locales[$locale] -isnot [System.Collections.IDictionary]) {
                $errors.Add("$key MISSING_${locale}:locale")
                continue
            }
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
    foreach ($mutation in @('producer', 'locale', 'segments', 'owner', 'mapping', 'missing_locale', 'missing_locales')) {
        $copy = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        switch ($mutation) {
            'producer' { $copy[0].definition.producer_id='NP99' }
            'locale' { $copy[0].definition.locales['en-US'].Remove('body') }
            'segments' { $copy[0].definition.visible_segment_ids=@('body','body') }
            'owner' { $copy[0].definition.disclosure_owner='' }
            'mapping' { $copy[0].definition.mapping_status='UNKNOWN' }
            'missing_locale' { $copy[0].definition.locales.Remove('en-US') }
            'missing_locales' { $copy[0].definition.Remove('locales') }
        }
        if ((Measure-ProducerRows $copy).ok) { throw "Mutation missed: $mutation" }
    }
    $catalog = @{format_version=1;contents=@{A=@{'1'=$definition}}}
    if (@(Read-CatalogEntries $catalog 'valid').Count -ne 1) { throw 'Valid catalog rejected' }
    if (@(Read-CatalogEntries @{format_version=1;contents=@{}} 'empty').Count -ne 0) { throw 'Explicit empty catalog rejected' }
    foreach ($invalid in @(
        @{}, @{format_version=1}, @{format_version='1';contents=@{}}, @{format_version=2;contents=@{}},
        @{format_version=1;contents=@()}, @{format_version=1;contents=@{A=@()}},
        @{format_version=1;contents=@{A=@{}}}, @{format_version=1;contents=@{A=@{'0'=$definition}}},
        @{format_version=1;contents=@{A=@{'1'='not an object'}}}
    )) {
        $rejected = $false
        try { Read-CatalogEntries $invalid 'invalid' | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw 'Malformed catalog accepted' }
    }
    'PRODUCER_INVENTORY_SELF_TEST: PASS (valid/empty catalogs, versions, unknown counts, 17 invalid fixtures)'
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
    foreach ($entry in @(Read-CatalogEntries $data $catalog)) { $entries.Add($entry) }
}
$result = Measure-ProducerRows $entries
$result.registered_catalogs = $catalogs.Count
$result.catalog_fingerprints = $fingerprints
$result | ConvertTo-Json -Depth 20
if (-not $result.ok) { exit 1 }
