param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repoRoot "game"
$runtimeRoot = Join-Path $env:TEMP "ggb-godot-validation"
$runtimeGodot = Join-Path $runtimeRoot "godot-validation.exe"
$appDataRoot = Join-Path $runtimeRoot "appdata"

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
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

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

Write-Host "Godot foundation, start screen, and practice validation passed."
