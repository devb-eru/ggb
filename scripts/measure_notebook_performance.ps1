[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$PackPath,
    [string]$OutputDirectory = (Join-Path $env:TEMP ("ggb-notebook-perf-" + [guid]::NewGuid().ToString("N"))),
    [ValidateRange(1,100)][int]$ColdRuns = 20,
    [ValidateRange(0,1000)][int]$WarmRuns = 100,
    [ValidateSet("NB-PERF-N2000","NB-PERF-L10000","NB-PERF-P2001","NB-PERF-LONG")]
    [string[]]$Fixtures = @("NB-PERF-N2000","NB-PERF-L10000","NB-PERF-P2001","NB-PERF-LONG"),
    [ValidateSet("ko-KR","en-US")][string[]]$Locales = @("ko-KR","en-US"),
    [ValidateRange(60,7200)][int]$DeadlineSeconds = 1800
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "This process-memory probe targets Windows." }
$exe = (Resolve-Path -LiteralPath $GodotPath).Path
$pack = (Resolve-Path -LiteralPath $PackPath).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) {
    if (@(Get-ChildItem -LiteralPath $output -Force).Count -gt 0) { throw "Use a new empty output directory; previous evidence is never overwritten." }
}
New-Item -ItemType Directory -Force -Path $output | Out-Null

function Get-Statistics([double[]]$Values) {
    if ($null -eq $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    [ordered]@{
        count = $Values.Count
        first = $Values[0]
        mean = ($Values | Measure-Object -Average).Average
        maximum = $sorted[-1]
        p95 = $sorted[[math]::Ceiling(0.95 * $sorted.Count) - 1]
    }
}
if ((Get-Statistics (1..20)).p95 -ne 19 -or (Get-Statistics (1..100)).p95 -ne 95 -or $null -ne (Get-Statistics @())) {
    throw "Nearest-rank percentile self-check failed."
}
$oldAppData = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
$runs = [Collections.Generic.List[object]]::new()
$groups = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()
$knownHashes = @{}
try {
    foreach ($fixture in $Fixtures) {
        foreach ($locale in $Locales) {
            $groupRuns = [Collections.Generic.List[object]]::new()
            for ($cold = 0; $cold -lt $ColdRuns; $cold++) {
                $name = "$fixture-$locale-$cold"
                $runDir = Join-Path $output $name
                $empty = Join-Path $runDir "empty"
                New-Item -ItemType Directory -Force -Path $empty | Out-Null
                $env:APPDATA = Join-Path $runDir "appdata"
                $env:LOCALAPPDATA = $env:APPDATA
                $stdout = Join-Path $runDir "stdout.log"
                $stderr = Join-Path $runDir "stderr.log"
                $warm = if ($cold -eq 0) { $WarmRuns } else { 0 }
                $arguments = @("--headless","--path",('"' + $empty + '"'),"--main-pack",('"' + $pack + '"'),"--",
                    "--ggb-dev-notebook-v2","--notebook-performance-probe","--nb-perf-fixture=$fixture",
                    "--nb-perf-locale=$locale","--nb-perf-warm=$warm")
                $timer = [Diagnostics.Stopwatch]::StartNew()
                $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
                $peak = 0L
                $fatal = ""
                while (-not $process.WaitForExit(50)) {
                    $process.Refresh()
                    $peak = [math]::Max($peak, $process.PeakWorkingSet64)
                    $errorText = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
                    if ($errorText -match "SCRIPT ERROR:|Parse Error:|Compilation failed|Failed loading resource:" -or $timer.Elapsed.TotalSeconds -gt $DeadlineSeconds) {
                        $fatal = "Script failure or execution deadline; see stderr."
                        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                        $process.WaitForExit()
                        break
                    }
                }
                $process.Refresh()
                $log = Get-Content -LiteralPath $stdout -Raw
                $lines = @($log -split "`n" | Where-Object { $_.StartsWith("NOTEBOOK_PERF_RESULT: ") })
                $result = $null
                if ($lines.Count -eq 1) { $result = $lines[0].Substring("NOTEBOOK_PERF_RESULT: ".Length) | ConvertFrom-Json -AsHashtable }
                $pass = $fatal -eq "" -and $process.ExitCode -eq 0 -and $null -ne $result -and $result.ok
                if ($pass) {
                    if ($knownHashes.ContainsKey($fixture) -and $knownHashes[$fixture] -ne $result.manifest.sha256) {
                        $pass = $false
                        $fatal = "Fixture hash differs across processes/locales."
                    }
                    $knownHashes[$fixture] = $result.manifest.sha256
                }
                $run = [ordered]@{name=$name;process_id=$process.Id;exit_code=$process.ExitCode;functional_pass=$pass;
                    failure=$fatal;wall_seconds=$timer.Elapsed.TotalSeconds;peak_working_set_bytes=$peak;result=$result}
                $runs.Add($run)
                $groupRuns.Add($run)
                $run | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $runDir "result.json") -Encoding utf8
                if (-not $pass) { $failures.Add($name); Write-Output "$name FAIL"; break }
                Write-Output "$name measured ($([math]::Round($timer.Elapsed.TotalSeconds,1))s)"
            }
            $metrics = @{}
            foreach ($run in $groupRuns) {
                if (-not $run.functional_pass) { continue }
                foreach ($metric in $run.result.timings_ms.Keys) {
                    if (-not $metrics.ContainsKey($metric)) { $metrics[$metric] = [Collections.Generic.List[double]]::new() }
                    foreach ($value in $run.result.timings_ms[$metric]) { $metrics[$metric].Add([double]$value) }
                }
            }
            $statistics = @{}
            foreach ($metric in $metrics.Keys) { $statistics[$metric] = Get-Statistics $metrics[$metric].ToArray() }
            $groups.Add([ordered]@{fixture=$fixture;locale=$locale;cold_runs=$groupRuns.Count;statistics_ms=$statistics;
                peak_process_working_set=Get-Statistics @($groupRuns | ForEach-Object {[double]$_.peak_working_set_bytes})})
        }
    }
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocal
}
$summary = [ordered]@{
    format_version=1;created_utc=[DateTime]::UtcNow.ToString("o");pack_sha256=(Get-FileHash -LiteralPath $pack -Algorithm SHA256).Hash
    engine_sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash;percentile="nearest rank ceil(0.95*n)"
    cold_definition="Fresh OS process; fixture parsed before model timer. OS disk cache NOT flushed."
    warm_definition="Warm model operations in first process; warm model search excludes debounce/input/rendering."
    acceptance="MEASUREMENT_ONLY";device_class="NOT_CLASSIFIED";renderer="headless"
    sampling_complete=($ColdRuns -ge 20 -and $WarmRuns -ge 100 -and $Fixtures.Count -eq 4 -and $Locales.Count -eq 2 -and $failures.Count -eq 0)
    requested_cold=$ColdRuns;requested_warm=$WarmRuns;groups=$groups;failed_runs=$failures;runs=$runs
    not_covered=@("OS input/IME","GPU/driver and device-class acceptance","warm UI input p95","50 open/close RAM recovery","60s input frame capture","Alt+Tab")
}
$summary | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $output "summary.json") -Encoding utf8
Write-Output "Measurement summary: $(Join-Path $output 'summary.json')"
if ($failures.Count -gt 0) { throw "Probe failures: $($failures -join ', ')" }
