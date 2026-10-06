param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [string]$RuntimeRoot = (Join-Path $env:TEMP ('ggb-renderer-validation-' + [Guid]::NewGuid().ToString('N')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Join-Path $repoRoot "game"
$outputRoot = Join-Path $repoRoot "builds/renderer_candidates"
$compatibilityExe = Join-Path $outputRoot "compatibility/GGB_Compatibility.exe"
$forwardPlusExe = Join-Path $outputRoot "forward_plus/GGB_ForwardPlus.exe"
$runtimeGodot = Join-Path $runtimeRoot "godot-renderer-validation.exe"
$appDataRoot = Join-Path $runtimeRoot "appdata"
$sourceTemplateRoot = Join-Path (Split-Path -Parent $GodotPath) "editor_data/export_templates"
$targetTemplateRoot = Join-Path $appDataRoot "Godot/export_templates"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

. (Join-Path $PSScriptRoot "godot_windows_template_policy.ps1")
$runtimeVersion = (& $GodotPath --headless --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not read Godot runtime version from: $GodotPath"
}
$templateVersionDirectory = Get-GodotWindowsTemplateDirectory `
    -TemplateRoot $sourceTemplateRoot -RuntimeVersion $runtimeVersion
if (Test-Path -LiteralPath $runtimeRoot) {
    throw "Validation runtime directory already exists: $runtimeRoot"
}

New-Item -ItemType Directory -Force -Path `
    (Split-Path -Parent $compatibilityExe), `
    (Split-Path -Parent $forwardPlusExe), `
    $runtimeRoot, `
    $appDataRoot | Out-Null
Copy-Item -LiteralPath $GodotPath -Destination $runtimeGodot -Force

New-Item -ItemType Directory -Force -Path $targetTemplateRoot | Out-Null
Copy-Item -LiteralPath $templateVersionDirectory -Destination $targetTemplateRoot -Recurse -Force
Write-Host "Godot: $runtimeVersion; templates: $templateVersionDirectory; isolated runtime: $runtimeRoot"

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
    if (-not $process.WaitForExit(600000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Validation process timed out: $FilePath"
    }
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
