Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_windows_template_policy.ps1')

$root = Join-Path ([IO.Path]::GetTempPath()) ('ggb-template-policy-' + [Guid]::NewGuid().ToString('N'))
$checks = 0
function New-TemplateFixture {
    param([string]$Version, [string]$Marker = $Version, [bool]$WithDebug = $true, [bool]$WithRelease = $false)
    $directory = Join-Path $root $Version
    New-Item -ItemType Directory -Path $directory | Out-Null
    [IO.File]::WriteAllText((Join-Path $directory 'version.txt'), $Marker)
    if ($WithDebug) { [IO.File]::WriteAllBytes((Join-Path $directory 'windows_debug_x86_64.exe'), [byte[]]@()) }
    if ($WithRelease) { [IO.File]::WriteAllBytes((Join-Path $directory 'windows_release_x86_64.exe'), [byte[]]@()) }
    return $directory
}
function Assert-Rejected {
    param([string]$Version, [string]$Reason, [string]$Configuration = 'debug')
    try { $null = Get-GodotWindowsTemplateDirectory -TemplateRoot $root -RuntimeVersion $Version -Configuration $Configuration }
    catch {
        if ($_.Exception.Message -notlike ('*' + $Reason + '*')) { throw }
        $script:checks++
        return
    }
    throw "Expected template rejection: $Version / $Reason"
}

try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $null = New-TemplateFixture '4.5.2.stable'
    $expected = New-TemplateFixture '4.6.3.stable'
    $null = New-TemplateFixture '4.7.2.stable'
    $baseline = Get-ChildItem -LiteralPath $root -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'windows_debug_x86_64.exe') -PathType Leaf
    } | Select-Object -First 1
    if ($baseline.FullName -eq $expected) { throw 'Baseline mismatch was not reproduced' }
    Write-Output ('BASELINE_TEMPLATE_MISMATCH: REPRODUCED (' + $baseline.Name + ')')
    foreach ($version in @('4.6.3.stable.official.7d41c59c4', '4.6.3.stable.steam.7d41c59c4')) {
        $actual = Get-GodotWindowsTemplateDirectory -TemplateRoot $root -RuntimeVersion $version
        if ($actual -ne $expected) { throw 'Wrong template selected from multiple versions' }
        $checks++
    }
    $zeroPatch = New-TemplateFixture '4.6.stable'
    if ((Get-GodotWindowsTemplateDirectory $root '4.6.stable.official.hash') -ne $zeroPatch) { throw 'Zero patch version mismatch' }
    $checks++
    $null = New-TemplateFixture '4.6.4.stable' '4.7.2.stable'
    $null = New-TemplateFixture '4.6.5.stable' '4.6.5.stable' $false
    Assert-Rejected '4.6.2.stable.official.hash' 'directory is missing'
    Assert-Rejected '4.6.4.stable.official.hash' 'marker does not match'
    Assert-Rejected '4.6.5.stable.official.hash' 'debug x64 export template is missing'
    Assert-Rejected 'garbage' 'Unsupported'
    Assert-Rejected '../4.6.3.stable' 'Unsupported'
    Assert-Rejected '4.6.3.stable.mono.official.hash' 'Unsupported'
    $missingMarker = Join-Path $root '4.6.6.stable'
    New-Item -ItemType Directory -Path $missingMarker | Out-Null
    Assert-Rejected '4.6.6.stable.official.hash' 'version marker is missing'
    Assert-Rejected '4.6.3.stable.official.hash' 'release x64 export template is missing' 'release'
    [IO.File]::WriteAllBytes((Join-Path $expected 'windows_release_x86_64.exe'), [byte[]]@())
    foreach ($version in @('4.6.3.stable.official.7d41c59c4', '4.6.3.stable.steam.7d41c59c4')) {
        if ((Get-GodotWindowsTemplateDirectory $root $version -Configuration release) -ne $expected) {throw 'Wrong release template directory'}
        $checks++
    }
    $releaseOnly = New-TemplateFixture '4.6.7.stable' '4.6.7.stable' $false $true
    if ((Get-GodotWindowsTemplateDirectory $root '4.6.7.stable.official.hash' -Configuration release) -ne $releaseOnly) {throw 'Release-only exact version was rejected'}
    $checks++
    Assert-Rejected '4.6.7.stable.official.hash' 'debug x64 export template is missing'
    Assert-Rejected '4.6.2.stable.official.hash' 'directory is missing' 'release'
    Assert-Rejected '4.6.4.stable.official.hash' 'marker does not match' 'release'
    Assert-Rejected '4.6.6.stable.official.hash' 'version marker is missing' 'release'
    Assert-Rejected '4.6.3.stable.mono.official.hash' 'Unsupported' 'release'
    Write-Output "GODOT_TEMPLATE_POLICY_CHECKS: $checks"
    Write-Output 'GODOT_TEMPLATE_POLICY: PASS'
} finally {
    $fullRoot = [IO.Path]::GetFullPath($root)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
    if (-not $fullRoot.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($fullRoot) -notmatch '^ggb-template-policy-[0-9a-f]{32}$') { throw 'Unsafe fixture cleanup path' }
    if (Test-Path -LiteralPath $fullRoot) { Remove-Item -LiteralPath $fullRoot -Recurse -Force }
}
