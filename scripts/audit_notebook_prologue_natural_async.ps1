param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
$hashes=@{}
function Check([bool]$value,[string]$label){if(-not $value){throw $label};$script:checks++}
function Json([string]$path){Get-Content -LiteralPath $path -Raw | ConvertFrom-Json}
function Hash([string]$path){if(-not $script:hashes.ContainsKey($path)){$script:hashes[$path]=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()};$script:hashes[$path]}
function Equal($a,$b){($a | ConvertTo-Json -Depth 40 -Compress) -ceq ($b | ConvertTo-Json -Depth 40 -Compress)}
function Summary([string]$path,[string]$prefix){
    $rows=@(Get-Content -LiteralPath $path | Where-Object {$_.StartsWith($prefix)})
    Check ($rows.Count -eq 1) ('Ambiguous result '+$path)
    $rows[0].Substring($prefix.Length) | ConvertFrom-Json
}
$manifest=Json (Join-Path $root 'manifest.json')
$actual=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')} | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
Check (@($manifest.files.path | Select-Object -Unique).Count -eq @($manifest.files).Count -and $actual.Count -eq @($manifest.files).Count -and @(Compare-Object $actual @($manifest.files.path)).Count -eq 0) 'Manifest completeness'
foreach($row in $manifest.files){
    Check ($row.path -is [string] -and -not $row.path.Contains('..') -and -not $row.path.Contains('\')) 'Evidence path invalid'
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Check ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)) 'Evidence escapes or missing'
    Check ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Changed evidence '+$row.path)
}
$source=Json (Join-Path $root 'source.json')
Check ($source.head -ceq '22c84f30f24f3e1c46055d45e06c5fd85eb00ae5' -and @($source.files).Count -eq 1 -and $source.files[0].path -ceq 'game/scripts/prologue/prologue_controller.gd') 'Source baseline/denominator'
Check ((Hash (Join-Path $repo $source.files[0].path)) -ceq $source.files[0].candidate_sha256) 'Final product differs'
function Corpus($receipt,[string]$version='final'){
    Check ($receipt.source_unchanged -and $receipt.source_corpus.file_count -eq 265 -and @($receipt.source_corpus.rows).Count -eq 265) 'Corpus denominator/mutation'
    $paths=@()
    foreach($row in $receipt.source_corpus.rows){
        $parts=$row.Split("`t")
        Check ($parts.Count -eq 2 -and $parts[0].StartsWith('scripts/') -and -not $parts[0].Contains('..') -and $parts[1] -cmatch '^[0-9a-f]{64}$') 'Invalid corpus row'
        $paths+=$parts[0]
        $path=if($parts[0] -ceq 'scripts/prologue/prologue_controller.gd' -and $version -ne 'final'){Join-Path $root ('archive/'+$version+'_controller.gd')}else{Join-Path $repo ('game/'+$parts[0])}
        Check ((Hash $path) -ceq $parts[1]) ('Mixed source '+$parts[0])
    }
    Check (@($paths | Select-Object -Unique).Count -eq 265) 'Duplicate product path'
    $all=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/scripts') -Filter '*.gd' -File -Recurse | ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')})
    Check ($all.Count -eq 265 -and @(Compare-Object $all $paths).Count -eq 0) 'Missing product source'
}
function Native([string]$dir,[string]$stem,[string]$runner,[string]$marker,[int]$exit=0,[string]$version='final'){
    $path=Join-Path $root ($dir+'/'+$stem)
    $receipt=Json ($path+$(if($stem -eq 'run'){'.json'}else{'.run.json'}))
    Check ($receipt.completed -and $receipt.exit_code -eq $exit -and [DateTime]$receipt.finished_utc -gt [DateTime]$receipt.started_utc) ('Native result '+$dir)
    Check ($receipt.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $receipt.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine fingerprint'
    Check ((Hash (Join-Path $PSScriptRoot $runner)) -ceq $receipt.runner_sha256) ('Runner fingerprint '+$runner)
    Corpus $receipt $version
    Check ((Hash ($path+'.out.log')) -ceq $receipt.stdout_sha256 -and (Hash ($path+'.err.log')) -ceq $receipt.stderr_sha256) 'Native logs changed'
    Check (-not (Select-String -LiteralPath ($path+'.out.log'),($path+'.err.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Script failure'
    $markers=@(Get-Content -LiteralPath ($path+'.out.log') | Where-Object {if($marker.EndsWith(' ')){$_.StartsWith($marker)}else{$_ -ceq $marker}})
    Check ($markers.Count -eq 1) ('Terminal marker '+$dir)
    if($receipt.harnesses){
        foreach($row in $receipt.harnesses){
            $harness=Join-Path $root ($dir+'/'+$row.name)
            Check ((Hash $harness) -ceq $row.sha256) ('Executed harness '+$row.name)
        }
    }
    $suiteName=switch($runner){
        'run_notebook_prologue_choice_async_audit.ps1'{'notebook_prologue_choice_async_audit'}
        'run_notebook_prologue_surface_async_audit.ps1'{'notebook_prologue_surface_async_audit'}
        'run_notebook_history_async_audit.ps1'{'notebook_history_async_audit'}
    }
    if($suiteName){
        foreach($pair in @(@('base_harness_sha256','notebook_history_async_audit.gd'),@('parent_harness_sha256','notebook_prologue_async_audit.gd'),@('harness_sha256',($suiteName+'.gd')),@('scene_sha256',($suiteName+'.tscn')))){
            if($receipt.($pair[0])){Check ((Hash (Join-Path $PSScriptRoot ('tests/'+$pair[1]))) -ceq $receipt.($pair[0])) ('Regression harness '+$pair[1])}
        }
    }
    $receipt
}
$windows=@('brush','spanner','cloth','water','bird','promotion','ack')
$routes=@('p2_complete','room_intro','p3_books','p3_drop','p3b_labels','p4_father','p4_tenure','p5_weather')
$stale=@('locale','scope','generation','progress','notes','inventory','window','service','active')
$retries=@('locale','scope','generation','progress','notes','inventory','window','requests')
$run=Native 'final' 'focused' 'run_notebook_prologue_natural_async_audit.ps1' 'PROLOGUE_NATURAL_ASYNC_SMOKE:PASS'
$result=Summary (Join-Path $root 'final/focused.out.log') 'PROLOGUE_NATURAL_ASYNC_AUDIT: '
Check (Equal $result (Json (Join-Path $root 'final/focused.result.json'))) 'Final result differs from raw'
Check ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 1256 -and $result.required_cases -eq 64 -and @($result.cases).Count -eq 64) 'Final denominator'
foreach($locale in @('ko_KR','en_US')){
    foreach($kind in @('window','route','stale_action','stale_retry')){
        $names=switch($kind){'window'{$windows}'route'{$routes}'stale_action'{$stale}'stale_retry'{$retries}}
        foreach($name in $names){
            $rows=@($result.cases | Where-Object {($(if($_.kind){$_.kind}else{'window'})) -ceq $kind -and $_.locale -ceq $locale -and $_.scenario -ceq $name})
            Check ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate final case '+$kind+':'+$name+':'+$locale)
            if($kind -eq 'window'){
                Check ($rows[0].tool_actions -eq 1) 'Action/retry reexecuted tool'
                Check ($rows[0].worker_kind -ceq $(if($name -in @('brush','spanner','bird')){'line'}else{'action'})) 'Wrong atomic worker kind'
            }
        }
    }
}
foreach($pair in @(@('baseline',14,14,'baseline'),@('diagnostic',64,2,'initial'))){
    $receipt=Native $pair[0] 'focused' 'run_notebook_prologue_natural_async_audit.ps1' 'PROLOGUE_NATURAL_ASYNC_SMOKE:FAIL' 1 $pair[3]
    $failed=Summary (Join-Path $root ($pair[0]+'/focused.out.log')) 'PROLOGUE_NATURAL_ASYNC_AUDIT: '
    Check (Equal $failed (Json (Join-Path $root ($pair[0]+'/focused.result.json')))) 'Historical result differs'
    Check (-not $failed.ok -and $failed.required_cases -eq $pair[1] -and @($failed.cases).Count -eq $pair[1] -and @($failed.cases | Where-Object {-not $_.passed}).Count -eq $pair[2]) 'Historical failure reclassified'
    if($pair[0] -eq 'diagnostic'){
        Check (@($failed.errors).Count -eq 4 -and @($failed.cases | Where-Object {-not $_.passed -and ($_.kind -cne 'stale_retry' -or $_.scenario -cne 'requests')}).Count -eq 0) 'Unexpected retry failure'
    }else{Check ('brush spread and hint retained' -in $failed.errors -and 'special line recorded once with physical state' -in $failed.errors) 'Baseline lacks behavioral failure'}
}
$choice=Native 'regressions/choice' 'focused' 'run_notebook_prologue_choice_async_audit.ps1' 'PROLOGUE_CHOICE_ASYNC_SMOKE:PASS'
$choiceResult=Summary (Join-Path $root 'regressions/choice/focused.out.log') 'PROLOGUE_CHOICE_ASYNC_AUDIT: '
Check ($choiceResult.ok -and $choiceResult.checks -eq 2128 -and $choiceResult.required_cases -eq 152 -and @($choiceResult.cases).Count -eq 152 -and @($choiceResult.cases | Where-Object {-not $_.passed}).Count -eq 0) 'Choice regression'
$prologue=Native 'regressions/prologue' 'run' 'run_notebook_prologue_compatibility.ps1' 'NOTEBOOK_PROLOGUE_SMOKE: PASS '
$branches=Summary (Join-Path $root 'regressions/prologue/run.out.log') 'NOTEBOOK_PROLOGUE_BRANCH_AUDIT: '
Check ($branches.required_count -eq 232 -and $branches.observed_count -eq 232 -and @($branches.not_covered).Count -eq 0 -and @($branches.unmapped).Count -eq 0 -and @($branches.errors).Count -eq 0) 'Sync branches'
$cursor=@()
foreach($pair in @(@('cursor_seed','seed',66),@('cursor_resume','resume',26),@('cursor_completed','completed',16))){
    $cursor+=Native ('regressions/'+$pair[0]) 'run' 'run_notebook_prologue_compatibility.ps1' 'NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'
    Check (@(Get-Content (Join-Path $root ('regressions/'+$pair[0]+'/run.out.log')) | Where-Object {$_ -ceq ('NOTEBOOK_PROLOGUE_PRESENTATION_CHECKS: '+$pair[1]+' '+$pair[2])}).Count -eq 1) 'Cursor checks'
}
Check ($cursor[0].profile -ceq $cursor[1].profile -and $cursor[1].profile -ceq $cursor[2].profile -and [DateTime]$cursor[1].started_utc -gt [DateTime]$cursor[0].finished_utc -and [DateTime]$cursor[2].started_utc -gt [DateTime]$cursor[1].finished_utc) 'Cursor disconnected process/profile'
foreach($pair in @(@('migration','NOTEBOOK_MIGRATION_SMOKE: PASS'),@('host','NOTEBOOK_HOST_SMOKE: PASS'))){$receipt=Native ('regressions/'+$pair[0]) $pair[0] 'run_notebook_save_preflight_audit.ps1' $pair[1]}
foreach($pair in @(@('migration','NOTEBOOK_SAVE_SAFETY_CHECKS: 381'),@('host','NOTEBOOK_HOST_CHECKS: 548'),@('host','NOTEBOOK_ASYNC_SAVE_CHECKS: 342'))){Check (@(Get-Content (Join-Path $root ('regressions/'+$pair[0]+'/'+$pair[0]+'.out.log')) | Where-Object {$_ -ceq $pair[1]}).Count -eq 1) 'Safety/host checks'}
$history=Native 'regressions/history' 'focused' 'run_notebook_history_async_audit.ps1' 'HISTORY_ASYNC_SMOKE:PASS'
$historyResult=Summary (Join-Path $root 'regressions/history/focused.out.log') 'HISTORY_ASYNC_AUDIT: '
Check ($historyResult.ok -and $historyResult.checks -eq 870 -and @($historyResult.cases).Count -eq 72 -and @($historyResult.errors).Count -eq 0) 'Common async regression'
$surface=Native 'regressions/surfaces' 'focused' 'run_notebook_prologue_surface_async_audit.ps1' 'PROLOGUE_SURFACE_ASYNC_SMOKE:PASS'
$surfaceResult=Summary (Join-Path $root 'regressions/surfaces/focused.out.log') 'PROLOGUE_SURFACE_ASYNC_AUDIT: '
Check ($surfaceResult.ok -and $surfaceResult.checks -eq 40878 -and @($surfaceResult.cases).Count -eq 54 -and @($surfaceResult.errors).Count -eq 0) 'Surface regression'
$processChecks=0
foreach($seedLocale in @('ko_KR','en_US')){
    foreach($mode in @('brush','water')){
        $previous=$null
        $previousReceipt=$null
        foreach($phase in @('seed','resume','verify')){
            $dir='processes/'+$seedLocale+'/'+$mode+'/'+$phase
            $receipt=Native $dir 'run' 'run_notebook_prologue_natural_process_audit.ps1' 'PROLOGUE_NATURAL_PROCESS_SMOKE:PASS'
            $value=Summary (Join-Path $root ($dir+'/run.out.log')) 'PROLOGUE_NATURAL_PROCESS_AUDIT: '
            Check (Equal $value (Json (Join-Path $root ($dir+'/run.result.json')))) 'Process result differs'
            $locale=if($phase -eq 'resume'){if($seedLocale -ceq 'ko_KR'){'en_US'}else{'ko_KR'}}else{$seedLocale}
            Check ($receipt.phase -ceq $phase -and $receipt.mode -ceq $mode -and $receipt.locale -ceq $locale -and $value.ok -and @($value.errors).Count -eq 0) 'Process coordinates/result'
            if($null -ne $previous){
                Check ($receipt.profile -ceq $previousReceipt.profile -and [DateTime]$receipt.started_utc -gt [DateTime]$previousReceipt.finished_utc) 'Process discontinuity'
                Check (Equal $previous.saved_entries $value.prior_entries) 'Next process did not load exact prior entries'
                foreach($entry in $previous.saved_entries){
                    $rows=@($value.saved_entries | Where-Object {$_.entry_uid -ceq $entry.entry_uid})
                    Check ($rows.Count -eq 1 -and (Equal $entry $rows[0])) 'Old process UID/original changed'
                }
            }
            $processChecks+=$value.checks
            $previous=$value
            $previousReceipt=$receipt
        }
    }
}
$negativeCount=0
if($SelfTest){
    foreach($defect in @('log_hash','native_exit','duplicate_case','mixed_source','profile','order')){
        $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-natural-negative-'+[guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $root -Destination $copy -Recurse
        if($defect -eq 'log_hash'){[IO.File]::AppendAllText((Join-Path $copy 'final/focused.out.log'),'changed')}
        else{
            $path=Join-Path $copy 'final/focused.run.json'
            if($defect -in @('profile','order')){$path=Join-Path $copy 'processes/ko_KR/brush/resume/run.json'}
            $receipt=Json $path
            switch($defect){
                'native_exit'{$receipt.exit_code=1}
                'mixed_source'{$receipt.source_corpus.rows[0]='scripts/autoload/event_manager.gd'+"`t"+('0'*64)}
                'profile'{$receipt.profile+='-different'}
                'order'{$receipt.started_utc='2000-01-01T00:00:00Z'}
                'duplicate_case'{
                    $resultPath=Join-Path $copy 'final/focused.result.json'
                    $changed=Json $resultPath
                    $changed.cases[1]=$changed.cases[0]
                    [IO.File]::WriteAllText($resultPath,($changed | ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
                    $out=Join-Path $copy 'final/focused.out.log'
                    $lines=@(Get-Content -LiteralPath $out | ForEach-Object {if($_.StartsWith('PROLOGUE_NATURAL_ASYNC_AUDIT: ')){'PROLOGUE_NATURAL_ASYNC_AUDIT: '+($changed | ConvertTo-Json -Depth 40 -Compress)}else{$_}})
                    [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false))
                    $receipt.stdout_sha256=Hash $out
                }
            }
            [IO.File]::WriteAllText($path,($receipt | ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
            $updated=Json (Join-Path $copy 'manifest.json')
            foreach($row in $updated.files){$file=Join-Path $copy $row.path;$row.sha256=Hash $file;$row.bytes=(Get-Item -LiteralPath $file).Length}
            [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($updated | ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
        }
        $rejected=$false
        try{& $PSCommandPath -EvidencePath $copy | Out-Null}catch{$rejected=$true}
        Check $rejected ('Negative accepted '+$defect)
        $negativeCount++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;natural_cases=64;natural_processes=12;process_assertions=$processChecks;final_regression_runs=9}
