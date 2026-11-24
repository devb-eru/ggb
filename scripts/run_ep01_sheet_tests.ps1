param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [ValidateSet('ep01','prologue','notebook_prologue','cursor_seed','cursor_resume','cursor_completed')][string]$Suite = 'ep01'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceProject = Join-Path $repoRoot 'game'
$testRoot = Join-Path $repoRoot 'outputs/ep01-godot-sync'
$cacheRequired = @('global_script_class_cache.cfg','uid_cache.bin','imported')
foreach ($entry in $cacheRequired) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceProject ".godot/$entry"))) {
        throw "Import the game project in Godot before running the EP01 sheet tests (missing .godot/$entry)."
    }
}
$fixture = Join-Path $testRoot 'project'
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
foreach ($directory in @('assets','data','examples','scenes','scripts')) {
    $link = Join-Path $fixture $directory
    $target = Join-Path $sourceProject $directory
    if ((Test-Path -LiteralPath $link) -and (Get-Item -LiteralPath $link).LinkType) { throw "Unexpected fixture link: $link" }
    New-Item -ItemType Directory -Force -Path $link | Out-Null
    & robocopy $target $link /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Fixture copy failed: $directory" }
}
foreach ($name in @('icon.svg','icon.svg.import')) {
    Copy-Item -LiteralPath (Join-Path $sourceProject $name) -Destination $fixture -Force
}
# Use the actual sources and imported assets with an isolated project/user store.
# The user's editor MCP autoload and plugins must not start a competing service.
$configuration = [IO.File]::ReadAllText((Join-Path $sourceProject 'project.godot'))
$configuration = $configuration -replace '(?m)^MCPRuntime=.*\r?\n',''
$configuration = $configuration -replace '(?m)^enabled=PackedStringArray\([^\r\n]*\)','enabled=PackedStringArray()'
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $configuration, [Text.UTF8Encoding]::new($false))
$cache = Join-Path $fixture '.godot'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
foreach ($name in @('global_script_class_cache.cfg','uid_cache.bin')) {
    Copy-Item -LiteralPath (Join-Path $sourceProject ".godot/$name") -Destination (Join-Path $cache $name) -Force
}
$imported = Join-Path $cache 'imported'
New-Item -ItemType Directory -Force -Path $imported | Out-Null
& robocopy (Join-Path $sourceProject '.godot/imported') $imported /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Imported asset copy failed' }
$engine = Join-Path $testRoot 'godot-validation.exe'
if (-not (Test-Path -LiteralPath $engine)) { Copy-Item -LiteralPath $GodotPath -Destination $engine }
$profileName = if ($Suite.StartsWith('cursor_')) { 'cursor' } else { $Suite }
$dataRoot = Join-Path $testRoot ('userdata/' + $profileName)
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$env:APPDATA = $dataRoot
$env:LOCALAPPDATA = $dataRoot
$logName = if ($Suite -eq 'ep01') { 'verified-smoke' } else { $Suite }
$stdout = Join-Path $testRoot ($logName + '.out.log')
$stderr = Join-Path $testRoot ($logName + '.err.log')
$arguments = @('--headless','--path',('"' + $fixture + '"'),'--quit-after','3600')
$marker = 'EP01_SHEET_SMOKE PASS'
if ($Suite -eq 'ep01') {
    $arguments += 'res://scripts/tests/ep01_sheet_smoke.tscn'
} elseif ($Suite -eq 'prologue') {
    $arguments += @('--','--prologue-smoke')
    $marker = 'PROLOGUE_SCENE_SMOKE: PASS'
} elseif ($Suite -eq 'notebook_prologue') {
    $arguments += @('--','--notebook-prologue-smoke','--ggb-dev-notebook-v2')
    $marker = 'NOTEBOOK_PROLOGUE_SMOKE: PASS'
} else {
    $phase = $Suite.Substring('cursor_'.Length)
    $arguments += @('--','--notebook-prologue-presentation-smoke',('--cursor-phase=' + $phase),'--ggb-dev-notebook-v2')
    $marker = 'NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'
}
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$outText = [IO.File]::ReadAllText($stdout)
$errText = [IO.File]::ReadAllText($stderr)
Write-Output $outText
if ($errText) { Write-Output $errText }
if ($process.ExitCode -ne 0 -or -not $outText.Contains($marker) -or $errText -match '(SCRIPT ERROR|ERROR:)') {
    throw "EP01 sheet integration verification failed (exit $($process.ExitCode))."
}
