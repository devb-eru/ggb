param([Parameter(Mandatory)][string]$EvidencePath,[Parameter(Mandatory)][string]$RepoPath)
$ErrorActionPreference='Stop'
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function Hash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
$m=Get-Content (Join-Path $EvidencePath 'manifest.json') -Raw|ConvertFrom-Json
$archive=Join-Path $EvidencePath 'raw.zip'
Require ($m.verification_id -ceq 'DISPLAY-STARTUP-20261105') 'Wrong verification ID'
Require ((Hash $archive) -ceq $m.archive_sha256) 'Archive hash mismatch'
Require ($m.source_files.Count -eq 311 -and $m.data_files.Count -eq 63) 'Unexpected source/data denominator'
foreach($f in @($m.source_files)+@($m.data_files)){Require ((Hash (Join-Path $RepoPath ('game/'+$f.path))) -ceq $f.sha256) ('Current source/data differs: '+$f.path)}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ggb-display-audit-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $root
$actual=@(Get-ChildItem $root -Recurse -File)
Require ($actual.Count -eq $m.raw_files.Count) 'Raw file denominator differs'
foreach($f in $m.raw_files){$p=Join-Path $root $f.path;Require ((Hash $p) -ceq $f.sha256 -and (Get-Item $p).Length -eq $f.bytes) ('Raw file differs: '+$f.path)}
$source=@{};foreach($f in $m.source_files){Require (-not $source.ContainsKey($f.path)) 'Duplicate source';$source[$f.path]=$f.sha256}
$expected=@('fixed-default','fixed-windowed','fixed-borderless','fixed-fullscreen','fixed-default-overrides')
Require ($m.runs.Count -eq 6 -and @($m.runs|Where-Object label -eq 'baseline-final').Count -eq 1) 'Run count differs'
$total=0
foreach($run in $m.runs){
    $dir=Join-Path $root $run.label
    $r=Get-Content (Join-Path $dir 'run.json') -Raw|ConvertFrom-Json
    $v=Get-Content (Join-Path $dir 'result.json') -Raw|ConvertFrom-Json
    Require ($r.label -ceq $run.label -and $r.completed -and -not $r.parse_error) 'Run not terminal/label mismatch'
    Require ((Hash (Join-Path $dir 'run.out.log')) -ceq $r.stdout_sha256 -and (Hash (Join-Path $dir 'run.err.log')) -ceq $r.stderr_sha256) 'Receipt log hashes differ'
    Require ((Get-Content (Join-Path $dir 'run.err.log') -Raw) -notmatch 'SCRIPT ERROR:|ERROR:') 'Unexpected engine error'
    Require ($v.test -ceq 'DISPLAY_STARTUP_SMOKE' -and $v.display_server -cne 'headless' -and $v.ready_before_first_process_frame) 'Native real startup was bypassed'
    Require ($v.check_count -eq $v.checks.Count -and @($v.checks|Where-Object{ -not $_.ok }).Count -eq $v.failures.Count) 'Check accounting differs'
    Require ($r.source_files.Count -eq 311) 'Run source denominator differs'
    $runMap=@{};foreach($f in $r.source_files){Require (-not $runMap.ContainsKey($f.path)) 'Duplicate run source';$runMap[$f.path]=$f.sha256}
    $diff=@($m.source_files|Where-Object{$runMap[$_.path] -cne $_.sha256})
    if($run.label -ceq 'baseline-final'){
        Require ($r.exit_code -eq 1 -and -not $v.ok -and $v.status -ceq 'fail') 'Baseline failure lost'
        Require ($diff.Count -eq 1 -and $diff[0].path -ceq 'scripts/ui/start_screen.gd') 'Baseline differs beyond product startup fix'
        Require ($v.failures.Count -eq 4 -and $v.final_window.mode -eq 0) 'Baseline no longer proves wrong mode'
        Require (@($v.failures|Where-Object{$_ -like 'startup/fullscreen_screen_origin:*'}).Count -eq 1) 'Baseline offscreen origin absent'
    }else{
        Require ($run.label -cin $expected -and $r.exit_code -eq 0 -and $v.ok -and $v.status -ceq 'pass' -and $v.failures.Count -eq 0) 'Candidate did not pass'
        Require ($diff.Count -eq 0 -and $v.controller_geometry -ceq 'run') 'Candidate source/geometry differs'
        Require ($v.check_count -ge 140 -and $v.geometry.Count -ge 20) 'Incomplete geometry checks'
        $want=3;if($run.label -ceq 'fixed-windowed'){$want=0};if($run.label -ceq 'fixed-fullscreen'){$want=4}
        Require ($v.final_window.mode -eq $want -and $v.final_window.native_mode -eq $want) 'Wrong final native mode'
        if($want -ne 0){Require (($v.final_window.position -join ',') -ceq ($v.final_window.screen_origin -join ',')) 'Fullscreen shifted';Require (($v.final_window.size -join ',') -ceq ($v.final_window.screen_native_size -join ',')) 'Fullscreen size differs'}
        Require (@($v.geometry|Where-Object{$_.control -like 'game/inventory_slot_*'}).Count -eq 6) 'Inventory slot coverage differs'
        Require (@($v.checks|Where-Object{$_.name -ceq 'game/reading_history/fits_native_client' -and $_.ok}).Count -eq 1) 'Reading footer coverage absent'
        Require (($r.arguments -contains '--windowed') -eq ($run.label -ceq 'fixed-default-overrides')) 'Unexpected CLI override case'
        $total+=$v.check_count
    }
    $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $dir 'source_scripts.zip'))
    try{
        $entries=@($zip.Entries|Where-Object{$_.FullName.EndsWith('.gd')})
        Require ($entries.Count -eq 311) 'Source ZIP denominator differs'
        foreach($entry in $entries){
            $stream=$entry.Open();try{$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()}finally{$sha.Dispose()}}finally{$stream.Dispose()}
            $path=$entry.FullName.Replace('\','/')
            Require ($runMap[$path] -ceq $hash) ('Source ZIP mismatch: '+$path)
        }
    }finally{$zip.Dispose()}
}
foreach($label in $expected){Require (@($m.runs|Where-Object label -ceq $label).Count -eq 1) 'Missing candidate case'}
foreach($name in @('start-screen','full-campaign')){
    $r=Get-Content (Join-Path $root ('regression/'+$name+'.json')) -Raw|ConvertFrom-Json
    Require ($r.completed -and $r.exit_code -eq 0 -and -not $r.parse_error -and $r.source_files.Count -eq 311) 'Headless regression did not pass'
    foreach($f in $r.source_files){Require ($source[$f.path] -ceq $f.sha256) 'Headless source differs'}
    $out=Join-Path $root ('regression/'+$name+'.out.log');$err=Join-Path $root ('regression/'+$name+'.err.log')
    Require ((Hash $out) -ceq $r.stdout_sha256 -and (Hash $err) -ceq $r.stderr_sha256) 'Headless receipt logs differ'
    Require ((Get-Content $err -Raw) -notmatch 'SCRIPT ERROR:|ERROR:') 'Headless engine error'
    $marker=if($name -eq 'full-campaign'){'FULL_CAMPAIGN_SMOKE: PASS'}else{'START_SCREEN_SMOKE: PASS'}
    Require ((Get-Content $out -Raw).Contains($marker)) 'Headless PASS marker absent'
}
@{ok=$true;native_successes=5;baseline_failures=1;native_checks=$total;headless_regressions=2;source_scripts=311;data_files=63;raw_files=$m.raw_files.Count;scope='native startup and geometry; not OS full playthrough or engine adoption'}|ConvertTo-Json
