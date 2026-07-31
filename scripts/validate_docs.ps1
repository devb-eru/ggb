Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Add-ValidationError {
    param(
        [string]$Rule,
        [string]$Path,
        [string]$Detail
    )

    $errors.Add("$Rule`t$Path`t$Detail")
}

function Get-RepoRelativePath {
    param([string]$FullName)

    $resolvedRoot = (Resolve-Path -LiteralPath $repoRoot).Path.TrimEnd("\")
    $resolvedFile = (Resolve-Path -LiteralPath $FullName).Path
    if (-not $resolvedFile.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside repository: $resolvedFile"
    }
    return $resolvedFile.Substring($resolvedRoot.Length).TrimStart("\").Replace("\", "/")
}

$markdownRoots = @(
    (Join-Path $repoRoot "README.md"),
    (Join-Path $repoRoot "docs"),
    (Join-Path $repoRoot "ideas")
)

$markdownFiles = foreach ($root in $markdownRoots) {
    if (Test-Path -LiteralPath $root -PathType Leaf) {
        Get-Item -LiteralPath $root
    }
    elseif (Test-Path -LiteralPath $root -PathType Container) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.md"
    }
}

$markdownFiles = $markdownFiles | Sort-Object FullName -Unique

foreach ($file in $markdownFiles) {
    $relativePath = Get-RepoRelativePath $file.FullName

    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $text = $utf8.GetString($bytes)
    }
    catch {
        Add-ValidationError "UTF8" $relativePath $_.Exception.Message
        continue
    }

    if ($text -notmatch "(?m)^# ") {
        Add-ValidationError "H1" $relativePath "H1 heading is missing"
    }

    $fenceCount = ([regex]::Matches($text, '(?m)^```')).Count
    if (($fenceCount % 2) -ne 0) {
        Add-ValidationError "FENCE" $relativePath "unpaired fence count=$fenceCount"
    }

    $linkPattern = "\[[^\]]+\]\((?!https?://|mailto:|#)(?<target>[^)#]+)(?:#[^)]+)?\)"
    foreach ($match in [regex]::Matches($text, $linkPattern)) {
        $target = [uri]::UnescapeDataString($match.Groups["target"].Value.Trim([char[]]"<> "))
        if ($target -match "^[A-Za-z][A-Za-z0-9+.-]*:") {
            continue
        }

        $candidate = Join-Path $file.DirectoryName $target
        if (-not (Test-Path -LiteralPath $candidate)) {
            Add-ValidationError "LINK" $relativePath $target
        }
    }
}

$decisionIds = @{}
$decisionRoot = Join-Path $repoRoot "docs/decisions"
foreach ($file in Get-ChildItem -LiteralPath $decisionRoot -File -Filter "GGB-DEC-*.md") {
    $relativePath = Get-RepoRelativePath $file.FullName
    $filenameMatch = [regex]::Match($file.Name, "^(GGB-DEC-\d{4}-\d{4})_")
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    $bodyMatch = [regex]::Match($text, '(?m)^\| ID \| `(GGB-DEC-\d{4}-\d{4})` \|')

    if (-not $filenameMatch.Success -or -not $bodyMatch.Success) {
        Add-ValidationError "DEC_ID" $relativePath "filename or body ID is missing"
        continue
    }

    $filenameId = $filenameMatch.Groups[1].Value
    $bodyId = $bodyMatch.Groups[1].Value
    if ($filenameId -ne $bodyId) {
        Add-ValidationError "DEC_ID" $relativePath "filename=$filenameId body=$bodyId"
    }

    if ($decisionIds.ContainsKey($bodyId)) {
        Add-ValidationError "DEC_DUP" $relativePath "also used by $($decisionIds[$bodyId])"
    }
    else {
        $decisionIds[$bodyId] = $relativePath
    }
}

$issueIds = @{}
$issueRoot = Join-Path $repoRoot "ideas/md/v04/issues/items"
$issueRegistryPath = Get-ChildItem -LiteralPath (Join-Path $repoRoot "ideas/md/v04/issues") -File -Filter "*.md" |
    Where-Object { $_.Name -ne "README.md" } |
    Select-Object -First 1 -ExpandProperty FullName
