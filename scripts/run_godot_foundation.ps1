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
    return $process.ExitCode
}

$importExit = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--editor", "--quit")
if ($importExit -ne 0) {
    throw "Godot import or parse failed with exit code $importExit"
}

$smokeExit = Invoke-GodotValidation @("--headless", "--path", $projectRoot, "--", "--foundation-smoke")
if ($smokeExit -ne 0) {
    throw "Foundation smoke failed with exit code $smokeExit"
}

$practiceSmokeExit = Invoke-GodotValidation @(
    "--headless", "--path", $projectRoot,
    "--script", "res://scripts/tests/practice_scene_smoke.gd"
)
if ($practiceSmokeExit -ne 0) {
    throw "Practice scene smoke failed with exit code $practiceSmokeExit"
}

Write-Host "Godot foundation and practice validation passed."
