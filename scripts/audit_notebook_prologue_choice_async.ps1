param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
$hashCache=@{}
function Assert-Condition([bool]$Value,[string]$Label){if(-not $Value){throw $Label};$script:checks++}
function Hash([string]$Path){
    $key=[IO.Path]::GetFullPath($Path)
    if(-not $script:hashCache.ContainsKey($key)){$script:hashCache[$key]=(Get-FileHash -LiteralPath $key).Hash.ToLowerInvariant()}
    $script:hashCache[$key]
}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
$manifest=Read-Json (Join-Path $root 'manifest.json')
Assert-Condition (@($manifest.files).Count -ge 31 -and @($manifest.files.path|Select-Object -Unique).Count -eq @($manifest.files).Count) 'Evidence denominator/duplicate'
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-Condition ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) 'Escaping evidence path'
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) ('Missing '+$row.path)
    Assert-Condition ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Changed '+$row.path)
}
$source=Read-Json (Join-Path $root 'source.json')
Assert-Condition (@($source.files).Count -eq 2) 'Product denominator'
foreach($row in $source.files){Assert-Condition ((Hash (Join-Path $repo $row.path)) -ceq $row.candidate_sha256) ('Product differs '+$row.path)}
$configs=@(
    @('focused-final','focused','run_notebook_prologue_choice_async_audit.ps1','PROLOGUE_CHOICE_ASYNC_SMOKE:PASS'),
    @('history','focused','run_notebook_history_async_audit.ps1','HISTORY_ASYNC_SMOKE:PASS'),
    @('migration','migration','run_notebook_save_preflight_audit.ps1','NOTEBOOK_MIGRATION_SMOKE: PASS'),
    @('host','host','run_notebook_save_preflight_audit.ps1','NOTEBOOK_HOST_SMOKE: PASS'),
    @('prologue','run','run_notebook_prologue_compatibility.ps1','NOTEBOOK_PROLOGUE_SMOKE: PASS '),
    @('cursor_seed','run','run_notebook_prologue_compatibility.ps1','NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'),
    @('cursor_resume','run','run_notebook_prologue_compatibility.ps1','NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'),
    @('cursor_completed','run','run_notebook_prologue_compatibility.ps1','NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'))