$issueIndexPaths = @(
    (Join-Path $issueRoot "README.md"),
    $issueRegistryPath
)
foreach ($file in Get-ChildItem -LiteralPath $issueRoot -File -Filter "GGB-*.md") {
    $relativePath = Get-RepoRelativePath $file.FullName
    $filenameMatch = [regex]::Match($file.Name, "^(GGB-(?:CNF|ERR)-\d{4}-\d{4})_")
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    $bodyMatch = [regex]::Match($text, '(?m)^# (GGB-(?:CNF|ERR)-\d{4}-\d{4}):')

    if (-not $filenameMatch.Success -or -not $bodyMatch.Success) {
        Add-ValidationError "ISSUE_ID" $relativePath "filename or H1 ID is missing"
        continue
    }

    $filenameId = $filenameMatch.Groups[1].Value
    $bodyId = $bodyMatch.Groups[1].Value
    if ($filenameId -ne $bodyId) {
        Add-ValidationError "ISSUE_ID" $relativePath "filename=$filenameId body=$bodyId"
    }
    if ($issueIds.ContainsKey($bodyId)) {
        Add-ValidationError "ISSUE_DUP" $relativePath "also used by $($issueIds[$bodyId])"
    }
    else {
        $issueIds[$bodyId] = $relativePath
    }
}

foreach ($issueId in $issueIds.Keys) {
    foreach ($indexPath in $issueIndexPaths) {
        $indexText = [System.IO.File]::ReadAllText($indexPath, $utf8)
        if ($indexText -notmatch [regex]::Escape($issueId)) {
            Add-ValidationError "ISSUE_INDEX" (Get-RepoRelativePath $indexPath) $issueId
        }
    }
}

$cnfCount = @($issueIds.Keys | Where-Object { $_ -like "GGB-CNF-*" }).Count
$errCount = @($issueIds.Keys | Where-Object { $_ -like "GGB-ERR-*" }).Count
$issueCount = $issueIds.Count
$registryText = [System.IO.File]::ReadAllText($issueIndexPaths[1], $utf8)
$verifiedCountPattern = "(?m)^\| VERIFIED \| $cnfCount \| $errCount \| $issueCount \|$"
if ($registryText -notmatch $verifiedCountPattern) {
    Add-ValidationError "ISSUE_COUNT" (Get-RepoRelativePath $issueIndexPaths[1]) "expected CNF=$cnfCount ERR=$errCount total=$issueCount"
}

foreach ($file in Get-ChildItem -LiteralPath $decisionRoot -File -Filter "GGB-DEC-*.md") {
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    if ($text -match '(?m)^\| \x60GGB-(?:CNF|ERR)-\d{4}-\d{4}\x60 \|[^\r\n]*\| (?:BACKLOG|READY|IN_PROGRESS|REVIEW|BLOCKED) \|$') {
        Add-ValidationError "DECISION_FOLLOWUP_STATUS" (Get-RepoRelativePath $file.FullName) "linked resolved issue remains in an active work state"
    }
}

$registryDateMatch = [regex]::Match($registryText, '(?m)^- [^:\r\n]+: (?<date>\d{4}-\d{2}-\d{2})\.$')
if (-not $registryDateMatch.Success) {
    Add-ValidationError "VALIDATION_DATE" (Get-RepoRelativePath $issueIndexPaths[1]) "current registry date is missing"
}
else {
    $currentValidationDate = $registryDateMatch.Groups["date"].Value
    $dateContractPaths = @(
        (Get-ChildItem -LiteralPath (Join-Path $repoRoot "ideas/md/v04") -File -Filter "17_*Godot*.md" | Select-Object -First 1 -ExpandProperty FullName),
        (Get-ChildItem -LiteralPath (Join-Path $repoRoot "ideas/md/v04") -File -Filter "18_GGB_*.md" | Select-Object -First 1 -ExpandProperty FullName)
    )
    foreach ($path in $dateContractPaths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            Add-ValidationError "VALIDATION_DATE" "ideas/md/v04" "17 or 18 contract file is missing"
            continue
        }
        $text = [System.IO.File]::ReadAllText($path, $utf8)
        if ([System.IO.Path]::GetFileName($path).StartsWith("17_")) {
            $dateSection = [regex]::Match($text, '(?ms)^## 33\..*?(?=^## |\z)').Value
        }
        else {
            $dateSection = [regex]::Match($text, '(?ms)\A.*?(?=^## 2\.)').Value
        }
        if ($dateSection -notmatch [regex]::Escape($currentValidationDate)) {
            Add-ValidationError "VALIDATION_DATE" (Get-RepoRelativePath $path) "expected current date=$currentValidationDate"
        }
    }
}

