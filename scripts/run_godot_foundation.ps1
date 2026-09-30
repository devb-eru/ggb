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

$blackMirrorResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--black-mirror-smoke")
Assert-GodotValidation -Result $blackMirrorResult -Name "Black mirror chapter smoke" -RequiredMarker "BLACK_MIRROR_SMOKE: PASS"
Write-Host "Black mirror mixture, irreversible trace, reset, capture, and J3 validation passed."

$basementPuzzleResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--script", "res://scripts/tests/basement_puzzle_smoke.gd")
Assert-GodotValidation -Result $basementPuzzleResult -Name "Basement puzzle rules" -RequiredMarker "BASEMENT_PUZZLE_SMOKE: PASS"
Write-Host "Basement overlay, pressure axes, and linked heart rule validation passed."

$basementSessionResult = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--basement-session-smoke")
Assert-GodotValidation -Result $basementSessionResult -Name "Basement session" -RequiredMarker "BASEMENT_SESSION_SMOKE: PASS"
Write-Host "Basement navigation, failure persistence, sleep shortcuts, heart, and D5 save validation passed."
