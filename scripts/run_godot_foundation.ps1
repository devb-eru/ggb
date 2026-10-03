param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectSourceRoot = Join-Path $repoRoot "game"
$runtimeRoot = Join-Path $env:TEMP "ggb-godot-validation"
$runtimeGodot = Join-Path $runtimeRoot "godot-validation.exe"
$appDataRoot = Join-Path $runtimeRoot "appdata"
$projectRoot = Join-Path $runtimeRoot "project"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$lfsPointers = @()
$lfsTrackedPaths = & git -C $repoRoot lfs ls-files --name-only
foreach ($trackedPath in $lfsTrackedPaths) {
    $absolutePath = Join-Path $repoRoot $trackedPath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        continue
    }
    $firstLine = Get-Content -LiteralPath $absolutePath -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine -eq "version https://git-lfs.github.com/spec/v1") {
        $lfsPointers += $trackedPath
    }
}
if ($lfsPointers.Count -gt 0) {
    throw "Git LFS assets are pointer files. Run 'git lfs pull' before Godot validation: $($lfsPointers -join ', ')"
}

New-Item -ItemType Directory -Force -Path $runtimeRoot, $appDataRoot | Out-Null
$resolvedRuntimeRoot = [System.IO.Path]::GetFullPath($runtimeRoot)
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
if (-not $resolvedProjectRoot.StartsWith($resolvedRuntimeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe validation project path: $resolvedProjectRoot"
}
if (Test-Path -LiteralPath $projectRoot) {
    Remove-Item -LiteralPath $projectRoot -Recurse -Force
}
Copy-Item -LiteralPath $projectSourceRoot -Destination $projectRoot -Recurse -Force
Copy-Item -LiteralPath $GodotPath -Destination $runtimeGodot -Force

function Invoke-GodotValidation {
    param([string[]]$Arguments)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $runtimeGodot
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.Environment["APPDATA"] = $appDataRoot
    $startInfo.Environment["LOCALAPPDATA"] = $appDataRoot
    # Windows PowerShell 5.1 uses the .NET Framework ProcessStartInfo API,
    # which does not expose ArgumentList. These validation arguments contain
    # no trailing backslashes, so standard quoted command-line escaping is
    # sufficient and keeps the script compatible with PowerShell 7 as well.
    $quotedArguments = foreach ($argument in $Arguments) {
        '"{0}"' -f ($argument -replace '"', '\"')
    }
    $startInfo.Arguments = $quotedArguments -join ' '

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    Write-Host $standardOutput.Result
    if (-not [string]::IsNullOrWhiteSpace($standardError.Result)) {
        Write-Host $standardError.Result
    }
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StandardOutput = $standardOutput.Result
        StandardError = $standardError.Result
        CombinedOutput = "$($standardOutput.Result)`n$($standardError.Result)"
    }
}

function Assert-GodotValidation {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$RequiredMarker = ""
    )

    if ($Result.ExitCode -ne 0) {
        throw "$Name failed with exit code $($Result.ExitCode)"
    }
    foreach ($fatalPattern in @("SCRIPT ERROR:", "ERROR: Failed loading resource:", "ERROR: Error importing")) {
        if ($Result.CombinedOutput.Contains($fatalPattern)) {
            throw "$Name emitted a fatal Godot log: $fatalPattern"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($RequiredMarker) -and -not $Result.CombinedOutput.Contains($RequiredMarker)) {
        throw "$Name did not emit its required success marker: $RequiredMarker"
    }
}

$importResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--editor", "--quit")
Assert-GodotValidation -Result $importResult -Name "Godot import and parse"

$smokeResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--foundation-smoke")
Assert-GodotValidation -Result $smokeResult -Name "Foundation smoke" -RequiredMarker "FOUNDATION_SMOKE: PASS"

$startScreenSmokeResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--start-screen-smoke")
Assert-GodotValidation -Result $startScreenSmokeResult -Name "Start screen smoke" -RequiredMarker "START_SCREEN_SMOKE: PASS"