$manifestPath = Join-Path $repoRoot "docs/asset_manifest.csv"
$requiredColumns = @(
    "asset_id", "source_entity_id", "asset_type", "variant", "build_scope",
    "required", "unit_count", "status", "is_placeholder", "owner", "reviewer",
    "target_milestone", "license_id", "evidence"
)
$allowedStatuses = @("PLANNED", "WORKING", "REVIEW", "APPROVED", "INTEGRATED", "REPLACED", "CUT")
$allowedScopes = @("demo_full", "full_only", "store_only")

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Add-ValidationError "ASSET_MANIFEST" "docs/asset_manifest.csv" "file is missing"
}
else {
    $manifest = @(Import-Csv -LiteralPath $manifestPath -Encoding utf8)
    $headers = if ($manifest.Count -gt 0) { $manifest[0].PSObject.Properties.Name } else { @() }
    foreach ($column in $requiredColumns) {
        if ($column -notin $headers) {
            Add-ValidationError "ASSET_COLUMN" "docs/asset_manifest.csv" $column
        }
    }

    $assetIds = @{}
    foreach ($row in $manifest) {
        if ([string]::IsNullOrWhiteSpace($row.asset_id)) {
            Add-ValidationError "ASSET_ID" "docs/asset_manifest.csv" "blank asset_id"
            continue
        }
        if ($assetIds.ContainsKey($row.asset_id)) {
            Add-ValidationError "ASSET_DUP" "docs/asset_manifest.csv" $row.asset_id
        }
        else {
            $assetIds[$row.asset_id] = $true
        }
        if ($row.status -notin $allowedStatuses) {
            Add-ValidationError "ASSET_STATUS" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.status)"
        }
        if ($row.build_scope -notin $allowedScopes) {
            Add-ValidationError "ASSET_SCOPE" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.build_scope)"
        }
        if ($row.required -notin @("true", "false")) {
            Add-ValidationError "ASSET_REQUIRED" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.required)"
        }
        if ($row.is_placeholder -notin @("true", "false")) {
            Add-ValidationError "ASSET_PLACEHOLDER" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.is_placeholder)"
        }
        $unitCount = 0
        if (-not [int]::TryParse($row.unit_count, [ref]$unitCount) -or $unitCount -lt 1) {
            Add-ValidationError "ASSET_COUNT" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.unit_count)"
        }
        if (
            $row.status -in @("APPROVED", "INTEGRATED") -and
            $row.license_id -eq "INTERNAL" -and
            $row.evidence -notmatch "(?:^|[;,\s])rights_ref=RIGHTS-\d{4}-\d{4}(?:$|[;,\s])"
        ) {
            Add-ValidationError "ASSET_RIGHTS" "docs/asset_manifest.csv" "$($row.asset_id) requires rights_ref=RIGHTS-YYYY-NNNN"
        }
    }
}

$currentContractFiles = @(
    (Join-Path $repoRoot "docs"),
    (Join-Path $repoRoot "ideas/md/v04")
)
$demoDefinitionPath = Join-Path $repoRoot "docs/demo_definition.md"
if (Test-Path -LiteralPath $demoDefinitionPath) {
    $demoDefinitionText = [System.IO.File]::ReadAllText($demoDefinitionPath, $utf8)
    if (
        $demoDefinitionText -notmatch 'sum\(unit_count where is_placeholder=true\)' -or
        $demoDefinitionText -notmatch 'build_scope\s*=\s*demo_full' -or
        $demoDefinitionText -notmatch 'required\s*=\s*true' -or
        $demoDefinitionText -notmatch 'status\s*!=\s*CUT'
    ) {
        Add-ValidationError "DEMO_PLACEHOLDER_RATIO" "docs/demo_definition.md" "use eligible unit_count weighted formula from asset_manifest.md"
    }
}