foreach($config in $configs){
    $dir=$config[0];$name=$config[1]
    $receipt=Join-Path $root ($dir+'/'+$name+$(if($name -eq 'run'){'.json'}else{'.run.json'}))
    $run=Read-Json $receipt
    Assert-Condition ($run.completed -and $run.exit_code -eq 0 -and $run.source_unchanged) ($dir+' native/source failure')
    Assert-Condition ($run.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $run.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine differs'
    Assert-Condition ($run.source_corpus.file_count -eq 265 -and @($run.source_corpus.rows).Count -eq 265 -and @($run.source_corpus.rows|Select-Object -Unique).Count -eq 265) 'Corpus denominator/duplicate'
    foreach($row in $run.source_corpus.rows){
        $columns=$row.Split("`t")
        Assert-Condition ($columns.Count -eq 2 -and $columns[0].StartsWith('scripts/') -and -not $columns[0].Contains('..')) 'Source path invalid'
        Assert-Condition ((Hash (Join-Path $repo ('game/'+$columns[0]))) -ceq $columns[1]) 'Mixed product corpus'
    }
    $runner=if($config[2] -eq 'ORIGINAL_COMPATIBILITY'){Join-Path $root 'runners/compatibility-original.ps1'}else{Join-Path $PSScriptRoot $config[2]}
    Assert-Condition ((Hash $runner) -ceq $run.runner_sha256) 'Runner differs'
    $out=Join-Path $root ($dir+'/'+$name+'.out.log');$err=Join-Path $root ($dir+'/'+$name+'.err.log')
    Assert-Condition ((Hash $out) -ceq $run.stdout_sha256 -and (Hash $err) -ceq $run.stderr_sha256) 'Native log differs'
    Assert-Condition (-not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Script failure'
    $lines=@(Get-Content -LiteralPath $out)
    $passes=if($dir -eq 'prologue'){@($lines|Where-Object {$_.StartsWith($config[3])})}else{@($lines|Where-Object {$_ -ceq $config[3]})}
    Assert-Condition ($passes.Count -eq 1) ('PASS missing '+$dir)
    if($dir -eq 'focused-final'){
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_prologue_choice_async_audit.gd')) -ceq $run.harness_sha256 -and (Hash (Join-Path $PSScriptRoot 'tests/notebook_prologue_choice_async_audit.tscn')) -ceq $run.scene_sha256) 'Focused harness/scene differs'
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.gd')) -ceq $run.base_harness_sha256) 'Base harness differs'
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_prologue_async_audit.gd')) -ceq $run.parent_harness_sha256) 'Parent harness differs'
    }
    if($dir -eq 'history'){
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.gd')) -ceq $run.harness_sha256) 'History harness differs'
        $raw=@($lines|Where-Object {$_.StartsWith('HISTORY_ASYNC_AUDIT: ')})
        Assert-Condition ($raw.Count -eq 1) 'History result missing'
        $result=$raw[0].Substring('HISTORY_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
        Assert-Condition ($result.ok -and @($result.errors).Count -eq 0 -and @($result.cases).Count -eq 72 -and @($result.cases|Where-Object {-not $_.passed}).Count -eq 0) 'History regression failure'
    }
    if($dir -eq 'prologue'){
        $raw=@($lines|Where-Object {$_.StartsWith('NOTEBOOK_PROLOGUE_BRANCH_AUDIT: ')})
        Assert-Condition ($raw.Count -eq 1) 'Producer branch audit missing'
        $audit=$raw[0].Substring('NOTEBOOK_PROLOGUE_BRANCH_AUDIT: '.Length)|ConvertFrom-Json
        Assert-Condition ($audit.required_count -gt 0 -and $audit.observed_count -ge $audit.required_count -and @($audit.not_covered).Count -eq 0 -and @($audit.unmapped).Count -eq 0 -and @($audit.errors).Count -eq 0) 'Legacy producer branch audit failed'
    }
}
$seed=Read-Json (Join-Path $root 'cursor_seed/run.json')
$resume=Read-Json (Join-Path $root 'cursor_resume/run.json')
$completed=Read-Json (Join-Path $root 'cursor_completed/run.json')
Assert-Condition ($seed.profile -ceq $resume.profile -and $resume.profile -ceq $completed.profile -and [DateTime]$resume.started_utc -gt [DateTime]$seed.finished_utc -and [DateTime]$completed.started_utc -gt [DateTime]$resume.finished_utc) 'Cursor process order differs'
$failed=Read-Json (Join-Path $root 'focused/focused.run.json')
Assert-Condition ($failed.completed -and $failed.exit_code -ne 0 -and (Hash (Join-Path $root 'focused/notebook_prologue_choice_async_audit.gd')) -ceq $failed.harness_sha256) 'Initial parse failure reclassified'
foreach($suffix in @('out','err')){
    $path=Join-Path $root ('focused/focused.'+$suffix+'.log')
    Assert-Condition ((Hash $path) -ceq $failed.$(if($suffix -eq 'out'){'stdout_sha256'}else{'stderr_sha256'})) 'Failed native log differs'
}
$intermediate=Read-Json (Join-Path $root 'focused-fixed/focused.run.json')
Assert-Condition ($intermediate.completed -and $intermediate.exit_code -ne 0 -and $intermediate.source_unchanged) 'P4 intermediate failure reclassified'
Assert-Condition ((Hash (Join-Path $root 'focused-fixed/prologue_controller.gd')) -ceq ($intermediate.source_corpus.rows|Where-Object {$_.StartsWith("scripts/prologue/prologue_controller.gd`t")}).Split("`t")[1]) 'P4 old source differs'
foreach($row in $intermediate.source_corpus.rows){
    $columns=$row.Split("`t")
    $path=if($columns[0] -ceq 'scripts/prologue/prologue_controller.gd'){Join-Path $root 'focused-fixed/prologue_controller.gd'}elseif($columns[0] -ceq 'scripts/systems/prologue_save_candidate.gd'){Join-Path $root 'archive/prologue_save_candidate.gd'}else{Join-Path $repo ('game/'+$columns[0])}
    Assert-Condition ((Hash $path) -ceq $columns[1]) 'Unexpected intermediate code difference'
}
$oldOut=Join-Path $root 'focused-fixed/focused.out.log'
$oldErr=Join-Path $root 'focused-fixed/focused.err.log'
Assert-Condition ((Hash $oldOut) -ceq $intermediate.stdout_sha256 -and (Hash $oldErr) -ceq $intermediate.stderr_sha256) 'P4 intermediate log differs'
Assert-Condition (-not (Select-String -LiteralPath $oldOut,$oldErr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'P4 assertion failure confused with script failure'
$oldRaw=@(Get-Content -LiteralPath $oldOut|Where-Object {$_.StartsWith('PROLOGUE_CHOICE_ASYNC_AUDIT: ')})
Assert-Condition ($oldRaw.Count -eq 1) 'P4 intermediate result missing'
$oldResult=$oldRaw[0].Substring('PROLOGUE_CHOICE_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
Assert-Condition (-not $oldResult.ok -and @($oldResult.errors).Count -eq 4 -and @($oldResult.cases).Count -eq 140 -and @($oldResult.cases|Where-Object {-not $_.passed}).Count -eq 4) 'P4 failure denominator differs'
foreach($row in @($oldResult.cases|Where-Object {-not $_.passed})){
    Assert-Condition ($row.kind -ceq 'choice' -and $row.mode -ceq 'p4_father' -and $row.scenario -in @('options_fail','options_replace')) 'P4 failure outside repaired boundary'
}
$result=Read-Json (Join-Path $root 'focused-final/focused.result.json')
$raw=@(Get-Content (Join-Path $root 'focused-final/focused.out.log')|Where-Object {$_.StartsWith('PROLOGUE_CHOICE_ASYNC_AUDIT: ')})
Assert-Condition ($raw.Count -eq 1) 'Focused result missing'
$native=$raw[0].Substring('PROLOGUE_CHOICE_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
Assert-Condition (($native|ConvertTo-Json -Depth 16 -Compress) -ceq ($result|ConvertTo-Json -Depth 16 -Compress)) 'Derived summary differs'
Assert-Condition ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 2128 -and $result.required_cases -eq 152 -and @($result.cases).Count -eq 152 -and @($result.timings).Count -eq 8) 'Focused result/denominator'
foreach($locale in @('ko_KR','en_US')){
    foreach($scenario in @('same_locale','other_locale','location','occurrence','content','completed')){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'retry_identity' -and $_.scenario -ceq $scenario -and $_.locale -ceq $locale})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate retry identity '+$scenario)
    }
    foreach($kind in @('candidate','ui')){
        $expected=if($kind -eq 'candidate'){@('basic','window','combined','stale_note','malformed')}else{@('success','promotion','ack','replace','locale','service','progress_changed','pending_note_changed','handoff','after_action','after_action_failure')}
        foreach($scenario in $expected){
            $rows=@($result.cases|Where-Object {$_.kind -ceq $kind -and $_.scenario -ceq $scenario -and $_.locale -ceq $locale})
            Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate base condition '+$kind+':'+$scenario)
        }
    }
    foreach($mode in @('p3_journal','p4_father','P1_EXIT','P6_SLEEP')){
        $answers=switch($mode){'p3_journal'{@('author','locked','silent')}'p4_father'{@('father_tea','mansion_age','luca_tenure')}default{@('confirm','cancel')}}
        $expected=@('success','options_fail','selected_fail','ack','options_replace','selected_replace','selected_locale','selected_context')+@($answers|ForEach-Object {'answer_'+$_})
        foreach($scenario in $expected){
            $rows=@($result.cases|Where-Object {$_.kind -ceq 'choice' -and $_.mode -ceq $mode -and $_.scenario -ceq $scenario -and $_.locale -ceq $locale})
            Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate choice '+$mode+':'+$scenario)
        }
        foreach($phase in @('choosing','selection_pending')){
            $rows=@($result.cases|Where-Object {$_.kind -ceq 'restore' -and $_.mode -ceq $mode -and $_.phase -ceq $phase -and $_.locale -ceq $locale})
            Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate restore '+$mode+':'+$phase)
        }
    }
    foreach($fixture in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'large' -and $_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        $timing=@($result.timings|Where-Object {$_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed -and $timing.Count -eq 1 -and $timing[0].worker_frames -gt 0 -and $timing[0].total_ms -gt 0) 'Large composite failed'
    }
}
$processCount=0
$processChecks=0
foreach($saving in @('sync','async')){
foreach($seedLocale in @('ko_KR','en_US')){
    foreach($mode in @('p3_journal','p4_father','P1_EXIT','P6_SLEEP')){
        $previous=$null
        $resumeSummary=$null
        foreach($phase in @('seed','resume','verify_response')){
            $dir=Join-Path $root ('processes/'+$saving+'/'+$seedLocale+'/'+$mode+'/'+$phase)
            $run=Read-Json (Join-Path $dir 'run.json')
            $locale=if($phase -eq 'resume'){if($seedLocale -eq 'ko_KR'){'en_US'}else{'ko_KR'}}else{$seedLocale}
            Assert-Condition ($run.completed -and $run.exit_code -eq 0 -and $run.source_unchanged -and $run.phase -ceq $phase -and $run.mode -ceq $mode -and $run.locale -ceq $locale -and $run.saving -ceq $saving) 'Native process boundary failed'
            Assert-Condition ($run.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $run.engine_sha256 -ceq $source.engine_sha256) 'Process engine differs'
            Assert-Condition ((Hash (Join-Path $PSScriptRoot 'run_notebook_prologue_choice_process_audit.ps1')) -ceq $run.runner_sha256) 'Process runner differs'
            foreach($pair in @(@('notebook_history_async_audit.gd','base_harness_sha256'),@('notebook_prologue_async_audit.gd','parent_harness_sha256'),@('notebook_prologue_choice_async_audit.gd','choice_harness_sha256'),@('notebook_prologue_choice_process_audit.gd','harness_sha256'),@('notebook_prologue_choice_process_audit.tscn','scene_sha256'))){
                Assert-Condition ((Hash (Join-Path $PSScriptRoot ('tests/'+$pair[0]))) -ceq $run.($pair[1])) 'Process harness differs'
            }
            Assert-Condition ($run.source_corpus.file_count -eq 265 -and @($run.source_corpus.rows).Count -eq 265 -and @($run.source_corpus.rows|Select-Object -Unique).Count -eq 265) 'Process corpus denominator'
            foreach($row in $run.source_corpus.rows){
                $columns=$row.Split("`t")
                Assert-Condition ($columns.Count -eq 2 -and $columns[0].StartsWith('scripts/') -and -not $columns[0].Contains('..')) 'Process corpus path invalid'
                Assert-Condition ((Hash (Join-Path $repo ('game/'+$columns[0]))) -ceq $columns[1]) 'Process mixed source'
            }
            $out=Join-Path $dir 'run.out.log';$err=Join-Path $dir 'run.err.log'
            Assert-Condition ((Hash $out) -ceq $run.stdout_sha256 -and (Hash $err) -ceq $run.stderr_sha256) 'Process native logs differ'
            Assert-Condition (-not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Process script failure'
            $lines=@(Get-Content -LiteralPath $out)
            Assert-Condition (@($lines|Where-Object {$_ -ceq 'PROLOGUE_CHOICE_PROCESS_SMOKE:PASS'}).Count -eq 1) 'Process PASS missing'
            $raw=@($lines|Where-Object {$_.StartsWith('PROLOGUE_CHOICE_PROCESS_AUDIT: ')})
            Assert-Condition ($raw.Count -eq 1) 'Process summary missing'
            $native=$raw[0].Substring('PROLOGUE_CHOICE_PROCESS_AUDIT: '.Length)|ConvertFrom-Json
            $summary=Read-Json (Join-Path $dir 'run.result.json')
            Assert-Condition (($native|ConvertTo-Json -Depth 16 -Compress) -ceq ($summary|ConvertTo-Json -Depth 16 -Compress)) 'Derived process summary differs'
            Assert-Condition ($summary.ok -and @($summary.errors).Count -eq 0 -and $summary.checks -gt 0 -and $summary.phase -ceq $phase -and $summary.mode -ceq $mode -and $summary.locale -ceq $locale -and $summary.saving -ceq $saving) 'Process result differs'
            if($previous){Assert-Condition ($run.profile -ceq $previous.profile -and [DateTime]$run.started_utc -gt [DateTime]$previous.finished_utc) 'Process pair disconnected'}
            if($phase -eq 'seed'){Assert-Condition ($summary.observed.cursor_phase -ceq 'selection_pending' -and $summary.observed.cursor_kind -ceq 'choice') 'Seed not selection-pending'}
            if($phase -eq 'resume'){
                Assert-Condition ($summary.observed.cursor_phase -ceq 'reading' -and $summary.observed.cursor_kind -ceq 'dialogue') 'Resume not response'
                $resumeSummary=$summary
            }
            if($phase -eq 'verify_response'){
                Assert-Condition ($summary.observed.snapshot_sha256 -ceq $resumeSummary.observed.snapshot_sha256 -and $summary.observed.cursor_token -ceq $resumeSummary.observed.cursor_token -and @($summary.observed.entry_uids).Count -eq @($resumeSummary.observed.entry_uids).Count -and @((Compare-Object $summary.observed.entry_uids $resumeSummary.observed.entry_uids)).Count -eq 0) 'Third process replayed or changed state'
            }
            $previous=$run;$processCount++;$processChecks+=$summary.checks
        }
    }
}
}
Assert-Condition ($processCount -eq 48) 'Native process denominator'
$baselinePrevious=$null
foreach($phase in @('seed','resume')){
    $dir=Join-Path $root ('archive/baseline-'+$phase)
    $run=Read-Json (Join-Path $dir 'run.json')
    Assert-Condition ($run.completed -and $run.source_unchanged -and $run.phase -ceq $phase -and $run.saving -ceq 'sync' -and $run.mode -ceq 'p3_journal') 'Baseline reproduction boundary differs'
    Assert-Condition ($run.engine_sha256 -ceq $source.engine_sha256 -and (Hash (Join-Path $PSScriptRoot 'run_notebook_prologue_choice_process_audit.ps1')) -ceq $run.runner_sha256) 'Baseline engine/runner differs'
    Assert-Condition ((Hash (Join-Path $dir 'notebook_prologue_choice_process_audit.gd')) -ceq $run.harness_sha256) 'Baseline historical harness differs'
    Assert-Condition ($run.source_corpus.file_count -eq 265 -and @($run.source_corpus.rows).Count -eq 265 -and @($run.source_corpus.rows|Select-Object -Unique).Count -eq 265) 'Baseline source denominator differs'
    foreach($row in $run.source_corpus.rows){
        $columns=$row.Split("`t")
        Assert-Condition ($columns.Count -eq 2 -and $columns[0].StartsWith('scripts/') -and -not $columns[0].Contains('..')) 'Baseline source path invalid'
        $path=switch($columns[0]){
            'scripts/prologue/prologue_controller.gd'{Join-Path $root 'archive/baseline_controller.gd'}
            'scripts/systems/prologue_save_candidate.gd'{Join-Path $root 'archive/prologue_save_candidate.gd'}
            default{Join-Path $repo ('game/'+$columns[0])}
        }
        Assert-Condition ((Hash $path) -ceq $columns[1]) 'Baseline source changed'
        $changed=@($source.files|Where-Object {$_.path -ceq ('game/'+$columns[0])})
        if($changed.Count){Assert-Condition ($columns[1] -ceq $changed[0].baseline_sha256) 'Baseline original product fingerprint differs'}
    }
    $out=Join-Path $dir 'run.out.log';$err=Join-Path $dir 'run.err.log'
    Assert-Condition ((Hash $out) -ceq $run.stdout_sha256 -and (Hash $err) -ceq $run.stderr_sha256) 'Baseline log differs'
    Assert-Condition (-not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Baseline failure is not a product assertion'
    $raw=@(Get-Content -LiteralPath $out|Where-Object {$_.StartsWith('PROLOGUE_CHOICE_PROCESS_AUDIT: ')})
    Assert-Condition ($raw.Count -eq 1) 'Baseline result missing'
    $summary=$raw[0].Substring('PROLOGUE_CHOICE_PROCESS_AUDIT: '.Length)|ConvertFrom-Json
    if($phase -eq 'seed'){
        Assert-Condition ($run.exit_code -eq 0 -and $summary.ok -and $summary.observed.cursor_phase -ceq 'selection_pending') 'Baseline seed failed'
    }else{
        Assert-Condition ($run.exit_code -ne 0 -and -not $summary.ok -and $summary.observed.diagnostic_error -ceq 'NB_PRESENTATION_CONFLICT' -and $summary.observed.cursor_phase -ceq 'selection_pending') 'Original conflict reproduction reclassified'
        Assert-Condition ($run.profile -ceq $baselinePrevious.profile -and [DateTime]$run.started_utc -gt [DateTime]$baselinePrevious.finished_utc) 'Baseline process pair disconnected'
    }
    $baselinePrevious=$run
}
$negativeCount=0
if($SelfTest){
    foreach($defect in @('missing_log','log_hash','native_exit','case_count','duplicate_case','mixed_source','process_profile','process_state')){
        $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-choice-evidence-negative-'+[guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $root -Destination $copy -Recurse
        $out=Join-Path $copy 'focused-final/focused.out.log'
        $receiptPath=Join-Path $copy 'focused-final/focused.run.json'
        if($defect -eq 'missing_log'){Remove-Item -LiteralPath $out}
        elseif($defect -eq 'log_hash'){[IO.File]::AppendAllText($out,'changed')}
        else{
            if($defect -in @('process_profile','process_state')){
                $receiptPath=Join-Path $copy 'processes/async/ko_KR/p3_journal/verify_response/run.json'
                $out=Join-Path $copy 'processes/async/ko_KR/p3_journal/verify_response/run.out.log'
            }
            $receipt=Read-Json $receiptPath
            if($defect -eq 'native_exit'){$receipt.exit_code=1}
            elseif($defect -eq 'mixed_source'){$receipt.source_corpus.rows[0]='scripts/autoload/event_manager.gd'+"`t"+('0'*64)}
            elseif($defect -eq 'process_profile'){$receipt.profile+='-disconnected'}
            elseif($defect -eq 'process_state'){
                $summaryPath=Join-Path $copy 'processes/async/ko_KR/p3_journal/verify_response/run.result.json'
                $mutated=Read-Json $summaryPath
                $mutated.observed.snapshot_sha256='0'*64
                [IO.File]::WriteAllText($summaryPath,($mutated|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
                $lines=@(Get-Content -LiteralPath $out|ForEach-Object {if($_.StartsWith('PROLOGUE_CHOICE_PROCESS_AUDIT: ')){'PROLOGUE_CHOICE_PROCESS_AUDIT: '+($mutated|ConvertTo-Json -Depth 16 -Compress)}else{$_}})
                [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false))
                $receipt.stdout_sha256=Hash $out
            }
            else{
                $mutated=Read-Json (Join-Path $copy 'focused-final/focused.result.json')
                if($defect -eq 'case_count'){$mutated.cases=@($mutated.cases|Select-Object -Skip 1)}else{$mutated.cases[1]=$mutated.cases[0]}
                [IO.File]::WriteAllText((Join-Path $copy 'focused-final/focused.result.json'),($mutated|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
                $lines=@(Get-Content -LiteralPath $out|ForEach-Object {if($_.StartsWith('PROLOGUE_CHOICE_ASYNC_AUDIT: ')){'PROLOGUE_CHOICE_ASYNC_AUDIT: '+($mutated|ConvertTo-Json -Depth 16 -Compress)}else{$_}})
                [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false))
                $receipt.stdout_sha256=Hash $out
            }
            [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
            $changed=Read-Json (Join-Path $copy 'manifest.json')
            foreach($row in $changed.files){$p=Join-Path $copy $row.path;$row.sha256=Hash $p;$row.bytes=(Get-Item -LiteralPath $p).Length}
            [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($changed|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        }
        $rejected=$false
        try{& $PSCommandPath -EvidencePath $copy|Out-Null}catch{$rejected=$true}
        Assert-Condition $rejected ('Negative accepted '+$defect)
        $negativeCount++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;focused_cases=152;native_runs=8;choice_processes=$processCount;process_assertions=$processChecks}
