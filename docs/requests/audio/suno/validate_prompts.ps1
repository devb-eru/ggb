# Read-only coverage checks for the adjacent Suno prompt documents.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$audioRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $audioRoot '../../..'))
$failures = [System.Collections.Generic.List[string]]::new()
$sourceFiles = @(Get-ChildItem -LiteralPath $audioRoot -Filter '*_*.md' -File)
$promptFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.md' -File)
$sourceText = ($sourceFiles | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName, $utf8) }) -join "`n"
$texts = @{}
foreach ($file in $promptFiles) {
    $texts[$file.Name] = [System.IO.File]::ReadAllText($file.FullName, $utf8)
}
$allPrompts = $texts.Values -join "`n"
$idPattern = '(?m)^\| `(?<id>(?:AUD|BGM|SFX)_[A-Z0-9_]+)`'
$expected = @([regex]::Matches($sourceText, $idPattern) | ForEach-Object { $_.Groups['id'].Value } | Sort-Object -Unique)
$manifest = @(Import-Csv -LiteralPath (Join-Path $repoRoot 'docs/asset_manifest.csv') -Encoding UTF8 |
    Where-Object { $_.asset_id -match '^(AUD|BGM|SFX)_' } | ForEach-Object { $_.asset_id } | Sort-Object -Unique)
foreach ($difference in @(Compare-Object $expected $manifest)) {
    $failures.Add("SOURCE_MANIFEST: $($difference.InputObject) $($difference.SideIndicator)")
}
$authored = @([regex]::Matches($allPrompts, $idPattern) | ForEach-Object { $_.Groups['id'].Value })
$authored += @([regex]::Matches($allPrompts, '(?m)^## (AUD_PUZ_[A-Z0-9_]+)\r?$') | ForEach-Object { $_.Groups[1].Value })
foreach ($id in $expected) {
    $count = @($authored | Where-Object { $_ -eq $id }).Count
    if ($count -ne 1) { $failures.Add("PARENT: $id count=$count") }
}
foreach ($id in $authored) {
    if ($id -notin $expected) { $failures.Add("UNKNOWN_PARENT: $id") }
}
$puzzleText = $texts['03_퍼즐.md']
$cueCount = 0
foreach ($line in ($sourceText -split '\r?\n')) {
    if ($line -notmatch '^\| `(AUD_PUZ_[A-Z0-9_]+)`') { continue }
    $id = $Matches[1]
    $cueColumn = ($line -split '\|')[5]
    $section = [regex]::Match($puzzleText, '(?ms)^## ' + [regex]::Escape($id) + '\r?\n(?<body>.*?)(?=^## |\z)').Groups['body'].Value
    foreach ($cue in [regex]::Matches($cueColumn, '`([A-Z][A-Z0-9_]+)`')) {
        $name = $cue.Groups[1].Value
        $cueCount++
        if ($section -notmatch ('(?m)^\| `' + [regex]::Escape($name) + '` \| `[^`]+` \|')) {
            $failures.Add("PUZZLE_CUE: $id/$name missing prompt row")
        }
    }
}
foreach ($name in @('PRESSURE_WAIT_LOOP', 'COMPLETE_CIRCUIT_LOOP')) {
    if ($puzzleText -notmatch ('(?m)^\| `' + $name + '` \| `[^`]+` \|')) {
        $failures.Add("IMPLICIT_LOOP: $name")
    }
}
$foley = @(
    'FOOTSTEP_WOOD', 'FOOTSTEP_CARPET', 'FOOTSTEP_STONE', 'FOOTSTEP_METAL',
    'DOOR_WOOD', 'DOOR_GLASS', 'DOOR_FACILITY', 'DOOR_AIRLOCK',
    'PAPER', 'BOOK', 'GRAPHITE', 'CLOTH', 'BRUSH', 'TOOL', 'GLASS', 'MIRROR',
    'LIQUID', 'TABLEWARE', 'FAN', 'RELAY', 'PUMP', 'GEAR', 'FIXTURE'
)
foreach ($name in $foley) {
    if ($texts['05_효과음과폴리.md'] -notmatch ('(?m)^\| `FOL_' + $name + '` \| `[^`]+`')) {
        $failures.Add("FOLEY: FOL_$name")
    }
}
foreach ($file in $promptFiles) {
    $body = $texts[$file.Name]
    if (([regex]::Matches($body, '(?m)^```').Count % 2) -ne 0) { $failures.Add("FENCE: $($file.Name)") }
    if ($body -match '[\u3040-\u30ff\ufffd]') { $failures.Add("UNEXPECTED_TEXT: $($file.Name)") }
    foreach ($link in [regex]::Matches($body, '\[[^\]]+\]\((?!https?://|#)([^)#]+)(?:#[^)]*)?\)')) {
        $target = [uri]::UnescapeDataString($link.Groups[1].Value.Trim('<', '>'))
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $target))) { $failures.Add("LINK: $($file.Name) -> $target") }
    }
}
if ($expected.Count -ne 97) { $failures.Add("EXPECTED_PARENT_COUNT: $($expected.Count), review scope") }
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output $_ }
    throw "Prompt validation failed: $($failures.Count) issue(s)."
}
Write-Output "PASS: $($expected.Count) source/manifest parents, each with one prompt definition."
Write-Output "PASS: $cueCount explicitly named puzzle cues and 2 implicit maintained loops."
Write-Output "PASS: $($foley.Count) expanded foley units; UTF-8, local links and fences."
Write-Output 'NOTE: musical intent, variant semantics and generated audio quality require separate review.'