$d5StateContractPath = Get-ChildItem -LiteralPath (Join-Path $repoRoot "ideas/md/v04") -File -Filter "17_*Godot*.md" |
    Select-Object -First 1 -ExpandProperty FullName
$d5ContractPaths = @(
    $demoDefinitionPath,
    (Join-Path $repoRoot "docs/product_contract.md"),
    (Join-Path $repoRoot "docs/full_game_definition.md"),
    $d5StateContractPath
)
foreach ($path in $d5ContractPaths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        Add-ValidationError "D5_BUILD_BOUNDARY" "ideas/md/v04/17_*Godot*.md" "contract file is missing"
        continue
    }
    $relativeContractPath = $path.Substring($repoRoot.Length).TrimStart("\").Replace("\", "/")
    if (-not (Test-Path -LiteralPath $path)) {
        Add-ValidationError "D5_BUILD_BOUNDARY" $relativeContractPath "contract file is missing"
        continue
    }

    $text = [System.IO.File]::ReadAllText($path, $utf8)
    $hasDemoResume = $text -match 'SAVE_D5_COMPLETE[^\r\n]*DEMO_END_SCREEN'
    $hasFullResume = $text -match 'SAVE_D5_COMPLETE[^\r\n]*D6_FREE_INSPECTION|D6_FREE_INSPECTION[^\r\n]*SAVE_D5_COMPLETE'
    if (-not $hasDemoResume -or -not $hasFullResume) {
        Add-ValidationError "D5_BUILD_BOUNDARY" $relativeContractPath "demo must resume DEMO_END_SCREEN; full or approved import must resume D6_FREE_INSPECTION"
    }
}

