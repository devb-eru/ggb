param([Parameter(Mandatory)][string]$EvidencePath,[Parameter(Mandatory)][string]$RepoPath)
$ErrorActionPreference='Stop'
function HashBytes([byte[]]$bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function Same($left,$right){
    if($null -eq $left -or $null -eq $right){return $null -eq $left -and $null -eq $right}
    if($left -is [Collections.IDictionary] -and $right -is [Collections.IDictionary]){
        if($left.Count -ne $right.Count){return $false}
        foreach($key in $left.Keys){if(-not $right.Contains($key) -or -not(Same $left[$key] $right[$key])){return $false}}
        return $true
    }
    if($left -is [Collections.IList] -and $right -is [Collections.IList]){
        if($left.Count -ne $right.Count){return $false}
        for($i=0;$i -lt $left.Count;$i++){if(-not(Same $left[$i] $right[$i])){return $false}}
        return $true
    }
    if($left -is [string] -or $right -is [string]){return $left -is [string] -and $right -is [string] -and $left -ceq $right}
    if($left -is [bool] -or $right -is [bool]){return $left -is [bool] -and $right -is [bool] -and $left -eq $right}
    return [double]$left -eq [double]$right
}
$manifest=Get-Content (Join-Path $EvidencePath 'manifest.json') -Raw|ConvertFrom-Json -AsHashtable
Require ($manifest.format_version -eq 1 -and $manifest.verification_id -ceq 'NB-EP02-BOUNDARIES-20261105') 'Manifest identity differs'
$archive=Join-Path $EvidencePath 'raw.zip'
Require ((Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant() -ceq $manifest.archive_sha256) 'Archive hash differs'
Require ($manifest.source_files.Count -eq 310 -and $manifest.data_files.Count -eq 63) 'Frozen source denominator differs'
Require (@($manifest.source_files.path|Sort-Object -Unique).Count -eq 310 -and @($manifest.data_files.path|Sort-Object -Unique).Count -eq 63) 'Duplicate frozen source path'
foreach($file in @($manifest.source_files)+@($manifest.data_files)){
    Require ((Get-FileHash -LiteralPath (Join-Path $RepoPath ('game/'+$file.path))).Hash.ToLowerInvariant() -ceq $file.sha256) ('Source differs: '+$file.path)
}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
$files=@{}
try{
    Require ($zip.Entries.Count -eq $manifest.raw_files.Count) 'Raw file count differs'
    foreach($file in $manifest.raw_files){
        Require (-not $files.ContainsKey($file.path)) 'Duplicate raw path'
        $entry=$zip.GetEntry($file.path)
        Require ($null -ne $entry -and $entry.Length -eq $file.bytes) ('Missing raw file '+$file.path)
        $s=$entry.Open();$m=[IO.MemoryStream]::new()
        try{$s.CopyTo($m);$bytes=$m.ToArray()}finally{$s.Dispose();$m.Dispose()}
        Require ((HashBytes $bytes) -ceq $file.sha256) ('Raw hash differs '+$file.path)
        $files[$file.path]=$bytes
    }
}finally{$zip.Dispose()}
function RawText([string]$path){Require ($files.ContainsKey($path)) ('Missing '+$path);[Text.Encoding]::UTF8.GetString($files[$path])}
function RawJson([string]$path){RawText $path|ConvertFrom-Json -AsHashtable}
function ResultJson([string]$path,[string]$marker){
    $matches=@([regex]::Matches((RawText $path),'(?m)^'+[regex]::Escape($marker)+': (\{[^\r\n]+\})\r?$'))
    Require ($matches.Count -eq 1) ('Result marker missing or repeated '+$path)
    return $matches[0].Groups[1].Value|ConvertFrom-Json -AsHashtable
}
foreach($stem in @('baseline/run','scope/run','boundaries/run','regression/sheet','regression/ep01','regression/modal-seed','regression/modal-resume','regression/modal-completed','regression/campaign')){
    $receipt=RawJson ($stem+'.json')
    Require ((HashBytes $files[$stem+'.out.log']) -ceq $receipt.stdout_sha256 -and (HashBytes $files[$stem+'.err.log']) -ceq $receipt.stderr_sha256) ('Receipt log hash differs '+$stem)
}
$scope=RawJson 'scope/run.json'
$boundary=RawJson 'boundaries/run.json'
$baseline=RawJson 'baseline/run.json'
$scopeResult=ResultJson 'scope/run.out.log' 'NOTEBOOK_J3_RETRY_SCOPE_RESULT'
$boundaryResult=ResultJson 'boundaries/run.out.log' 'EP02_MODAL_BOUNDARY_RESULT'
Require ($scopeResult.ok -eq $true -and $scopeResult.cases -eq 18 -and $scopeResult.assertions -eq 2298 -and $scopeResult.errors.Count -eq 0) 'Retry scope result differs'
Require ($boundaryResult.ok -eq $true -and $boundaryResult.cases -eq 44 -and $boundaryResult.checks -eq 692 -and $boundaryResult.errors.Count -eq 0) 'Boundary result differs'
Require ($baseline.completed -and $baseline.exit_code -eq 1) 'Original failure was relabeled'
$baselineResult=ResultJson 'baseline/run.out.log' 'NOTEBOOK_J3_RETRY_SCOPE_RESULT'
Require ($baselineResult.ok -eq $false -and $baselineResult.cases -eq 18 -and $baselineResult.assertions -eq 2334 -and $baselineResult.errors.Count -gt 0) 'Original failure result differs'
Require ((RawText 'baseline/run.out.log') -match '"ok":false' -and (RawText 'baseline/run.out.log') -match 'stale UI callable preserves full snapshot') 'Actual UI failure evidence missing'
$final=@(@('scope','NOTEBOOK_J3_RETRY_SCOPE_RESULT: .*"ok":true'),@('boundaries','EP02_MODAL_BOUNDARY_RESULT: .*"ok": true'))
foreach($spec in $final){
    $r=RawJson ($spec[0]+'/run.json');$out=RawText ($spec[0]+'/run.out.log');$err=RawText ($spec[0]+'/run.err.log')
    Require ($r.completed -and -not $r.script_error -and $r.exit_code -eq 0 -and $out -match $spec[1]) ('Native failure '+$spec[0])
    Require (($out+$err) -notmatch 'SCRIPT ERROR:|Parse Error:|(?m)^ERROR:|J3_RETRY_ASSERT: .* FAIL ') ('Log error '+$spec[0])
    Require (Same $r.meta.source_files $manifest.source_files) 'Focused run source differs'
}
$expectedMarkers=@{sheet='SHEET_SYNC_SMOKE PASS checks=3361 failures=0';ep01='EP01_SHEET_SMOKE PASS: 557';'modal-seed'='NOTEBOOK_MODAL_PRESENTATION_CHECKS: seed 980';'modal-resume'='NOTEBOOK_MODAL_PRESENTATION_CHECKS: resume 7';'modal-completed'='NOTEBOOK_MODAL_PRESENTATION_CHECKS: completed 4';campaign='FULL_CAMPAIGN_SMOKE: PASS'}
foreach($name in $expectedMarkers.Keys){
    $r=RawJson ('regression/'+$name+'.json');$out=RawText ('regression/'+$name+'.out.log');$err=RawText ('regression/'+$name+'.err.log')
    Require ($r.completed -and -not $r.script_error -and $r.exit_code -eq 0 -and $out.Contains($expectedMarkers[$name])) ('Regression failure '+$name)
    Require (($out+$err) -notmatch 'SCRIPT ERROR:|Parse Error:|(?m)^ERROR:') ('Regression log error '+$name)
    Require (Same $r.source.source_files $manifest.source_files) ('Regression source differs '+$name)
}
$before=@{};foreach($file in $baseline.meta.source_files){$before[$file.path]=$file.sha256}
$changes=@($manifest.source_files|Where-Object{$before[$_.path] -cne $_.sha256})
Require ($changes.Count -eq 1 -and $changes[0].path -ceq 'scripts/chapters/chapter_one_controller.gd') 'Unexpected product/source changes between negative and fixed runs'
foreach($pair in @(@('baseline',$baseline.meta.source_files),@('scope',$manifest.source_files),@('boundaries',$manifest.source_files))){
    $stream=[IO.MemoryStream]::new([byte[]]$files[$pair[0]+'/source_scripts.zip'],$false)
    $sources=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read)
    try{
        Require (@($sources.Entries|Where-Object{$_.FullName.EndsWith('.gd')}).Count -eq 310) 'Archived script denominator differs'
        foreach($file in $pair[1]){
            $entry=$sources.GetEntry($file.path)
            Require ($null -ne $entry) ('Archived source missing '+$file.path)
            $s=$entry.Open();$m=[IO.MemoryStream]::new()
            try{$s.CopyTo($m);$bytes=$m.ToArray()}finally{$s.Dispose();$m.Dispose()}
            Require ((HashBytes $bytes) -ceq $file.sha256) ('Archived source differs '+$file.path)
        }
    }finally{$sources.Dispose();$stream.Dispose()}
}
$trace=RawJson 'boundaries/trace.json'
Require ($trace.pid -eq $boundary.pid -and $trace.cases.Count -eq 44) 'Boundary trace denominator differs'
$expected=@('options/C4/false/false','options/C4/false/true','close/c4/false','close/c4/true','restore/c4/choosing','memory/reading','memory/finish_pending','memory/completion')
foreach($i in 0..2){foreach($switch in @('false','true')){$expected+='answer/'+$i+'/'+$switch}}
foreach($replay in @('false','true')){
    foreach($ack in @('false','true')){$expected+='options/J3/'+$replay+'/'+$ack}
    foreach($i in 0..1){$expected+='close/j3/'+$replay+'/'+$i}
}
foreach($locale in @('ko-KR','en-US')){
    $rows=@($trace.cases|Where-Object starting_locale -CEQ $locale)
    Require ($rows.Count -eq 22 -and @(Compare-Object ($expected|Sort-Object) ($rows.case_id|Sort-Object)).Count -eq 0) 'Independent boundary set differs'
    foreach($row in $rows){
        Require ($row.passed -and $row.errors.Count -eq 0) ('Failed trace '+$row.case_id)
        Require (Same $row.snapshot $row.disk) ('Trace RAM/disk differs '+$row.case_id)
        Require (@($row.ack_loss_transactions|Sort-Object -Unique).Count -eq $row.ack_loss_transactions.Count) 'Duplicate acknowledged transaction'
        $state=$row.snapshot;$entries=$state.meta_progress.dialogue_history.entries
        $mirror=$state.loop_state.event_local_states.BLACK_MIRROR
        if($row.case_id.StartsWith('answer/')){
            $parts=$row.case_id.Split('/');$target=[int]$parts[1];if($parts[2] -ceq 'true'){$target=($target+1)%3}
            Require ($mirror.cleaner_ready -eq ($target -ne 2) -and $mirror.surface_open -eq ($target -eq 2) -and $mirror.dry_passed -eq ($target -eq 0)) 'Accepted answer physical state differs'
            # v2 observations use selection IDs; CH01..03 are body localization IDs.
            foreach($i in 0..2){$id='NB_EP02_CHOICE_C4_COMMIT_SELECT_'+$i;$count=@($entries|Where-Object{$_.observation.content_id -ceq $id -and $_.observation.entry_kind -ceq 'choice_confirmed'}).Count;Require ($count -eq [int]($i -eq $target)) ('Rejected/unselected answer was disclosed: '+$row.starting_locale+'/'+$row.case_id+'/'+$id)}
        }
        if($row.case_id.StartsWith('memory/') -or $row.case_id.Contains('/J3/') -or $row.case_id.StartsWith('close/j3/')){
            Require ($state.meta_progress.journal_stage -eq 2 -and $mirror.j3_order.Count -eq 0) 'Optional memory solved physical journal'
            Require (@($entries|Where-Object{$_.observation.producer_id -ceq 'NP05' -and $_.observation.entry_kind -ceq 'choice_confirmed'}).Count -eq 0) 'UI-only memory invented answer observation'
        }
    }
}
[pscustomobject]@{ok=$true;source_scripts=310;data_files=63;boundary_cases=44;boundary_checks=692;retry_scope_cases=18;retry_scope_assertions=2298;native_successes=8;raw_files=$manifest.raw_files.Count;scope='EP02 focused regression, not OS/full acceptance'}|ConvertTo-Json
