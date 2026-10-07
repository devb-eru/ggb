param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [string[]]$Suites = @('chapter-one', 'chapter-one-notes', 'modals', 'stay', 'chapter-surfaces', 'prologue-surfaces'),
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 1200
)
$ErrorActionPreference = 'Stop'
$allowed = @('chapter-one', 'chapter-one-notes', 'modals', 'stay', 'chapter-surfaces', 'prologue-surfaces', 'mara1', 'iris', 'luca', 'authority-archive', 'settlement', 'journal-four-display')
if ($Suites.Count -eq 0 -or @($Suites | Where-Object { $_ -cnotin $allowed }).Count -gt 0 -or
    @($Suites | Select-Object -Unique).Count -ne $Suites.Count) { throw 'Select distinct supported suites' }
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Godot project required' }
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not ($project + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use an isolated project copy under TEMP, not the user project'
}
$evidence = [IO.Path]::GetFullPath($EvidencePath)
if (-not ($evidence + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $evidence)) { throw 'Evidence must be a new directory under TEMP' }
New-Item -ItemType Directory -Path $evidence | Out-Null
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    foreach ($suite in $Suites) {
        $env:APPDATA = Join-Path $evidence ($suite + '-appdata')
        $env:LOCALAPPDATA = Join-Path $evidence ($suite + '-localappdata')
        New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
        $stdout = Join-Path $evidence ($suite + '.out.log')
        $stderr = Join-Path $evidence ($suite + '.err.log')
        $started = [DateTime]::UtcNow.ToString('o')
        $child = Start-Process -FilePath $engine -ArgumentList @('--headless', '--path', ('"' + $project + '"'),
            '--', ('--notebook-' + $suite + '-smoke'), '--ggb-dev-notebook-v2', '--notebook-producer-trace') `
            -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        Write-Output ($suite + ': PID=' + $child.Id + ' evidence=' + $evidence)
        $finished = $child.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            $child.Kill()
            $child.WaitForExit()
        }
        $receipt = @{schema_version=1; completed=$finished; exit_code=$child.ExitCode;
            started_utc=$started; finished_utc=[DateTime]::UtcNow.ToString('o');
            stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();
            stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
        [IO.File]::WriteAllText((Join-Path $evidence ($suite + '.run.json')),
            ($receipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        Get-Content -LiteralPath $stdout | Where-Object { $_ -match '^NOTEBOOK_[A-Z0-9_]+_SMOKE:|^.*COVERAGE:|^.*PHASE:|^STAY_ASSERTIONS:' }
        if (-not $finished) { throw ('Suite timeout: ' + $suite) }
        if ($child.ExitCode -ne 0) { throw ('Suite failed: ' + $suite) }
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