$creditsPath = Join-Path $repoRoot "docs/third_party_credits.csv"
if (Test-Path -LiteralPath $creditsPath) {
    $credits = @(Import-Csv -LiteralPath $creditsPath -Encoding utf8)
    $creditHeaders = if ($credits.Count -gt 0) { $credits[0].PSObject.Properties.Name } else { @() }
    $creditRequiredColumns = @(
        "license_id", "item_name", "item_type", "asset_ids", "source_url",
        "license_name", "required_attribution", "modifications", "status", "evidence"
    )
    $creditAllowedStatuses = @(
        "POLICY_READY_SIGNATURES_PENDING", "PLANNED_RELEASE_ATTRIBUTION",
        "VERIFIED", "INCLUDED", "BLOCKED", "EXCLUDED"
    )
    foreach ($column in $creditRequiredColumns) {
        if ($column -notin $creditHeaders) {
            Add-ValidationError "CREDITS_COLUMN" "docs/third_party_credits.csv" $column
        }
    }
    $creditIds = @{}
    foreach ($row in $credits) {
        if ([string]::IsNullOrWhiteSpace($row.license_id)) {
            Add-ValidationError "CREDITS_ID" "docs/third_party_credits.csv" "blank license_id"
            continue
        }
        if ($creditIds.ContainsKey($row.license_id)) {
            Add-ValidationError "CREDITS_DUP" "docs/third_party_credits.csv" $row.license_id
        }
        else {
            $creditIds[$row.license_id] = $true
        }
        if ($row.status -notin $creditAllowedStatuses) {
            Add-ValidationError "CREDITS_STATUS" "docs/third_party_credits.csv" "$($row.license_id)=$($row.status)"
        }
        if (
            $row.license_id -eq "INTERNAL" -and
            $row.status -in @("VERIFIED", "INCLUDED") -and
            $row.evidence -notmatch '(?:^|[;,\s])rights_ref=RIGHTS-\d{4}-\d{4}(?:$|[;,\s])'
        ) {
            Add-ValidationError "CREDITS_RIGHTS" "docs/third_party_credits.csv" "INTERNAL cannot be VERIFIED or INCLUDED before verified rights_ref"
        }
    }
    if (
        (Test-Path -LiteralPath (Join-Path $repoRoot "game/project.godot")) -and
        @($credits | Where-Object { $_.license_id -eq "GODOT_ENGINE" -and $_.license_name -eq "MIT" }).Count -ne 1
    ) {
        Add-ValidationError "CREDITS_GODOT" "docs/third_party_credits.csv" "exactly one GODOT_ENGINE MIT runtime entry is required"
    }
}
foreach ($root in $currentContractFiles) {
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.md") {
        $relativePath = Get-RepoRelativePath $file.FullName
        if ($relativePath -like "ideas/md/v04/issues/*" -or $relativePath -eq "docs/project_review_2026-07-31.md") {
            continue
        }
        $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
        if ($text -match "schema_version\s*[:=]\s*12|progress schema 12|schema 9~12|from_schema:\s*10|to_schema:\s*12|FIX_LEGACY_V9|schema 8\uC758|schema 9\uC758|schema 10\uC758|\uC2A4\uD0A4\uB9C8 10\uC73C\uB85C") {
            Add-ValidationError "STALE_SAVE_VERSION" $relativePath "runtime schema 12 notation"
        }
        if ($text -match 'F2[^\r\n]*5\uC885|\uD544\uC218[^\r\n]*(?:\uC9C0\uC2DD|knowledge)\s*5\uC885|F2[^\r\n]*\uB2E4\uC12F\s+(?:\uD544\uC218\s+)?(?:\uC0AC\uC2E4|\uC9C0\uC2DD|required_knowledge)') {
            Add-ValidationError "STALE_F2_FACT_COUNT" $relativePath "F2 requires six knowledge entries"
        }
        if ($text -match '\uCEE8\uD2B8\uB864\uB7EC\s+\uC9C4\uB3D9') {
            Add-ValidationError "EXCLUDED_INPUT" $relativePath "controller haptics referenced in 1.0 contract"
        }
        if ($text -match '\uC5D4\uB529[^\r\n]*8~15\uBD84|\uAC01\s+8~15\uBD84') {
            Add-ValidationError "ENDING_DURATION" $relativePath "ending target must be 9~15 minutes"
        }
        if ($text -match '(?m)(N\s*/\s*5|N~N\uBD84|:\s*N(?:\uAC1C|\uBD84))') {
            Add-ValidationError "PLACEHOLDER" $relativePath "use semantic localization placeholders"
        }
        if ($text -match '\uAD8C\uC7A5\s+\uC9C4\uD589:\s*\uD575\uC2EC\s+\uAD00\uACC4\s+\uC774\uBCA4\uD2B8\s+3\uBA85\s+\uC774\uC0C1') {
            Add-ValidationError "RELATION_RECOMMENDATION" $relativePath "recommended relation route is two to three servants"
        }
        if ($text -match 'Windows\s+\uCD5C\uC18C\s+\uBC84\uC804|\uCD5C\uC18C\s+Windows\s+\uBC84\uC804') {
            Add-ValidationError "STALE_WINDOWS_SCOPE" $relativePath "Windows 10/11 64-bit is fixed; only hardware and renderer remain provisional"
        }
        if ($text -match '3\.5~5\.5\uC2DC\uAC04|3\uC2DC\uAC04\s*30\uBD84~5\uC2DC\uAC04\s*30\uBD84|\uAD8C\uC7A5\s+\uC9C4\uD589\s*\|\s*5~7\uC2DC\uAC04|\uAD00\uACC4\s+\uD3EC\uD568\s+\uAD8C\uC7A5[^\r\n]*\+45~70\uBD84') {
            Add-ValidationError "STALE_PLAYTIME" $relativePath "use 3:30-5:45 mandatory and current two-to-three-servant relation budget"
        }
    }
}

$gameRoot = Join-Path $repoRoot "game"
foreach ($file in Get-ChildItem -LiteralPath $gameRoot -Recurse -File) {
    if ($file.Name -like "*tmp*") {
        Add-ValidationError "TEMP_FILE" (Get-RepoRelativePath $file.FullName) "temporary file remains in game tree"
    }
}

Write-Host "Markdown files: $($markdownFiles.Count)"
Write-Host "Decision IDs: $($decisionIds.Count)"
Write-Host "Issue IDs: $issueCount (CNF $cnfCount, ERR $errCount)"
if (Test-Path -LiteralPath $manifestPath) {
    Write-Host "Asset rows: $((Import-Csv -LiteralPath $manifestPath -Encoding utf8).Count)"
}

if ($errors.Count -gt 0) {
    Write-Host "Validation errors: $($errors.Count)"
    $errors | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "PASS"
