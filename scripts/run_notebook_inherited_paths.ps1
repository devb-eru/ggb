param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 1800
)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$harness = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'tests/notebook_inherited_path_audit.gd')).Path
$scene = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'tests/notebook_inherited_paths.tscn')).Path
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$evidence = [IO.Path]::GetFullPath($EvidencePath)
if (-not ($project + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Use an isolated Godot project under TEMP' }
if (-not ($evidence + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $evidence)) { throw 'Evidence must be a new directory under TEMP' }
New-Item -ItemType Directory -Path $evidence | Out-Null
$testDirectory = Join-Path $project ('__notebook_inherited_audit_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$frozenHarness = Join-Path $testDirectory 'notebook_inherited_path_audit.gd'
$frozenScene = Join-Path $testDirectory 'notebook_inherited_paths.tscn'
Copy-Item -LiteralPath $harness -Destination $frozenHarness
Copy-Item -LiteralPath $scene -Destination $frozenScene
$stdout = Join-Path $evidence 'inherited-paths.out.log'
$stderr = Join-Path $evidence 'inherited-paths.err.log'
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $started = [DateTime]::UtcNow.ToString('o')
    $arguments = @('--headless', '--path', ('"' + $project + '"'), ('"' + $frozenScene + '"'),
        '--', '--ggb-dev-notebook-v2', '--notebook-require-authored')
    $child = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ('INHERITED_PATH_RUNNING: PID=' + $child.Id + ' evidence=' + $evidence)
    $finished = $child.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) { $child.Kill(); $child.WaitForExit() }
    $receipt = [ordered]@{
        schema_version=1;completed=$finished;exit_code=$child.ExitCode;require_authored=$true
        started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o')
        engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant()
        harness_sha256=(Get-FileHash -LiteralPath $frozenHarness).Hash.ToLowerInvariant()
        scene_sha256=(Get-FileHash -LiteralPath $frozenScene).Hash.ToLowerInvariant()
        runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant()
        stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()
    }
    [IO.File]::WriteAllText((Join-Path $evidence 'inherited-paths.run.json'), ($receipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    if (-not $finished -or $child.ExitCode -ne 0) { throw 'Inherited-path audit did not finish successfully' }
    $lines = @(Get-Content -LiteralPath $stdout)
    if (@($lines | Where-Object { $_ -ceq 'NOTEBOOK_INHERITED_PATH_SMOKE:PASS' }).Count -ne 1 -or
        (Select-String -LiteralPath $stdout, $stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|INHERITED_PATH_ASSERT:' -Quiet)) { throw 'Missing exact PASS or reported script/assertion error' }
    $summaries = @($lines | Where-Object { $_.StartsWith('NOTEBOOK_INHERITED_PATH_AUDIT: ') })
    if ($summaries.Count -ne 1) { throw 'Expected one audit summary' }
    $result = $summaries[0].Substring('NOTEBOOK_INHERITED_PATH_AUDIT: '.Length) | ConvertFrom-Json
    if (-not $result.ok -or $result.harness_sha256 -cne $receipt.harness_sha256 -or
        @($result.cases).Count -ne $result.required_action_cases -or
        @($result.exclusions).Count -ne $result.required_exclusion_cases -or
        @($result.cases | Where-Object { @($_.passes).Count -ne 2 }).Count -ne 0 -or
        $result.new_entry_classes.legacy -ne 0 -or $result.new_entry_classes.unmapped -ne 0) { throw 'Incomplete, mismatched or invalid audit summary' }
    [IO.File]::WriteAllText((Join-Path $evidence 'inherited-paths.result.json'), ($result | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ok=$true;cases=$result.required_action_cases;exclusions=$result.required_exclusion_cases;assertions=$result.assertions;new_entry_classes=$result.new_entry_classes;source_corpus=$result.source_corpus;evidence=$evidence} | ConvertTo-Json -Depth 6
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