$practiceSmokeResult = Invoke-GodotValidation @(
    "--headless", "--path", $projectRoot,
    "--script", "res://scripts/tests/practice_scene_smoke.gd",
    "--quit-after", "300"
)
Assert-GodotValidation -Result $practiceSmokeResult -Name "Practice scene smoke" -RequiredMarker "PRACTICE_SCENE_SMOKE: PASS"

$prologueSmokeResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--prologue-smoke")
Assert-GodotValidation -Result $prologueSmokeResult -Name "Prologue scene smoke" -RequiredMarker "PROLOGUE_SCENE_SMOKE: PASS"

Write-Host "Godot foundation, start screen, practice, and prologue validation passed."

$chapterOneSmokeResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--chapter-one-smoke")
Assert-GodotValidation -Result $chapterOneSmokeResult -Name "Chapter one smoke" -RequiredMarker "CHAPTER_ONE_SMOKE: PASS"
Write-Host "Chapter one reset, failure, shortcut, journal, and load validation passed."

$historyResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--dialogue-history-smoke")
Assert-GodotValidation -Result $historyResult -Name "Dialogue history" -RequiredMarker "DIALOGUE_HISTORY_SMOKE: PASS"

$archiveResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/notebook_archive_smoke.gd", "--quit-after", "1800")
Assert-GodotValidation -Result $archiveResult -Name "Notebook archive candidates" -RequiredMarker "NOTEBOOK_ARCHIVE_SMOKE: PASS"

$migrationResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-migration-smoke")
Assert-GodotValidation -Result $migrationResult -Name "Notebook save migration and metadata commands" -RequiredMarker "NOTEBOOK_MIGRATION_SMOKE: PASS"

$notebookContentResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-content-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookContentResult -Name "Notebook authored hint content" -RequiredMarker "NOTEBOOK_CONTENT_SMOKE: PASS"

$notebookPrologueResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-prologue-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookPrologueResult -Name "Notebook authored prologue dialogue and choices" -RequiredMarker "NOTEBOOK_PROLOGUE_SMOKE: PASS"

$notebookKnowledgeResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-knowledge-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookKnowledgeResult -Name "Notebook knowledge revisions and atomic event notes" -RequiredMarker "NOTEBOOK_KNOWLEDGE_SMOKE: PASS"

$notebookChapterOneResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-chapter-one-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookChapterOneResult -Name "Notebook authored chapter-one dialogue and observations" -RequiredMarker "NOTEBOOK_CHAPTER_ONE_SMOKE: PASS"

$notebookChapterOneNotesResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-chapter-one-notes-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookChapterOneNotesResult -Name "Notebook chapter-one knowledge acquisition and source revisions" -RequiredMarker "NOTEBOOK_CHAPTER_ONE_NOTES_SMOKE: PASS"

$notebookModalsResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-modals-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookModalsResult -Name "Notebook modal disclosure and explicit selection semantics" -RequiredMarker "NOTEBOOK_MODALS_SMOKE: PASS"

$notebookMirrorResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-mirror-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookMirrorResult -Name "Notebook mirror observations and event-written knowledge" -RequiredMarker "NOTEBOOK_MIRROR_SMOKE: PASS"

$notebookBasementResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-basement-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookBasementResult -Name "Notebook basement observations, irreversible choices and event notes" -RequiredMarker "NOTEBOOK_BASEMENT_SMOKE: PASS"

$notebookFractureResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-fracture-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookFractureResult -Name "Notebook fracture dialogue, rest confirmation and event notes" -RequiredMarker "NOTEBOOK_FRACTURE_SMOKE: PASS"

$notebookFractureSurfacesResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-fracture-surfaces-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookFractureSurfacesResult -Name "Notebook timed fracture surfaces and world choices" -RequiredMarker "NOTEBOOK_FRACTURE_SURFACES_SMOKE: PASS"

