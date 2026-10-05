param(
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../game/data/notebook'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'

function Test-ChoiceRows($Index) {
    $errors = [System.Collections.Generic.List[string]]::new()
    $rows = [System.Collections.Generic.List[object]]::new()
    $latest = @{}
    foreach ($entry in $Index.Values) {
        if (-not $latest.ContainsKey($entry.id) -or $entry.version -gt $latest[$entry.id]) { $latest[$entry.id] = $entry.version }
    }
    foreach ($entry in ($Index.Values | Sort-Object id, version)) {
        $row = $entry.definition
        if ($null -eq $row.choices) { continue }
        $label = "$($entry.id)@$($entry.version)"
        if (@($row.choices).Count -eq 0) { $errors.Add("$label EMPTY_CHOICES"); continue }
        if ([string]::IsNullOrWhiteSpace($row.producer_id)) { $errors.Add("$label MISSING_PRODUCER") }
        $cancel = $row.cancel_index
        if ($null -eq $cancel -or $cancel -lt -1 -or $cancel -ge @($row.choices).Count) { $errors.Add("$label CANCEL_INDEX") }
        $targets = @()
        for ($i = 0; $i -lt @($row.choices).Count; $i++) {
            $choice = $row.choices[$i]
            $kind = switch ($choice.kind) {
                'ui' { 'ui' }
                'cancel' { 'choice_cancelled' }
                'confirm' { 'choice_confirmed' }
                'choice_cancelled' { 'choice_cancelled' }
                'choice_confirmed' { 'choice_confirmed' }
                default { '' }
            }
            if (-not $kind) { $errors.Add("$label OPTION_$i UNKNOWN_KIND") }
            if ($cancel -eq $i -and $kind -notin @('choice_cancelled', 'ui')) { $errors.Add("$label CANCEL_DISPATCHES_ACTION") }
            $target = $null
            if ($kind -eq 'ui') {
                if ($choice.content_id) { $errors.Add("$label OPTION_$i UI_HAS_RECORD") }
            } else {
                # The shared controller records choice descriptors at version 1.
                $target = $Index["$($choice.content_id)@1"]
                if (-not $target) { $errors.Add("$label OPTION_$i MISSING_V1_TARGET") }
                elseif ($target.definition.entry_kind -ne $kind) { $errors.Add("$label OPTION_$i TARGET_KIND") }
            }
            foreach ($locale in @('ko-KR', 'en-US')) {
                $options = $row.locales.$locale
                $text = if ($null -ne $options) { $options.("option_$i") } else { $null }
                if ([string]::IsNullOrWhiteSpace($text)) { $errors.Add("$label OPTION_$i MISSING_$locale") }
                if ($target) {
                    $selected = $target.definition.locales.$locale.body
                    if ([string]::IsNullOrWhiteSpace($selected) -or $text -cne $selected) { $errors.Add("$label OPTION_$i LABEL_MISMATCH_$locale") }
                }
            }
            $targets += [ordered]@{ index = $i; kind = $choice.kind; entry_kind = $kind; content_id = $choice.content_id; version = $(if ($kind -eq 'ui') { $null } else { 1 }) }
        }
        $rows.Add([ordered]@{
            id = $entry.id; version = $entry.version; current = ($entry.version -eq $latest[$entry.id])
            producer = $row.producer_id; catalog = $entry.catalog; cancel_index = $cancel; choices = $targets
        })
    }
    return @{ ok = ($errors.Count -eq 0); errors = @($errors); rows = @($rows) }
}

if ($SelfTest) {
    $fixture = @{
        'OPTIONS@1' = @{
            id = 'OPTIONS'; version = 1; catalog = 'fixture'
            definition = @{
                producer_id = 'NP05'; cancel_index = 1
                choices = @(@{kind='ui'; content_id=''}, @{kind='cancel'; content_id='CANCEL'}, @{kind='confirm'; content_id='YES'})
                locales = @{ 'ko-KR' = @{option_0='review';option_1='cancel';option_2='yes'}; 'en-US' = @{option_0='review';option_1='cancel';option_2='yes'} }
            }
        }
        'CANCEL@1' = @{id='CANCEL';version=1;catalog='fixture';definition=@{entry_kind='choice_cancelled';locales=@{'ko-KR'=@{body='cancel'};'en-US'=@{body='cancel'}}}}
        'YES@1' = @{id='YES';version=1;catalog='fixture';definition=@{entry_kind='choice_confirmed';locales=@{'ko-KR'=@{body='yes'};'en-US'=@{body='yes'}}}}
    }
    if (-not (Test-ChoiceRows $fixture).ok) { throw 'Valid fixture rejected' }
    $uiDismissal = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    $uiDismissal['OPTIONS@1'].definition.cancel_index = 0
    if (-not (Test-ChoiceRows $uiDismissal).ok) { throw 'Valid UI dismissal rejected' }
    $longKinds = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    $longKinds['OPTIONS@1'].definition.choices[1].kind = 'choice_cancelled'
    $longKinds['OPTIONS@1'].definition.choices[2].kind = 'choice_confirmed'
    if (-not (Test-ChoiceRows $longKinds).ok) { throw 'Valid long-form kinds rejected' }
    $mutations = @(
        @{code='MISSING_V1_TARGET'; apply={param($x) $x.Remove('YES@1')}},
        @{code='TARGET_KIND'; apply={param($x) $x['YES@1'].definition.entry_kind='choice_cancelled'}},
        @{code='LABEL_MISMATCH_en-US'; apply={param($x) $x['YES@1'].definition.locales['en-US'].body='other'}},
        @{code='MISSING_ko-KR'; apply={param($x) $x['OPTIONS@1'].definition.locales['ko-KR'].Remove('option_2')}},
        @{code='CANCEL_DISPATCHES_ACTION'; apply={param($x) $x['OPTIONS@1'].definition.cancel_index=2}},
        @{code='CANCEL_INDEX'; apply={param($x) $x['OPTIONS@1'].definition.cancel_index=9}},
        @{code='UNKNOWN_KIND'; apply={param($x) $x['OPTIONS@1'].definition.choices[2].kind='unknown'}},
        @{code='UI_HAS_RECORD'; apply={param($x) $x['OPTIONS@1'].definition.choices[0].content_id='YES'}},
        @{code='EMPTY_CHOICES'; apply={param($x) $x['OPTIONS@1'].definition.choices=@()}},
        @{code='MISSING_PRODUCER'; apply={param($x) $x['OPTIONS@1'].definition.producer_id=''}}
    )
    foreach ($mutation in $mutations) {
        $copy = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        & $mutation.apply $copy | Out-Null
        $result = Test-ChoiceRows $copy
        if ($result.ok -or -not ($result.errors | Where-Object { $_.EndsWith($mutation.code) })) { throw "Mutation missed: $($mutation.code)" }
    }
    @{ok=$true; valid_fixtures=3; rejected_mutations=$mutations.Count} | ConvertTo-Json
    exit 0
}

$index = @{}
$sources = @()
foreach ($file in (Get-ChildItem -LiteralPath $CatalogPath -Filter '*.json' -File | Sort-Object Name)) {
    $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    if ($null -eq $document.contents) { continue }
    $sources += @{catalog=$file.Name;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash}
    foreach ($content in $document.contents.PSObject.Properties) {
        foreach ($version in $content.Value.PSObject.Properties) {
            $key = "$($content.Name)@$($version.Name)"
            if ($index.ContainsKey($key)) { throw "Duplicate catalog definition: $key" }
            $index[$key] = @{id=$content.Name;version=[int]$version.Name;catalog=$file.Name;definition=$version.Value}
        }
    }
}
if ($index.Count -eq 0) { throw 'No content catalogs found' }
$result = Test-ChoiceRows $index
$result.sources = $sources
$result.definition_count = $index.Count
$result.choice_versions = $result.rows.Count
$result.current_choice_ids = @($result.rows | Where-Object current).Count
$result.producers = @($result.rows | Group-Object -Property { $_.producer } | Sort-Object Name | ForEach-Object {
    @{producer=$_.Name;versions=$_.Count;current=@($_.Group | Where-Object current).Count}
})
$result | ConvertTo-Json -Depth 20
if (-not $result.ok) { exit 1 }
