param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
$hashCache=@{}
function Check([bool]$Value,[string]$Label){if(-not $Value){throw $Label};$script:checks++}
function Hash([string]$Path){
    $key=[IO.Path]::GetFullPath($Path)
    if(-not $script:hashCache.ContainsKey($key)){$script:hashCache[$key]=(Get-FileHash -LiteralPath $key).Hash.ToLowerInvariant()}
    $script:hashCache[$key]
}
function Json([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Equal($Left,$Right){($Left|ConvertTo-Json -Depth 30 -Compress) -ceq ($Right|ConvertTo-Json -Depth 30 -Compress)}
function Summary([string]$Out,[string]$Prefix){
    $rows=@(Get-Content -LiteralPath $Out|Where-Object {$_.StartsWith($Prefix)})
    Check ($rows.Count -eq 1) ('Ambiguous summary '+$Prefix)
    $rows[0].Substring($Prefix.Length)|ConvertFrom-Json
}
$manifest=Json (Join-Path $root 'manifest.json')
$actual=@(Get-ChildItem -LiteralPath $root -File -Recurse|Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')}|ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
Check (@($manifest.files).Count -ge 30 -and @($manifest.files.path|Select-Object -Unique).Count -eq @($manifest.files).Count) 'Manifest denominator/duplicate'
Check ($actual.Count -eq @($manifest.files).Count -and @(Compare-Object $actual @($manifest.files.path)).Count -eq 0) 'Unlisted/missing evidence'
foreach($row in $manifest.files){
    Check ($row.path -is [string] -and -not $row.path.Contains('\') -and -not $row.path.Contains('..')) 'Invalid relative evidence path'
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Check ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)) 'Escaping/missing evidence'
    Check ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Changed evidence '+$row.path)
}
$source=Json (Join-Path $root 'source.json')
Check (@($source.files).Count -eq 1 -and $source.files[0].path -ceq 'game/scripts/prologue/prologue_controller.gd') 'Product denominator'
Check ((Hash (Join-Path $repo $source.files[0].path)) -ceq $source.files[0].candidate_sha256) 'Candidate source differs'
function Corpus($Run,[bool]$Historical=$false){
    Check ($Run.source_unchanged -and $Run.source_corpus.file_count -eq 265 -and @($Run.source_corpus.rows).Count -eq 265) 'Corpus denominator/mutation'
    $paths=@()
    foreach($row in $Run.source_corpus.rows){
        $parts=$row.Split("`t")
        Check ($parts.Count -eq 2 -and $parts[0].StartsWith('scripts/') -and -not $parts[0].Contains('..') -and $parts[1] -cmatch '^[0-9a-f]{64}$') 'Invalid corpus row'
        $paths+=$parts[0]
        $file=if($Historical -and $parts[0] -ceq 'scripts/prologue/prologue_controller.gd'){Join-Path $root 'archive/prologue_controller.gd'}else{Join-Path $repo ('game/'+$parts[0])}
        Check ((Hash $file) -ceq $parts[1]) ('Mixed source '+$parts[0])
    }
    Check (@($paths|Select-Object -Unique).Count -eq 265) 'Duplicate source path'
    $all=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/scripts') -Filter '*.gd' -File -Recurse|ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')})
    Check ($all.Count -eq 265 -and @(Compare-Object $all $paths).Count -eq 0) 'Missing product source'
}
function Native([string]$Dir,[string]$Name,[string]$Runner,[string]$Marker,[bool]$Failed=$false,[bool]$Historical=$false){
    $base=Join-Path $root ($Dir+'/'+$Name)
    $receipt=Json ($base+$(if($Name -eq 'run'){'.json'}else{'.run.json'}))
    Check ($receipt.completed -and ($receipt.exit_code -ne 0) -eq $Failed -and [DateTime]$receipt.finished_utc -gt [DateTime]$receipt.started_utc) ('Native boundary '+$Dir)
    Check ($receipt.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $receipt.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine fingerprint'
    $runnerPath=if($Historical -and $Runner -ceq 'run_notebook_prologue_surface_async_audit.ps1'){Join-Path $root ('archive/'+$Runner)}else{Join-Path $PSScriptRoot $Runner}
    Check ((Hash $runnerPath) -ceq $receipt.runner_sha256) 'Runner fingerprint'
    Corpus $receipt $Historical
    $out=$base+'.out.log';$err=$base+'.err.log'
    Check ((Hash $out) -ceq $receipt.stdout_sha256 -and (Hash $err) -ceq $receipt.stderr_sha256) 'Native logs changed'
    Check (-not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Script failure'
    $matches=if($Marker.EndsWith(' ')){@(Get-Content -LiteralPath $out|Where-Object {$_.StartsWith($Marker)})}else{@(Get-Content -LiteralPath $out|Where-Object {$_ -ceq $Marker})}
    Check ($matches.Count -eq 1) ('Exact terminal marker '+$Dir)
    $receipt
}
function Harness($Run,[string]$Name,[string]$Field,[string]$Path=''){
    if(-not $Path){$Path=Join-Path $PSScriptRoot ('tests/'+$Name)}
    Check ((Hash $Path) -ceq $Run.$Field) ('Harness fingerprint '+$Name)
}
$run=Native 'focused-final' 'focused' 'run_notebook_prologue_surface_async_audit.ps1' 'PROLOGUE_SURFACE_ASYNC_SMOKE:PASS'
foreach($pair in @(@('notebook_history_async_audit.gd','base_harness_sha256'),@('notebook_prologue_async_audit.gd','parent_harness_sha256'),@('notebook_prologue_surface_async_audit.gd','harness_sha256'),@('notebook_prologue_surface_async_audit.tscn','scene_sha256'))){Harness $run $pair[0] $pair[1]}
$final=Summary (Join-Path $root 'focused-final/focused.out.log') 'PROLOGUE_SURFACE_ASYNC_AUDIT: '
Check (Equal $final (Json (Join-Path $root 'focused-final/focused.result.json'))) 'Derived result differs'
Check ($final.ok -and @($final.errors).Count -eq 0 -and $final.checks -eq 40878 -and $final.required_cases -eq 54 -and @($final.cases).Count -eq 54 -and @($final.timings).Count -eq 8) 'Focused denominator/result'
$scenarios=@('success','promotion','ack','request_changed','active_changed','generation','scope','locale','service','progress','notes','inventory','window','dialogue','modal','notebook','stale_note','unknown_content')
$extras=@('repaint','new_attempt','p2_plain_tools','pending_repaint','queued_free')
foreach($locale in @('ko_KR','en_US')){
    foreach($kind in @('surface','extra')){
        foreach($scenario in $(if($kind -eq 'surface'){$scenarios}else{$extras})){
            $rows=@($final.cases|Where-Object {$_.kind -ceq $kind -and $_.locale -ceq $locale -and $_.scenario -ceq $scenario})
            Check ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate condition '+$kind+':'+$scenario+':'+$locale)
        }
    }
    foreach($fixture in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')){
        $rows=@($final.cases|Where-Object {$_.kind -ceq 'large' -and $_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        $times=@($final.timings|Where-Object {$_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        Check ($rows.Count -eq 1 -and $rows[0].passed -and $times.Count -eq 1 -and $times[0].worker_frames -gt 0 -and $times[0].begin_ms -gt 0 -and $times[0].total_ms -gt $times[0].begin_ms) 'Large fixture/timing'
    }
}
foreach($dir in @('focused','diagnostic')){
    $failed=Native $dir 'focused' 'run_notebook_prologue_surface_async_audit.ps1' 'PROLOGUE_SURFACE_ASYNC_SMOKE:FAIL' $true $true
    Harness $failed 'notebook_history_async_audit.gd' 'base_harness_sha256'
    Harness $failed 'notebook_prologue_async_audit.gd' 'parent_harness_sha256'
    Harness $failed 'notebook_prologue_surface_async_audit.tscn' 'scene_sha256'
    Harness $failed 'notebook_prologue_surface_async_audit.gd' 'harness_sha256' (Join-Path $root ($dir+'/notebook_prologue_surface_async_audit.gd'))
    $result=Summary (Join-Path $root ($dir+'/focused.out.log')) 'PROLOGUE_SURFACE_ASYNC_AUDIT: '
    $bad=@($result.cases|Where-Object {-not $_.passed})
    Check (-not $result.ok -and $result.required_cases -eq 52 -and @($result.cases).Count -eq 52 -and $bad.Count -eq $(if($dir -eq 'focused'){3}else{2})) 'Historical failure reclassified'
    foreach($row in $bad){Check (($row.kind -ceq 'large' -and $row.fixture -ceq 'NB-PERF-P2001') -or ($dir -eq 'focused' -and $row.kind -ceq 'surface' -and $row.scenario -ceq 'success' -and $row.locale -ceq 'en_US')) 'Unexpected historical failure'}
}
$old=Native 'archive/pre-isolation-focus' 'focused' 'run_notebook_prologue_surface_async_audit.ps1' 'PROLOGUE_SURFACE_ASYNC_SMOKE:PASS' $false $true
Harness $old 'notebook_prologue_surface_async_audit.gd' 'harness_sha256' (Join-Path $root 'archive/pre-isolation-focus/notebook_prologue_surface_async_audit.gd')
$oldResult=Summary (Join-Path $root 'archive/pre-isolation-focus/focused.out.log') 'PROLOGUE_SURFACE_ASYNC_AUDIT: '
Check ($oldResult.ok -and $oldResult.checks -eq 40860 -and $oldResult.required_cases -eq 52 -and @($oldResult.cases).Count -eq 52) 'Pre-isolation result is historical only'
$badPath=Join-Path $root 'archive/pre-isolation-choice/focused.run.json'
$bad=Json $badPath
Check ($bad.completed -and $bad.exit_code -ne 0 -and $bad.engine_sha256 -ceq $source.engine_sha256) 'Pre-isolation choice failure reclassified'
Corpus $bad $true
Check ((Hash (Join-Path $PSScriptRoot 'run_notebook_prologue_choice_async_audit.ps1')) -ceq $bad.runner_sha256) 'Pre-isolation choice runner'
foreach($pair in @(@('notebook_history_async_audit.gd','base_harness_sha256'),@('notebook_prologue_async_audit.gd','parent_harness_sha256'),@('notebook_prologue_choice_async_audit.gd','harness_sha256'),@('notebook_prologue_choice_async_audit.tscn','scene_sha256'))){Harness $bad $pair[0] $pair[1]}
$badOut=Join-Path $root 'archive/pre-isolation-choice/focused.out.log';$badErr=Join-Path $root 'archive/pre-isolation-choice/focused.err.log'
Check ((Hash $badOut) -ceq $bad.stdout_sha256 -and (Hash $badErr) -ceq $bad.stderr_sha256 -and (Select-String -LiteralPath $badErr -Pattern 'SCRIPT ERROR' -Quiet)) 'Pre-isolation script failure must remain failure'
$badResult=Summary $badOut 'PROLOGUE_CHOICE_ASYNC_AUDIT: '
Check (-not $badResult.ok -and @($badResult.errors).Count -gt 0) 'Pre-isolation choice summary must fail'
$choice=Native 'choice' 'focused' 'run_notebook_prologue_choice_async_audit.ps1' 'PROLOGUE_CHOICE_ASYNC_SMOKE:PASS'
foreach($pair in @(@('notebook_history_async_audit.gd','base_harness_sha256'),@('notebook_prologue_async_audit.gd','parent_harness_sha256'),@('notebook_prologue_choice_async_audit.gd','harness_sha256'),@('notebook_prologue_choice_async_audit.tscn','scene_sha256'))){Harness $choice $pair[0] $pair[1]}
$result=Summary (Join-Path $root 'choice/focused.out.log') 'PROLOGUE_CHOICE_ASYNC_AUDIT: '
Check (Equal $result (Json (Join-Path $root 'choice/focused.result.json'))) 'Derived choice result differs'
Check ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 2128 -and $result.required_cases -eq 152 -and @($result.cases).Count -eq 152 -and @($result.timings).Count -eq 8) 'Choice regression'
Check (@($result.cases|Where-Object {-not $_.passed}).Count -eq 0) 'Choice case failed'
$caseIds=@($result.cases|ForEach-Object {$_.kind+'|'+$_.locale+'|'+$_.mode+'|'+$_.scenario+'|'+$_.phase+'|'+$_.fixture})
Check (@($caseIds|Select-Object -Unique).Count -eq 152) 'Duplicate choice condition'
$prologue=Native 'prologue' 'run' 'run_notebook_prologue_compatibility.ps1' 'NOTEBOOK_PROLOGUE_SMOKE: PASS '
$branches=Summary (Join-Path $root 'prologue/run.out.log') 'NOTEBOOK_PROLOGUE_BRANCH_AUDIT: '
Check ($branches.required_count -eq 232 -and $branches.observed_count -ge 232 -and @($branches.not_covered).Count -eq 0 -and @($branches.unmapped).Count -eq 0 -and @($branches.errors).Count -eq 0) 'Synchronous branch regression'
$cursor=@()
foreach($pair in @(@('cursor_seed','seed',66),@('cursor_resume','resume',26),@('cursor_completed','completed',16))){
    $receipt=Native $pair[0] 'run' 'run_notebook_prologue_compatibility.ps1' 'NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'
    $cursor+=$receipt
    Check (@(Get-Content (Join-Path $root ($pair[0]+'/run.out.log'))|Where-Object {$_ -ceq ('NOTEBOOK_PROLOGUE_PRESENTATION_CHECKS: '+$pair[1]+' '+$pair[2])}).Count -eq 1) 'Cursor assertions'
}
Check ($cursor[0].profile -ceq $cursor[1].profile -and $cursor[1].profile -ceq $cursor[2].profile -and [DateTime]$cursor[1].started_utc -gt [DateTime]$cursor[0].finished_utc -and [DateTime]$cursor[2].started_utc -gt [DateTime]$cursor[1].finished_utc) 'Cursor process boundary'
foreach($pair in @(@('migration','NOTEBOOK_MIGRATION_SMOKE: PASS'),@('host','NOTEBOOK_HOST_SMOKE: PASS'))){$receipt=Native $pair[0] $pair[0] 'run_notebook_save_preflight_audit.ps1' $pair[1]}
Check (@(Get-Content (Join-Path $root 'migration/migration.out.log')|Where-Object {$_ -ceq 'NOTEBOOK_SAVE_SAFETY_CHECKS: 381'}).Count -eq 1) 'Save safety assertions'
Check (@(Get-Content (Join-Path $root 'host/host.out.log')|Where-Object {$_ -ceq 'NOTEBOOK_HOST_CHECKS: 548'}).Count -eq 1) 'Host assertions'
Check (@(Get-Content (Join-Path $root 'host/host.out.log')|Where-Object {$_ -ceq 'NOTEBOOK_ASYNC_SAVE_CHECKS: 342'}).Count -eq 1) 'Internal async assertions'
$history=Native 'history' 'focused' 'run_notebook_history_async_audit.ps1' 'HISTORY_ASYNC_SMOKE:PASS'
Harness $history 'notebook_history_async_audit.gd' 'harness_sha256'
$result=Summary (Join-Path $root 'history/focused.out.log') 'HISTORY_ASYNC_AUDIT: '
Check (Equal $result (Json (Join-Path $root 'history/focused.result.json'))) 'Derived history result differs'
Check ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 870 -and @($result.cases).Count -eq 72 -and @($result.cases|Where-Object {-not $_.passed}).Count -eq 0) 'History regression'
$negativeCount=0
if($SelfTest){
    foreach($defect in @('missing_log','log_hash','native_exit','case_count','duplicate_case','mixed_source','cursor_profile','cursor_order')){
        $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-surface-evidence-negative-'+[guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $root -Destination $copy -Recurse
        $out=Join-Path $copy 'focused-final/focused.out.log'
        $receiptPath=Join-Path $copy 'focused-final/focused.run.json'
        if($defect -eq 'missing_log'){
            Check ([IO.Path]::GetFullPath($out).StartsWith($copy+'\',[StringComparison]::OrdinalIgnoreCase)) 'Negative delete outside owned path'
            Remove-Item -LiteralPath $out
        }elseif($defect -eq 'log_hash'){[IO.File]::AppendAllText($out,'changed')}
        else{
            if($defect -in @('cursor_profile','cursor_order')){$receiptPath=Join-Path $copy 'cursor_resume/run.json'}
            $receipt=Json $receiptPath
            switch($defect){
                'native_exit'{$receipt.exit_code=1}
                'mixed_source'{$receipt.source_corpus.rows[0]='scripts/autoload/event_manager.gd'+"`t"+('0'*64)}
                'cursor_profile'{$receipt.profile+='-disconnected'}
                'cursor_order'{$receipt.started_utc='2000-01-01T00:00:00Z'}
                default{
                    $path=Join-Path $copy 'focused-final/focused.result.json'
                    $mutated=Json $path
                    if($defect -eq 'case_count'){$mutated.cases=@($mutated.cases|Select-Object -Skip 1)}else{$mutated.cases[1]=$mutated.cases[0]}
                    [IO.File]::WriteAllText($path,($mutated|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
                    $lines=@(Get-Content -LiteralPath $out|ForEach-Object {if($_.StartsWith('PROLOGUE_SURFACE_ASYNC_AUDIT: ')){'PROLOGUE_SURFACE_ASYNC_AUDIT: '+($mutated|ConvertTo-Json -Depth 30 -Compress)}else{$_}})
                    [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false))
                    $receipt.stdout_sha256=Hash $out
                }
            }
            [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
            $changed=Json (Join-Path $copy 'manifest.json')
            foreach($row in $changed.files){$p=Join-Path $copy $row.path;$row.sha256=Hash $p;$row.bytes=(Get-Item -LiteralPath $p).Length}
            [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($changed|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
        }
        $rejected=$false
        try{& $PSCommandPath -EvidencePath $copy|Out-Null}catch{$rejected=$true}
        Check $rejected ('Negative accepted '+$defect)
        $negativeCount++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;focused_cases=54;native_runs=9;historical_failures=3;choice_cases=152}
