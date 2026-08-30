param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repoRoot "game"
$outputRoot = Join-Path $repoRoot "builds/renderer_candidates"
$compatibilityExe = Join-Path $outputRoot "compatibility/GGB_Compatibility.exe"
$forwardPlusExe = Join-Path $outputRoot "forward_plus/GGB_ForwardPlus.exe"
$runtimeRoot = Join-Path $env:TEMP "ggb-renderer-validation"
$runtimeGodot = Join-Path $runtimeRoot "godot-renderer-validation.exe"
$appDataRoot = Join-Path $runtimeRoot "appdata"
$sourceTemplateRoot = Join-Path (Split-Path -Parent $GodotPath) "editor_data/export_templates"
$targetTemplateRoot = Join-Path $appDataRoot "Godot/export_templates"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

New-Item -ItemType Directory -Force -Path `
    (Split-Path -Parent $compatibilityExe), `
    (Split-Path -Parent $forwardPlusExe), `
    $runtimeRoot, `
    $appDataRoot | Out-Null
Copy-Item -LiteralPath $GodotPath -Destination $runtimeGodot -Force

$templateVersionDirectory = Get-ChildItem -LiteralPath $sourceTemplateRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName "windows_debug_x86_64.exe") -PathType Leaf
    } |
    Select-Object -First 1
if ($null -eq $templateVersionDirectory) {
    throw "Matching Windows export templates were not found under: $sourceTemplateRoot"
}
New-Item -ItemType Directory -Force -Path $targetTemplateRoot | Out-Null
Copy-Item -LiteralPath $templateVersionDirectory.FullName -Destination $targetTemplateRoot -Recurse -Force

function Invoke-ValidationProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
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

$compatibilityExportExit = Invoke-ValidationProcess $runtimeGodot @(
    "--headless", "--path", $projectRoot,
    "--export-debug", "Windows Desktop Debug", $compatibilityExe
)
if ($compatibilityExportExit -ne 0) {
    throw "Compatibility candidate export failed with exit code $compatibilityExportExit"
}

$forwardPlusExportExit = Invoke-ValidationProcess $runtimeGodot @(
    "--headless", "--path", $projectRoot,
    "--export-debug", "Windows Desktop Debug", $forwardPlusExe
)
if ($forwardPlusExportExit -ne 0) {
    throw "Forward+ candidate export failed with exit code $forwardPlusExportExit"
}

$compatibilitySmokeExit = Invoke-ValidationProcess $compatibilityExe @(
    "--headless", "--rendering-method", "gl_compatibility", "--", "--foundation-smoke"
)
if ($compatibilitySmokeExit -ne 0) {
    throw "Compatibility candidate smoke failed with exit code $compatibilitySmokeExit"
}

$forwardPlusSmokeExit = Invoke-ValidationProcess $forwardPlusExe @(
    "--headless", "--rendering-method", "forward_plus", "--", "--foundation-smoke"
)
if ($forwardPlusSmokeExit -ne 0) {
    throw "Forward+ candidate smoke failed with exit code $forwardPlusSmokeExit"
}

Write-Host "Both renderer candidates exported and passed the foundation smoke."
