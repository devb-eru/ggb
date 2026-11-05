param([Parameter(Mandatory)][string]$EvidencePath,[Parameter(Mandatory)][string]$RepoPath)
$ErrorActionPreference='Stop'
function Require([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function Hash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
$m=Get-Content (Join-Path $EvidencePath 'manifest.json') -Raw|ConvertFrom-Json
Require ($m.id -ceq 'INVENTORY-DRAG-FEEDBACK-20261105' -and $m.source_files.Count -eq 313) 'Wrong evidence/source denominator'
$archive=Join-Path $EvidencePath 'raw.zip'
Require ((Hash $archive) -ceq $m.archive_sha256) 'Archive differs'
foreach($f in $m.source_files){Require ((Hash (Join-Path $RepoPath ('game/'+$f.path))) -ceq $f.sha256) ('Current source differs: '+$f.path)}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ggb-drag-audit-'+[Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $archive -DestinationPath $root
Require (@(Get-ChildItem $root -Recurse -File).Count -eq $m.raw_files.Count) 'Raw denominator differs'
foreach($f in $m.raw_files){Require ((Hash (Join-Path $root $f.path)) -ceq $f.sha256 -and (Get-Item (Join-Path $root $f.path)).Length -eq $f.bytes) ('Raw differs: '+$f.path)}
$maps=@{}
foreach($name in @('baseline','candidate')){
    $r=Get-Content (Join-Path $root ($name+'/run.json')) -Raw|ConvertFrom-Json
    $out=Join-Path $root ($name+'/run.out.log');$err=Join-Path $root ($name+'/run.err.log')
    Require ($r.completed -and -not $r.parse_error -and $r.source_files.Count -eq 313) 'Run incomplete'
    Require ((Hash $out) -ceq $r.stdout_sha256 -and (Hash $err) -ceq $r.stderr_sha256) 'Receipt logs differ'
    Require (([string](Get-Content $err -Raw)) -notmatch 'SCRIPT ERROR:|ERROR:') 'Focused engine error'
    $line=@(Get-Content $out|Where-Object{$_ -like 'INVENTORY_DRAG_FEEDBACK_RESULT: *'})
    Require ($line.Count -eq 1) 'Missing focused result'
    $v=$line[0].Substring('INVENTORY_DRAG_FEEDBACK_RESULT: '.Length)|ConvertFrom-Json
    Require ($v.checks -eq 244 -and 'engine_drag_notification_delivery' -cin $v.not_covered) 'Coverage accounting differs'
    if($name -eq 'baseline'){Require ($r.exit_code -eq 1 -and -not $v.ok -and $v.errors.Count -eq 20) 'Baseline failure lost'}
    else{Require ($r.exit_code -eq 0 -and $v.ok -and $v.errors.Count -eq 0) 'Candidate not passed'}
    $map=@{};foreach($f in $r.source_files){Require (-not $map.ContainsKey($f.path)) 'Duplicate source';$map[$f.path]=$f.sha256}
    $maps[$name]=$map
    $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $root ($name+'/source_scripts.zip')))
    try{
        $entries=@($zip.Entries|Where-Object{$_.FullName.EndsWith('.gd')});Require ($entries.Count -eq 313) 'Source ZIP denominator differs'
        foreach($entry in $entries){$stream=$entry.Open();try{$sha=[Security.Cryptography.SHA256]::Create();try{$h=[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()}finally{$sha.Dispose()}}finally{$stream.Dispose()};Require ($map[$entry.FullName.Replace('\','/')] -ceq $h) 'Source ZIP differs'}
    }finally{$zip.Dispose()}
}
$diff=@($m.source_files|Where-Object{$maps.baseline[$_.path] -cne $_.sha256})
Require ($diff.Count -eq 1 -and $diff[0].path -ceq 'scripts/prologue/prologue_controller.gd') 'Baseline differs beyond targeted product fix'
foreach($f in $m.source_files){Require ($maps.candidate[$f.path] -ceq $f.sha256) 'Candidate corpus differs'}
$failures=@()
foreach($dir in @('baseline-chapter-one','candidate-related')){
    $r=Get-Content (Join-Path $root ($dir+'/chapter-one.json')) -Raw|ConvertFrom-Json
    Require ($r.completed -and $r.exit_code -eq 1) 'Existing chapter-one failure was hidden'
    $log=Get-Content (Join-Path $root ($dir+'/chapter-one.err.log')) -Raw
    Require ($log -match 'CHAPTER_ONE_SMOKE: FAIL (\[[^\r\n]+\])') 'Chapter-one failure array absent'
    $a=@($Matches[1]|ConvertFrom-Json);Require ($a.Count -eq 8) 'Chapter-one failure count differs'
    $failures+=,($a -join "`n")
}
Require ($failures[0] -ceq $failures[1]) 'Baseline/candidate chapter-one failures differ'
$prologue=Get-Content (Join-Path $root 'candidate-related/prologue.json') -Raw|ConvertFrom-Json
$log=Get-Content (Join-Path $root 'candidate-related/prologue.out.log') -Raw
Require ($prologue.completed -and $prologue.exit_code -eq 0 -and $log.Contains('PROLOGUE_SCENE_CHECKS: 265') -and $log.Contains('PROLOGUE_SCENE_SMOKE: PASS')) 'Related prologue not passed'
@{ok=$true;focused_checks=244;baseline_errors=20;candidate_errors=0;related_prologue_checks=265;chapter_one_baseline_and_candidate_failures=8;raw_files=$m.raw_files.Count;source_scripts=313;scope='synthetic drag-end only; not OS/engine delivery'}|ConvertTo-Json
