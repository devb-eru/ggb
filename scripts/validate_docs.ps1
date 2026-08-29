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
    (Join-Path $repoRoot "CONTRIBUTING.md"),
    (Join-Path $repoRoot "THIRD_PARTY_NOTICES.md"),
    (Join-Path $repoRoot "docs"),
    (Join-Path $repoRoot "ideas"),
    (Join-Path $repoRoot "game")
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

$milestonePath = Join-Path $repoRoot "docs/milestones.md"
$milestoneIds = @{}
if (-not (Test-Path -LiteralPath $milestonePath -PathType Leaf)) {
    Add-ValidationError "MILESTONE_REGISTRY" "docs/milestones.md" "file is missing"
}
else {
    $milestoneText = [System.IO.File]::ReadAllText($milestonePath, $utf8)
    foreach ($match in [regex]::Matches($milestoneText, '(?m)^\| `(?<id>[A-Z][A-Z0-9_]+)` \|')) {
        $milestoneId = $match.Groups["id"].Value
        if ($milestoneIds.ContainsKey($milestoneId)) {
            Add-ValidationError "MILESTONE_DUP" "docs/milestones.md" $milestoneId
        }
        else {
            $milestoneIds[$milestoneId] = $true
        }
    }
    if ($milestoneIds.Count -eq 0) {
        Add-ValidationError "MILESTONE_REGISTRY" "docs/milestones.md" "no milestone IDs found"
    }
}

$objectCatalogPath = Join-Path $repoRoot "docs/game_object_catalog.csv"
$objectIds = @{}
$objectRows = @()
if (-not (Test-Path -LiteralPath $objectCatalogPath -PathType Leaf)) {
    Add-ValidationError "OBJECT_CATALOG" "docs/game_object_catalog.csv" "file is missing"
}
else {
    $objectRows = @(Import-Csv -LiteralPath $objectCatalogPath -Encoding utf8)
    foreach ($row in $objectRows) {
        if ($row.object_id -notmatch '^(?:OBJ|SERVANT_OBJ)_[A-Z0-9_]+$') {
            Add-ValidationError "OBJECT_ID" "docs/game_object_catalog.csv" $row.object_id
            continue
        }
        if ($objectIds.ContainsKey($row.object_id)) {
            Add-ValidationError "OBJECT_DUP" "docs/game_object_catalog.csv" $row.object_id
        }
        else {
            $objectIds[$row.object_id] = $true
        }
    }

    $clockLocationContracts = @{
        "OBJ_LIBRARY_OUTER_CLOCK" = "M1_LIBRARY_OUTER"
        "OBJ_LIBRARY_RECORD_CLOCK" = "M1_LIBRARY_INNER"
    }
    foreach ($clockId in $clockLocationContracts.Keys) {
        $clockRows = @($objectRows | Where-Object { $_.object_id -eq $clockId })
        if ($clockRows.Count -ne 1) {
            Add-ValidationError "CLOCK_OBJECT_CONTRACT" "docs/game_object_catalog.csv" "$clockId count=$($clockRows.Count)"
            continue
        }
        if ($clockRows[0].location_ids -ne $clockLocationContracts[$clockId]) {
            Add-ValidationError "CLOCK_LOCATION_CONTRACT" "docs/game_object_catalog.csv" "$clockId=$($clockRows[0].location_ids)"
        }
    }
}

$objectContractFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot "docs") -File -Filter "*.md" |
        Where-Object { $_.Name -notlike "project_review_*.md" }
    Get-ChildItem -LiteralPath (Join-Path $repoRoot "ideas/md/v04") -File -Filter "*.md"
)
foreach ($file in $objectContractFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    foreach ($match in [regex]::Matches($text, '(?<![A-Z0-9_])(?<id>(?:SERVANT_)?OBJ_[A-Z0-9_]+)(?![A-Z0-9_*])')) {
        $objectId = $match.Groups["id"].Value
        if ($objectId.EndsWith("_") -or $objectIds.ContainsKey($objectId)) {
            continue
        }
        Add-ValidationError "OBJECT_REF" (Get-RepoRelativePath $file.FullName) $objectId
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

    $targetMatch = [regex]::Match($text, '(?m)^\| 목표 마일스톤 \| `(?<id>[A-Z][A-Z0-9_]+)` \|$')
    if (-not $targetMatch.Success) {
        Add-ValidationError "ISSUE_MILESTONE" $relativePath "target milestone is missing"
    }
    elseif (-not $milestoneIds.ContainsKey($targetMatch.Groups["id"].Value)) {
        Add-ValidationError "ISSUE_MILESTONE" $relativePath $targetMatch.Groups["id"].Value
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
$issueStatusPattern = '(?m)^\| (OPEN|IN_PROGRESS|BLOCKED|RESOLVED|VERIFIED|DEFERRED|WONT_FIX) \| (\d+) \| (\d+) \| (\d+) \|$'
$issueStatusRows = [regex]::Matches($registryText, $issueStatusPattern)
$registryCnfCount = 0
$registryErrCount = 0
$registryIssueCount = 0
foreach ($statusRow in $issueStatusRows) {
    $registryCnfCount += [int]$statusRow.Groups[2].Value
    $registryErrCount += [int]$statusRow.Groups[3].Value
    $registryIssueCount += [int]$statusRow.Groups[4].Value
}
if (
    $issueStatusRows.Count -ne 7 -or
    $registryCnfCount -ne $cnfCount -or
    $registryErrCount -ne $errCount -or
    $registryIssueCount -ne $issueCount
) {
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
$assetIds = @{}

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
        if (-not $milestoneIds.ContainsKey($row.target_milestone)) {
            Add-ValidationError "ASSET_MILESTONE" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.target_milestone)"
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
        if (
            $row.source_entity_id -match '^(?:OBJ|SERVANT_OBJ)_[A-Z0-9_]+$' -and
            -not $objectIds.ContainsKey($row.source_entity_id)
        ) {
            Add-ValidationError "ASSET_OBJECT_REF" "docs/asset_manifest.csv" "$($row.asset_id)=$($row.source_entity_id)"
        }
    }

    foreach ($objectRow in $objectRows) {
        if (-not $assetIds.ContainsKey($objectRow.art_asset_id)) {
            Add-ValidationError "OBJECT_ASSET_REF" "docs/game_object_catalog.csv" "$($objectRow.object_id)=$($objectRow.art_asset_id)"
        }
    }

    $outerClockAssetRows = @($manifest | Where-Object {
        $_.asset_id -eq "ART_OBJ_LIBRARY_OUTER_CLOCK" -and
        $_.source_entity_id -eq "OBJ_LIBRARY_OUTER_CLOCK" -and
        $_.asset_type -eq "object_state"
    })
    if ($outerClockAssetRows.Count -ne 1) {
        Add-ValidationError "CLOCK_ASSET_CONTRACT" "docs/asset_manifest.csv" "ART_OBJ_LIBRARY_OUTER_CLOCK -> OBJ_LIBRARY_OUTER_CLOCK count=$($outerClockAssetRows.Count)"
    }
}

$requestRegisterPath = Join-Path $repoRoot "docs/requests/request_register.csv"
$requestRequiredColumns = @(
    "request_id", "team", "batch_id", "title", "build_scope", "priority",
    "status", "owner", "reviewer", "target_milestone", "source_ids",
    "asset_ids", "brief_path", "depends_on", "acceptance_gate", "evidence"
)
$requestAllowedTeams = @("ART", "AUD", "CNT")
$requestAllowedScopes = @("vertical_slice", "demo_remainder", "full_only", "store_only")
$requestAllowedStatuses = @(
    "PLANNED", "DRAFT", "READY_FOR_ACCEPTANCE", "ACCEPTED", "IN_PROGRESS",
    "REVIEW", "APPROVED", "INTEGRATED", "CHANGES_REQUESTED", "CANCELLED"
)
$requestIds = @{}

if (-not (Test-Path -LiteralPath $requestRegisterPath)) {
    Add-ValidationError "REQUEST_REGISTER" "docs/requests/request_register.csv" "file is missing"
}
else {
    $requests = @(Import-Csv -LiteralPath $requestRegisterPath -Encoding utf8)
    $requestHeaders = if ($requests.Count -gt 0) { $requests[0].PSObject.Properties.Name } else { @() }
    foreach ($column in $requestRequiredColumns) {
        if ($column -notin $requestHeaders) {
            Add-ValidationError "REQUEST_COLUMN" "docs/requests/request_register.csv" $column
        }
    }

    foreach ($row in $requests) {
        if ($row.request_id -notmatch '^REQ-(ART|AUD|CNT)-\d{4}-\d{4}$') {
            Add-ValidationError "REQUEST_ID" "docs/requests/request_register.csv" $row.request_id
            continue
        }
        $idTeam = $Matches[1]
        if ($requestIds.ContainsKey($row.request_id)) {
            Add-ValidationError "REQUEST_DUP" "docs/requests/request_register.csv" $row.request_id
        }
        else {
            $requestIds[$row.request_id] = $true
        }
        if ($row.team -notin $requestAllowedTeams -or $row.team -ne $idTeam) {
            Add-ValidationError "REQUEST_TEAM" "docs/requests/request_register.csv" "$($row.request_id)=$($row.team)"
        }
        if ($row.build_scope -notin $requestAllowedScopes) {
            Add-ValidationError "REQUEST_SCOPE" "docs/requests/request_register.csv" "$($row.request_id)=$($row.build_scope)"
        }
        if ($row.status -notin $requestAllowedStatuses) {
            Add-ValidationError "REQUEST_STATUS" "docs/requests/request_register.csv" "$($row.request_id)=$($row.status)"
        }
        if (-not $milestoneIds.ContainsKey($row.target_milestone)) {
            Add-ValidationError "REQUEST_MILESTONE" "docs/requests/request_register.csv" "$($row.request_id)=$($row.target_milestone)"
        }
        if ([string]::IsNullOrWhiteSpace($row.owner) -or [string]::IsNullOrWhiteSpace($row.reviewer)) {
            Add-ValidationError "REQUEST_OWNER" "docs/requests/request_register.csv" $row.request_id
        }
        if ([string]::IsNullOrWhiteSpace($row.source_ids)) {
            Add-ValidationError "REQUEST_SOURCE" "docs/requests/request_register.csv" $row.request_id
        }

        if ($row.team -in @("ART", "AUD")) {
            if ([string]::IsNullOrWhiteSpace($row.asset_ids)) {
                if ($row.status -ne "PLANNED") {
                    Add-ValidationError "REQUEST_ASSET" "docs/requests/request_register.csv" "$($row.request_id) has no asset_ids"
                }
            }
            else {
                foreach ($assetId in $row.asset_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                    $trimmedAssetId = $assetId.Trim()
                    if (-not $assetIds.ContainsKey($trimmedAssetId)) {
                        Add-ValidationError "REQUEST_ASSET" "docs/requests/request_register.csv" "$($row.request_id) references $trimmedAssetId"
                    }
                }
            }
        }

        if ($row.status -in @("READY_FOR_ACCEPTANCE", "ACCEPTED", "IN_PROGRESS", "REVIEW", "APPROVED", "INTEGRATED", "CHANGES_REQUESTED")) {
            if ([string]::IsNullOrWhiteSpace($row.brief_path) -or $row.brief_path -eq "TBD") {
                Add-ValidationError "REQUEST_BRIEF" "docs/requests/request_register.csv" "$($row.request_id) has no brief_path"
                continue
            }
            $briefPath = Join-Path $repoRoot $row.brief_path
            if (-not (Test-Path -LiteralPath $briefPath -PathType Leaf)) {
                Add-ValidationError "REQUEST_BRIEF" "docs/requests/request_register.csv" "$($row.request_id) missing $($row.brief_path)"
                continue
            }
            $briefText = [System.IO.File]::ReadAllText($briefPath, $utf8)
            if ($briefText -notmatch "(?m)^# $([regex]::Escape($row.request_id)):") {
                Add-ValidationError "REQUEST_BRIEF_ID" $row.brief_path $row.request_id
            }
            $requestFieldPattern = "(?m)^\| request_id \| \x60$([regex]::Escape($row.request_id))\x60 \|$"
            if ($briefText -notmatch $requestFieldPattern) {
                Add-ValidationError "REQUEST_BRIEF_ID" $row.brief_path "request_id field=$($row.request_id)"
            }
            if ($briefText -notmatch [regex]::Escape($row.status)) {
                Add-ValidationError "REQUEST_BRIEF_STATUS" $row.brief_path $row.status
            }
            if ($row.status -eq "ACCEPTED") {
                if ($briefText -notmatch '팀 패키지의 범위 수락은 \d{4}-\d{2}-\d{2} 완료됐다') {
                    Add-ValidationError "REQUEST_ACCEPTED_BRIEF" $row.brief_path "record package acceptance separately from allocation and production completion"
                }
                if ($briefText -match '(?m)^##+ (?:\d+\. )?팀 수락 조건$|^### 팀 수락$') {
                    Add-ValidationError "REQUEST_ACCEPTED_BRIEF" $row.brief_path "unchecked allocation gates must not be labeled as pending team acceptance"
                }
            }
            $registerRevisionMatch = [regex]::Match($row.evidence, '(?:^|[;,\s])request_revision=(?<revision>\d+)(?:$|[;,\s])')
            if (-not $registerRevisionMatch.Success) {
                Add-ValidationError "REQUEST_REVISION" "docs/requests/request_register.csv" $row.request_id
            }
            $briefRevisionMatch = [regex]::Match($briefText, '(?m)^\| (?:의뢰 개정|request revision) \| `(?<revision>\d+)` \|$')
            if (-not $briefRevisionMatch.Success) {
                Add-ValidationError "REQUEST_REVISION" $row.brief_path "brief revision is missing"
            }
            elseif (
                $registerRevisionMatch.Success -and
                $briefRevisionMatch.Groups["revision"].Value -ne $registerRevisionMatch.Groups["revision"].Value
            ) {
                Add-ValidationError "REQUEST_REVISION" $row.brief_path "register=$($registerRevisionMatch.Groups['revision'].Value) brief=$($briefRevisionMatch.Groups['revision'].Value)"
            }
            $briefMilestoneMatch = [regex]::Match($briefText, '(?m)^\| 목표 마일스톤 \| `(?<id>[A-Z][A-Z0-9_]+)` \|$')
            if (-not $briefMilestoneMatch.Success) {
                Add-ValidationError "REQUEST_BRIEF_MILESTONE" $row.brief_path "target milestone is missing"
            }
            elseif ($briefMilestoneMatch.Groups["id"].Value -ne $row.target_milestone) {
                Add-ValidationError "REQUEST_BRIEF_MILESTONE" $row.brief_path "register=$($row.target_milestone) brief=$($briefMilestoneMatch.Groups['id'].Value)"
            }
            if ([string]::IsNullOrWhiteSpace($row.acceptance_gate) -or $row.acceptance_gate -eq "TBD") {
                Add-ValidationError "REQUEST_ACCEPTANCE" "docs/requests/request_register.csv" $row.request_id
            }

            $requiredBriefTerms = switch ($row.team) {
                "ART" { @("asset_id", "location_id", "\uC0C1\uD0DC", "\uC811\uADFC\uC131", "\uB0A9\uD488") }
                "AUD" { @("\uC6A9\uB3C4", "\uAE38\uC774", "\uC545\uAE30\u00B7\uC74C\uC0C9", "\uBC18\uBCF5 \uC5EC\uBD80", "sensory_caption_id") }
                "CNT" { @("trigger", "source_event_id", "speaker_id", "state_reads", "state_writes", "repeat_policy") }
            }
            foreach ($term in $requiredBriefTerms) {
                if ($briefText -notmatch $term) {
                    Add-ValidationError "REQUEST_BRIEF_FIELD" $row.brief_path $term
                }
            }
            foreach ($sourceId in $row.source_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                $trimmedSourceId = $sourceId.Trim()
                if ($briefText -notmatch [regex]::Escape($trimmedSourceId)) {
                    Add-ValidationError "REQUEST_BRIEF_SOURCE" $row.brief_path $trimmedSourceId
                }
            }
            if ($row.team -in @("ART", "AUD")) {
                foreach ($assetId in $row.asset_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
                    $trimmedAssetId = $assetId.Trim()
                    if ($briefText -notmatch [regex]::Escape($trimmedAssetId)) {
                        Add-ValidationError "REQUEST_BRIEF_ASSET" $row.brief_path $trimmedAssetId
                    }
                }
            }
        }
    }

    # ART/AUD requests must form a disjoint, complete partition of their
    # production manifest rows.
    $requestedAssetOwners = @{}
    foreach ($row in $requests | Where-Object { $_.team -in @("ART", "AUD") }) {
        foreach ($assetId in $row.asset_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $trimmedAssetId = $assetId.Trim()
            if ($requestedAssetOwners.ContainsKey($trimmedAssetId)) {
                Add-ValidationError "REQUEST_ASSET_PARTITION" "docs/requests/request_register.csv" "$trimmedAssetId is owned by $($requestedAssetOwners[$trimmedAssetId]) and $($row.request_id)"
            }
            else {
                $requestedAssetOwners[$trimmedAssetId] = $row.request_id
            }
        }
    }
    foreach ($assetRow in $manifest | Where-Object { $_.owner -in @("210", "NOne") }) {
        if (-not $requestedAssetOwners.ContainsKey($assetRow.asset_id)) {
            Add-ValidationError "REQUEST_ASSET_PARTITION" "docs/asset_manifest.csv" "$($assetRow.asset_id) has no ART/AUD request"
        }
    }

    $requestReadmePath = Join-Path $repoRoot "docs/requests/README.md"
    if (Test-Path -LiteralPath $requestReadmePath -PathType Leaf) {
        $requestReadmeText = [System.IO.File]::ReadAllText($requestReadmePath, $utf8)
        if (@($requests | Where-Object { $_.status -eq "ACCEPTED" }).Count -eq $requests.Count) {
            if ($requestReadmeText -match 'VS01 실측 뒤 수락|데모 제작률 뒤 수락') {
                Add-ValidationError "REQUEST_ACCEPTED_DOC_STATUS" "docs/requests/README.md" "all requests are ACCEPTED but a batch is still described as waiting for acceptance"
            }
            if ($requestReadmeText -notmatch 'ACCEPTED.{0,10}는[^\r\n]*즉시 병렬 제작한다는 뜻이 아니다') {
                Add-ValidationError "REQUEST_START_GATE" "docs/requests/README.md" "separate scope acceptance from production start gates"
            }
        }
    }


    $artVsRequest = @($requests | Where-Object { $_.request_id -eq "REQ-ART-2026-0001" })
    if ($artVsRequest.Count -ne 1 -or "ART_OBJ_LIBRARY_OUTER_CLOCK" -notin @($artVsRequest[0].asset_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        Add-ValidationError "CLOCK_ART_REQUEST" "docs/requests/request_register.csv" "REQ-ART-2026-0001 must own ART_OBJ_LIBRARY_OUTER_CLOCK"
    }
    if ($artVsRequest.Count -eq 1) {
        $artVsAssetCount = @($artVsRequest[0].asset_ids.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)).Count
        $artDemoRequest = @($requests | Where-Object { $_.request_id -eq "REQ-ART-2026-0002" })
        if ($artDemoRequest.Count -eq 1) {
            $artDemoBriefPath = Join-Path $repoRoot $artDemoRequest[0].brief_path
            if (Test-Path -LiteralPath $artDemoBriefPath -PathType Leaf) {
                $artDemoBriefText = [System.IO.File]::ReadAllText($artDemoBriefPath, $utf8)
                foreach ($countMatch in [regex]::Matches($artDemoBriefText, '(?:버티컬 슬라이스|VS01에서 이미 요청한) (?<count>\d+)개')) {
                    if ([int]$countMatch.Groups['count'].Value -ne $artVsAssetCount) {
                        Add-ValidationError "REQUEST_ART_VS_COUNT" $artDemoRequest[0].brief_path "expected VS asset count=$artVsAssetCount, found=$($countMatch.Groups['count'].Value)"
                    }
                }
            }
        }
    }

    $cntVsRequest = @($requests | Where-Object { $_.request_id -eq "REQ-CNT-2026-0001" })
    if ($cntVsRequest.Count -eq 1) {
        $cntVsBriefPath = Join-Path $repoRoot $cntVsRequest[0].brief_path
        if (Test-Path -LiteralPath $cntVsBriefPath -PathType Leaf) {
            $cntVsBriefText = [System.IO.File]::ReadAllText($cntVsBriefPath, $utf8)
            if ($cntVsBriefText -notmatch '(?m)^\| `CNT-VS01-PUZA-01`[^\r\n]*`OBJ_LIBRARY_OUTER_CLOCK`') {
                Add-ValidationError "CLOCK_CNT_REQUEST" $cntVsRequest[0].brief_path "CNT-VS01-PUZA-01 must reference OBJ_LIBRARY_OUTER_CLOCK"
            }
            if ($cntVsBriefText -match '(?m)^\| `CNT-VS01-PUZA-01`[^\r\n]*`OBJ_LIBRARY_RECORD_CLOCK`') {
                Add-ValidationError "CLOCK_CNT_REQUEST" $cntVsRequest[0].brief_path "CNT-VS01-PUZA-01 must not reference OBJ_LIBRARY_RECORD_CLOCK"
            }
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

$projectConfigPath = Join-Path $gameRoot "project.godot"
if (-not (Test-Path -LiteralPath $projectConfigPath -PathType Leaf)) {
    Add-ValidationError "GODOT_PROJECT" "game/project.godot" "file is missing"
}
else {
    $projectText = [System.IO.File]::ReadAllText($projectConfigPath, $utf8)
    $projectNameMatch = [regex]::Match($projectText, '(?m)^config/name="(?<name>[^"]+)"$')
    if (-not $projectNameMatch.Success -or $projectNameMatch.Groups['name'].Value -eq "임시") {
        Add-ValidationError "GODOT_APP_NAME" "game/project.godot" "use a non-placeholder internal application name"
    }

    $mainSceneMatch = [regex]::Match($projectText, '(?m)^run/main_scene="(?<path>res://[^"]+)"$')
    if (-not $mainSceneMatch.Success) {
        Add-ValidationError "GODOT_MAIN_SCENE" "game/project.godot" "run/main_scene is missing"
    }
    else {
        $mainSceneUri = $mainSceneMatch.Groups['path'].Value
        if ($mainSceneUri -eq "res://signal_practice.tscn" -or -not $mainSceneUri.StartsWith("res://scenes/main/")) {
            Add-ValidationError "GODOT_MAIN_SCENE" "game/project.godot" "$mainSceneUri is not a production bootstrap path"
        }
        $mainScenePath = Join-Path $gameRoot $mainSceneUri.Substring(6).Replace("/", "\")
        if (-not (Test-Path -LiteralPath $mainScenePath -PathType Leaf)) {
            Add-ValidationError "GODOT_MAIN_SCENE" "game/project.godot" "$mainSceneUri does not exist"
        }
    }
}

$godotSourceFiles = Get-ChildItem -LiteralPath $gameRoot -Recurse -File |
    Where-Object { $_.Extension -in @(".gd", ".godot", ".tscn", ".tres") }
foreach ($file in $godotSourceFiles) {
    $relativePath = Get-RepoRelativePath $file.FullName
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    foreach ($match in [regex]::Matches($text, 'res://(?<path>[^"''\r\n]+)')) {
        $resourcePath = $match.Groups['path'].Value
        $candidate = Join-Path $gameRoot $resourcePath.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $candidate)) {
            Add-ValidationError "GODOT_RESOURCE_REF" $relativePath "res://$resourcePath"
        }
    }
}

$practiceScenePath = Join-Path $gameRoot "signal_practice.tscn"
if (Test-Path -LiteralPath $practiceScenePath -PathType Leaf) {
    $practiceSceneText = [System.IO.File]::ReadAllText($practiceScenePath, $utf8)
    if ($practiceSceneText -match 'signal="button_down"|method="_on_button_down"') {
        Add-ValidationError "PRACTICE_INPUT" "game/signal_practice.tscn" "use confirmed pressed signals"
    }
}

$practiceKeyPath = Join-Path $gameRoot "key.gd"
if (Test-Path -LiteralPath $practiceKeyPath -PathType Leaf) {
    $practiceKeyText = [System.IO.File]::ReadAllText($practiceKeyPath, $utf8)
    if (
        $practiceKeyText -match '(?<![A-Za-z0-9_])key_clicked(?![A-Za-z0-9_])' -or
        $practiceKeyText -notmatch 'disabled\s*=\s*true' -or
        $practiceKeyText -notmatch '\.add_item\('
    ) {
        Add-ValidationError "PRACTICE_KEY_ACQUIRE" "game/key.gd" "acquisition must write inventory, hide, and disable the key"
    }
}

foreach ($file in Get-ChildItem -LiteralPath $gameRoot -Recurse -File) {
    if ($file.Name -like "*tmp*") {
        Add-ValidationError "TEMP_FILE" (Get-RepoRelativePath $file.FullName) "temporary file remains in game tree"
    }
}

$workflowRoot = Join-Path $repoRoot ".github/workflows"
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    foreach ($workflow in Get-ChildItem -LiteralPath $workflowRoot -File -Include "*.yml", "*.yaml") {
        $workflowText = [System.IO.File]::ReadAllText($workflow.FullName, $utf8)
        foreach ($usesMatch in [regex]::Matches($workflowText, '(?m)^\s*uses:\s*(?<reference>[^#\r\n]+)')) {
            $reference = $usesMatch.Groups['reference'].Value.Trim()
            if ($reference -notmatch '^\./' -and $reference -notmatch '@[0-9a-f]{40}$') {
                Add-ValidationError "ACTION_REF_NOT_PINNED" (Get-RepoRelativePath $workflow.FullName) $reference
            }
        }
    }
}

Write-Host "Markdown files: $($markdownFiles.Count)"
Write-Host "Decision IDs: $($decisionIds.Count)"
Write-Host "Issue IDs: $issueCount (CNF $cnfCount, ERR $errCount)"
Write-Host "Milestone IDs: $($milestoneIds.Count)"
Write-Host "Object IDs: $($objectIds.Count)"
if (Test-Path -LiteralPath $manifestPath) {
    Write-Host "Asset rows: $((Import-Csv -LiteralPath $manifestPath -Encoding utf8).Count)"
}
if (Test-Path -LiteralPath $requestRegisterPath) {
    Write-Host "Request IDs: $($requestIds.Count)"
}

if ($errors.Count -gt 0) {
    Write-Host "Validation errors: $($errors.Count)"
    $errors | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "PASS"
