# Read-only coverage check for 05_AUD_ID_사용처_호출표.md.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$audioRoot = $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $audioRoot '../../..'))
$usagePath = Join-Path $audioRoot '05_AUD_ID_사용처_호출표.md'
$sourcePaths = @(
    (Join-Path $audioRoot '01_공간앰비언스_전수명세.md'),
    (Join-Path $audioRoot '02_BGM_인격서명음_전수명세.md'),
    (Join-Path $audioRoot '03_퍼즐_전환_전수명세.md'),
    (Join-Path $audioRoot '04_공통SFX_전수명세.md')
)
$failures = [System.Collections.Generic.List[string]]::new()
$sourceText = ($sourcePaths | ForEach-Object { [System.IO.File]::ReadAllText($_, $utf8) }) -join "`n"
$usageText = [System.IO.File]::ReadAllText($usagePath, $utf8)
$parentPattern = '(?m)^\| `(?<id>(?:AUD|BGM|SFX)_[A-Z0-9_]+)`'
$expected = @([regex]::Matches($sourceText, $parentPattern) | ForEach-Object { $_.Groups['id'].Value } | Sort-Object -Unique)
$manifest = @(Import-Csv -LiteralPath (Join-Path $repoRoot 'docs/asset_manifest.csv') -Encoding UTF8 |
    Where-Object { $_.asset_id -match '^(AUD|BGM|SFX)_' } | ForEach-Object { $_.asset_id } | Sort-Object -Unique)
foreach ($difference in @(Compare-Object $expected $manifest)) {
    $failures.Add("SOURCE_MANIFEST: $($difference.InputObject) $($difference.SideIndicator)")
}
$definitionStart = $usageText.IndexOf('## 3.')
$definitionEnd = $usageText.IndexOf('## 9.')
if ($definitionStart -lt 0 -or $definitionEnd -le $definitionStart) {
    $failures.Add('STRUCTURE: parent definition range §3~§8 not found')
    $definitionText = ''
}
else {
    $definitionText = $usageText.Substring($definitionStart, $definitionEnd - $definitionStart)
}
$actual = @([regex]::Matches($definitionText, $parentPattern) | ForEach-Object { $_.Groups['id'].Value })
foreach ($id in $expected) {
    $count = @($actual | Where-Object { $_ -eq $id }).Count
    if ($count -ne 1) { $failures.Add("PARENT_USAGE: $id count=$count") }
}
foreach ($id in $actual) {
    if ($id -notin $expected) { $failures.Add("UNKNOWN_PARENT_USAGE: $id") }
}
$puzzleSource = [System.IO.File]::ReadAllText((Join-Path $audioRoot '03_퍼즐_전환_전수명세.md'), $utf8)
$puzzleUsage = [regex]::Match($usageText, '(?ms)^### 6\.1 하위 cue 호출 기준\r?\n(?<body>.*?)(?=^## 7\.)').Groups['body'].Value
$cueCount = 0
foreach ($line in ($puzzleSource -split '\r?\n')) {
    if ($line -notmatch '^\| `(AUD_PUZ_[A-Z0-9_]+)`') { continue }
    $parentId = $Matches[1]
    $cueColumn = ($line -split '\|')[5]
    foreach ($cue in [regex]::Matches($cueColumn, '`([A-Z][A-Z0-9_]+)`')) {
        $cueName = $cue.Groups[1].Value
        $cueCount++
        if ($puzzleUsage -notmatch ('`' + [regex]::Escape($cueName) + '`')) {
            $failures.Add("PUZZLE_CUE_USAGE: $parentId/$cueName")
        }
    }
}
foreach ($cueName in @('PRESSURE_WAIT_LOOP', 'COMPLETE_CIRCUIT_LOOP')) {
    if ($puzzleUsage -notmatch ('`' + $cueName + '`')) { $failures.Add("IMPLICIT_LOOP_USAGE: $cueName") }
}
foreach ($cueName in @('SLEEP', 'COMMIT', 'CUT', 'MORNING')) {
    $normalResetRow = [regex]::Match($usageText, '(?m)^\| `AUD_EVT_NORMAL_RESET`.*$').Value
    if ($normalResetRow -notmatch ('`' + $cueName + '`')) { $failures.Add("NORMAL_RESET_PART: $cueName") }
}
$runtimeRows = @([regex]::Matches($usageText, '(?m)^\| `(?<id>(?:AUD|BGM|SFX)_[A-Z0-9_]+)` \| [^\r\n]+ \| [^\r\n]+ \| 없음: 리소스 미등록 \|$'))
if ($runtimeRows.Count -ne 9) { $failures.Add("CURRENT_RUNTIME_ROWS: expected=9 actual=$($runtimeRows.Count)") }
if ($expected.Count -ne 97) { $failures.Add("EXPECTED_PARENT_COUNT: $($expected.Count)") }
if ($actual.Count -ne 97) { $failures.Add("ACTUAL_PARENT_COUNT: $($actual.Count)") }
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output $_ }
    throw "Audio usage validation failed: $($failures.Count) issue(s)."
}
Write-Output "PASS: $($expected.Count) manifest/source audio parents each have one usage definition."
Write-Output "PASS: $cueCount explicit puzzle cues and 2 maintained loops have action mappings."
Write-Output "PASS: 4 NORMAL_RESET parts and 9 current PLANNED runtime entries are documented."
