function Get-GodotWindowsTemplateDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateRoot,
        [Parameter(Mandatory = $true)][string]$RuntimeVersion
    )

    $version = $RuntimeVersion.Trim()
    $match = [regex]::Match($version, '^(\d+\.\d+(?:\.\d+)?)\.(stable|beta\d+|rc\d+|dev\d+)(?:\.[A-Za-z0-9_-]+)*$')
    if (-not $match.Success -or $version -match '\.mono(?:\.|$)') {
        throw "Unsupported standard Godot version: $version"
    }
    $templateVersion = '{0}.{1}' -f $match.Groups[1].Value, $match.Groups[2].Value
    $directory = Join-Path $TemplateRoot $templateVersion
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw "Exact Godot export template directory is missing: $directory"
    }
    $marker = Join-Path $directory 'version.txt'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        throw "Godot export template version marker is missing: $marker"
    }
    if ((Get-Content -LiteralPath $marker -Raw).Trim() -cne $templateVersion) {
        throw "Godot export template version marker does not match $templateVersion"
    }
    $debugTemplate = Join-Path $directory 'windows_debug_x86_64.exe'
    if (-not (Test-Path -LiteralPath $debugTemplate -PathType Leaf)) {
        throw "Windows debug x64 export template is missing: $debugTemplate"
    }
    return $directory
}