$notebookMara1Result = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-mara1-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookMara1Result -Name "Notebook Mara 1 evidence and research record" -RequiredMarker "NOTEBOOK_MARA1_SMOKE: PASS"

$notebookIrisResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-iris-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookIrisResult -Name "Notebook Iris evidence and conditional disclosure" -RequiredMarker "NOTEBOOK_IRIS_SMOKE: PASS"

$notebookLucaResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-luca-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookLucaResult -Name "Notebook Luca evidence and frozen localized cycle" -RequiredMarker "NOTEBOOK_LUCA_SMOKE: PASS"

$notebookSettlementResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-settlement-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookSettlementResult -Name "Notebook last evening and core approach evidence" -RequiredMarker "NOTEBOOK_SETTLEMENT_SMOKE: PASS"

$notebookJournalFourResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-journal-four-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookJournalFourResult -Name "Notebook composed J4 document and original quotations" -RequiredMarker "NOTEBOOK_JOURNAL_FOUR_SMOKE: PASS"

$notebookJournalFourDisplayResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-journal-four-display-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookJournalFourDisplayResult -Name "Notebook J4 confirmation, actual reading and minimum access" -RequiredMarker "NOTEBOOK_JOURNAL_FOUR_DISPLAY_SMOKE: PASS"

$notebookCoreResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-core-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookCoreResult -Name "Notebook core puzzle evidence and nonbinding authority" -RequiredMarker "NOTEBOOK_CORE_SMOKE: PASS"

$notebookFinalResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-final-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookFinalResult -Name "Notebook final records, relation disclosures and neutral ending review" -RequiredMarker "NOTEBOOK_FINAL_SMOKE: PASS"
$notebookRealityResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-reality-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookRealityResult -Name "Notebook reality handoff, physical pages and final views" -RequiredMarker "NOTEBOOK_REALITY_SMOKE: PASS"
$notebookStayResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-stay-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookStayResult -Name "Notebook stay policies, table scenes and written sentences" -RequiredMarker "NOTEBOOK_STAY_SMOKE: PASS"

$notebookPuzzleSurfacesResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-puzzle-surfaces-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookPuzzleSurfacesResult -Name "Notebook puzzle boards and immutable mirror diagram" -RequiredMarker "NOTEBOOK_PUZZLE_SURFACES_SMOKE: PASS"

$notebookChapterSurfacesResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-chapter-surfaces-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookChapterSurfacesResult -Name "Notebook chapter labels, journal fragments and clock boards" -RequiredMarker "NOTEBOOK_CHAPTER_SURFACES_SMOKE: PASS"

$notebookAuthorityArchiveResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--notebook-authority-archive-smoke", "--ggb-dev-notebook-v2")
Assert-GodotValidation -Result $notebookAuthorityArchiveResult -Name "Notebook Edgar authority and Mara 2 archive evidence" -RequiredMarker "NOTEBOOK_AUTHORITY_ARCHIVE_SMOKE: PASS"

$blackMirrorResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--black-mirror-smoke")
Assert-GodotValidation -Result $blackMirrorResult -Name "Black mirror chapter smoke" -RequiredMarker "BLACK_MIRROR_SMOKE: PASS"
Write-Host "Black mirror mixture, irreversible trace, reset, capture, and J3 validation passed."

$basementPuzzleResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/basement_puzzle_smoke.gd")
Assert-GodotValidation -Result $basementPuzzleResult -Name "Basement puzzle rules" -RequiredMarker "BASEMENT_PUZZLE_SMOKE: PASS"
Write-Host "Basement overlay, pressure axes, and linked heart rule validation passed."

$basementSessionResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--basement-session-smoke")
Assert-GodotValidation -Result $basementSessionResult -Name "Basement session" -RequiredMarker "BASEMENT_SESSION_SMOKE: PASS"
Write-Host "Basement navigation, failure persistence, sleep shortcuts, heart, and D5 save validation passed."
