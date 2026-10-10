param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('import','final','campaign-v2','campaign-ordinary','pack','pack-foundation','producer-contract','prologue-surfaces','migration','query','host')][string]$Mode,
    [string]$PackPath,
    [ValidateRange(1,7200)][int]$TimeoutSeconds = 3600
)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $EnginePath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$evidence = [IO.Path]::GetFullPath($EvidencePath)
if (-not ($project + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw 'Use a TEMP isolated project' }
if (-not ($evidence + '\').StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use a new TEMP evidence directory' }
function Get-Corpus([string]$Root, [string]$Subdirectory, [string]$Filter) {
    [string[]]$paths = @(Get-ChildItem -LiteralPath (Join-Path $Root $Subdirectory) -Filter $Filter -Recurse -File | ForEach-Object { $_.FullName })
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $rows = foreach ($path in $paths) { 'res://' + $path.Substring($Root.Length + 1).Replace('\','/') + "`t" + (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).ToLowerInvariant() } finally { $sha.Dispose() }
    [ordered]@{file_count=$paths.Count;sha256=$hash}
}
$scripts = Get-Corpus $project 'scripts' '*.gd'
$data = Get-Corpus $project 'data' '*'
New-Item -ItemType Directory -Path $evidence | Out-Null
$arguments = @('--headless','--path',('"'+$project+'"'))
$marker = $null
$pack = $null
$requireAuthored = $false
$notebookV2 = $false
switch ($Mode) {
    'import' { $arguments += @('--editor','--import') }
    'final' {
        $arguments += @('--','--notebook-final-smoke','--ggb-dev-notebook-v2','--notebook-require-authored','--notebook-producer-trace')
        $marker = 'NOTEBOOK_FINAL_SMOKE: PASS'; $requireAuthored = $true; $notebookV2 = $true
    }
    'campaign-v2' {
        $arguments += @('--','--full-campaign-smoke','--ggb-dev-notebook-v2','--notebook-require-authored','--notebook-producer-trace')
        $marker = 'FULL_CAMPAIGN_SMOKE: PASS'; $requireAuthored = $true; $notebookV2 = $true
    }
    'campaign-ordinary' { $arguments += @('--','--full-campaign-smoke'); $marker = 'FULL_CAMPAIGN_SMOKE: PASS' }
    'pack' {
        if (-not $PackPath) { throw 'A new TEMP output PCK is required' }
        $pack = [IO.Path]::GetFullPath($PackPath)
        if (-not $pack.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $pack)) { throw 'Use a new TEMP pack path' }
        $arguments += @('--export-pack','"Windows Desktop Debug"',('"'+$pack+'"'))
    }
    'pack-foundation' {
        if (-not $PackPath) { throw 'A previously generated TEMP PCK is required' }
        $pack = (Resolve-Path -LiteralPath $PackPath).Path
        if (-not $pack.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase)) { throw 'Use a TEMP pack' }
        # Run from an empty directory so loose project resources cannot satisfy the test.
        $empty = Join-Path $evidence 'empty'
        New-Item -ItemType Directory -Path $empty | Out-Null
        $arguments = @('--headless','--path',('"'+$empty+'"'),'--main-pack',('"'+$pack+'"'),'--','--foundation-smoke')
        $marker = 'FOUNDATION_SMOKE: PASS'
    }
    default {
        $arguments += @('--',('--notebook-'+$Mode+'-smoke'),'--ggb-dev-notebook-v2','--notebook-require-authored','--notebook-producer-trace')
        $marker = 'NOTEBOOK_'+$Mode.Replace('-','_').ToUpperInvariant()+'_SMOKE: PASS'
        $requireAuthored = $true; $notebookV2 = $true
    }
}
$stdout = Join-Path $evidence ($Mode+'.out.log')
$stderr = Join-Path $evidence ($Mode+'.err.log')
$oldAppData = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $started = [DateTime]::UtcNow.ToString('o')
    $child = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ($Mode+': PID='+$child.Id+' evidence='+$evidence)
    $finished = $child.WaitForExit($TimeoutSeconds*1000)
    if (-not $finished) { $child.Kill(); $child.WaitForExit() }
    $receipt = [ordered]@{schema_version=1;mode=$Mode;pid=$child.Id;completed=$finished;exit_code=$child.ExitCode;require_authored=$requireAuthored;notebook_v2=$notebookV2;
        arguments=$arguments;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');timeout_seconds=$TimeoutSeconds;
        engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();
        source_corpus=$scripts;data_corpus=$data;source_unchanged=((($scripts|ConvertTo-Json -Compress) -ceq ((Get-Corpus $project 'scripts' '*.gd')|ConvertTo-Json -Compress)) -and (($data|ConvertTo-Json -Compress) -ceq ((Get-Corpus $project 'data' '*')|ConvertTo-Json -Compress)));
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    if ($pack -and (Test-Path -LiteralPath $pack)) { $receipt.pack_sha256 = (Get-FileHash -LiteralPath $pack).Hash.ToLowerInvariant(); $receipt.pack_bytes = (Get-Item -LiteralPath $pack).Length }
    [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.run.json')), ($receipt|ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    if (-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged) { throw 'Native completion or immutable source check failed' }
    if (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -Quiet) { throw 'Native error reported' }
    $lines = @(Get-Content -LiteralPath $stdout)
    if ($Mode -eq 'producer-contract') {
        $summaries = @($lines|Where-Object {$_.StartsWith($marker+' ')})
        if ($summaries.Count -ne 1) { throw 'Writer native summary missing' }
        $summary = $summaries[0].Substring(($marker+' ').Length)|ConvertFrom-Json
        if ($summary.ok -isnot [bool] -or -not $summary.ok -or @($summary.errors).Count -ne 0) { throw 'Writer native summary failed' }
    } elseif ($marker -and @($lines|Where-Object {$_ -ceq $marker}).Count -ne 1) { throw 'Exact native PASS missing' }
    if ($Mode -eq 'pack' -and (-not $receipt.pack_sha256 -or $receipt.pack_bytes -le 0)) { throw 'Pack was not generated' }
    $lines | Where-Object {$_ -match '^Godot Engine|COVERAGE:|SMOKE:|^FINAL_PHASE:'}
    [pscustomobject]@{mode=$Mode;completed=$finished;exit_code=$child.ExitCode;source_corpus=$scripts;data_corpus=$data}
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocal
}
