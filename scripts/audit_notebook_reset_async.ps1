param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Check([bool]$condition,[string]$message){if(-not $condition){throw $message};$script:checks++}
function Json([string]$path){Get-Content -LiteralPath $path -Raw | ConvertFrom-Json}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Summary([string]$path,[string]$prefix){
    $lines=@(Get-Content -LiteralPath $path | Where-Object {$_.StartsWith($prefix)})
    Check ($lines.Count -eq 1) ('Ambiguous summary '+$path)
    $lines[0].Substring($prefix.Length) | ConvertFrom-Json
}
function Corpus($receipt,[bool]$historical=$false){
    Check ($receipt.source_unchanged -and $receipt.source_corpus.file_count -eq 265 -and @($receipt.source_corpus.rows).Count -eq 265) 'Source mutation/denominator'
    $paths=@()
    foreach($row in $receipt.source_corpus.rows){
        $parts=$row.Split("`t")
        Check ($parts.Count -eq 2 -and $parts[0].StartsWith('scripts/') -and -not $parts[0].Contains('..') -and $parts[1] -cmatch '^[0-9a-f]{64}$') 'Bad corpus row'
        $paths+=$parts[0]
        $path=Join-Path $repo ('game/'+$parts[0])
        $archive=Join-Path $root ('archive/pre-between-fix/game/'+$parts[0])
        if($historical -and (Test-Path -LiteralPath $archive)){$path=$archive}
        Check ((Hash $path) -ceq $parts[1]) ('Mixed product source '+$parts[0])
    }
    $actual=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/scripts') -Filter '*.gd' -File -Recurse | ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')})
    Check (@($paths | Select-Object -Unique).Count -eq 265 -and $actual.Count -eq 265 -and @(Compare-Object $paths $actual).Count -eq 0) 'Missing/duplicate source'
}
function Native([string]$dir,[string]$stem,[string]$runner,[string]$marker,[int]$exit=0,[bool]$historical=$false){
    $path=Join-Path $root ($dir+'/'+$stem)
    $receipt=Json ($path+$(if($stem -eq 'run'){'.json'}else{'.run.json'}))
    Check ($receipt.completed -and $receipt.exit_code -eq $exit -and [DateTime]$receipt.finished_utc -gt [DateTime]$receipt.started_utc) ('Native completion '+$dir)
    Check ($receipt.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $receipt.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine fingerprint'
    Check ((Hash (Join-Path $PSScriptRoot $runner)) -ceq $receipt.runner_sha256) 'Runner fingerprint'
    Corpus $receipt $historical
    Check ((Hash ($path+'.out.log')) -ceq $receipt.stdout_sha256 -and (Hash ($path+'.err.log')) -ceq $receipt.stderr_sha256) 'Changed raw log'
    Check (-not (Select-String -LiteralPath ($path+'.out.log'),($path+'.err.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|resources still in use|ObjectDB instances leaked' -Quiet)) 'Script/resource error'
    Check (@(Get-Content -LiteralPath ($path+'.out.log') | Where-Object {$_ -ceq $marker}).Count -eq 1) 'Missing/ambiguous terminal marker'
    foreach($entry in $receipt.harnesses){Check ((Hash (Join-Path $root ($dir+'/'+$entry.name))) -ceq $entry.sha256) 'Executed harness fingerprint'}
    $pairs=switch($dir){
        'current-choice'{@(@('base_harness_sha256','notebook_history_async_audit.gd'),@('parent_harness_sha256','notebook_prologue_async_audit.gd'),@('harness_sha256','notebook_prologue_choice_async_audit.gd'),@('scene_sha256','notebook_prologue_choice_async_audit.tscn'))}
        'current-history'{@(@('harness_sha256','notebook_history_async_audit.gd'),@('scene_sha256','notebook_history_async_audit.tscn'))}
    }
    foreach($pair in $pairs){Check ((Hash (Join-Path $PSScriptRoot ('tests/'+$pair[1]))) -ceq $receipt.($pair[0])) 'Regression harness fingerprint'}
    $receipt
}
function ResetCoordinates($result,[bool]$failed=$false){
    Check (@($result.cases).Count -eq 136 -and $result.required_cases -eq 136) 'Reset denominator'
    foreach($locale in @('ko_KR','en_US')){
        foreach($type in @('normal','broken')){
            foreach($kind in @('phase','reject','ack','stale','between')){
                $names=switch($kind){
                    {$_ -in @('phase','reject','ack')}{@('sleep_confirmed','player_committed','memory_committed','physical_reset_complete','morning_loaded','route_selected','complete','idle')}
                    'stale'{@('guard','revision','epoch','cancel','root','source','busy','payload')}
                    'between'{@('between_epoch','between_revision')}
                }
                foreach($name in $names){
                    $rows=@($result.cases | Where-Object {$_.locale -ceq $locale -and $_.reset_type -ceq $type -and $_.kind -ceq $kind -and $(if($kind -in @('phase','reject','ack')){$_.phase}else{$_.scenario}) -ceq $name})
                    Check ($rows.Count -eq 1 -and $rows[0].passed -eq (-not ($failed -and $kind -eq 'between'))) ('Reset coordinate '+$locale+':'+$type+':'+$kind+':'+$name)
                }
            }
        }
    }
}
$manifest=Json (Join-Path $root 'manifest.json')
$actual=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')} | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
Check ($actual.Count -eq @($manifest.files).Count -and @($manifest.files.path | Select-Object -Unique).Count -eq $actual.Count -and @(Compare-Object $actual @($manifest.files.path)).Count -eq 0) 'Manifest completeness'
foreach($row in $manifest.files){
    Check ($row.path -is [string] -and -not $row.path.Contains('..') -and -not $row.path.Contains('\')) 'Manifest path'
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Check ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)) 'Manifest escape/missing'
    Check ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) 'Evidence integrity'
}
$source=Json (Join-Path $root 'source.json')
$expected=@('game/scripts/autoload/save_manager.gd','game/scripts/systems/dialogue_history_writer.gd','game/scripts/systems/notebook_save_worker.gd','game/scripts/systems/reset_coordinator.gd','game/scripts/systems/bootstrap.gd','game/scripts/prologue/prologue_controller.gd')
Check ($source.head -ceq 'ede16eef62145121c41634ba9a0c7999b26a0712' -and @($source.files).Count -eq 6 -and @(Compare-Object $expected @($source.files.path)).Count -eq 0) 'Product change denominator'
foreach($row in $source.files){
    Check ((Hash (Join-Path $repo $row.path)) -ceq $row.candidate_sha256) 'Candidate differs'
    Check ((Hash (Join-Path $root ('baseline/'+$row.path))) -ceq $row.baseline_sha256) 'Baseline differs'
}
$receipt=Native 'current-focused' 'run' 'run_notebook_reset_async_audit.ps1' 'RESET_ASYNC_SMOKE:PASS'
$focused=Summary (Join-Path $root 'current-focused/run.out.log') 'RESET_ASYNC_AUDIT: '
Check ($focused.ok -and @($focused.errors).Count -eq 0 -and $focused.checks -eq 3364) 'Reset assertions'
ResetCoordinates $focused
$receipt=Native 'archive/between-diagnostic' 'run' 'run_notebook_reset_async_audit.ps1' 'RESET_ASYNC_SMOKE:FAIL' 1 $true
$failed=Summary (Join-Path $root 'archive/between-diagnostic/run.out.log') 'RESET_ASYNC_AUDIT: '
Check (-not $failed.ok -and @($failed.errors).Count -eq 16 -and $failed.checks -eq 3404) 'Original failure must remain failure'
ResetCoordinates $failed $true
$receipt=Native 'current-ui' 'run' 'run_notebook_reset_async_audit.ps1' 'RESET_UI_SMOKE:PASS'
$ui=Summary (Join-Path $root 'current-ui/run.out.log') 'RESET_UI_AUDIT: '
Check ($ui.ok -and @($ui.errors).Count -eq 0 -and @($ui.cases).Count -eq 16 -and $ui.required_cases -eq 16 -and $ui.checks -eq 372) 'UI denominator'
foreach($locale in @('ko_KR','en_US')){
    foreach($scenario in @('success','reject_initial','reject_physical','ack_physical','locale','cancel')){
        $rows=@($ui.cases | Where-Object {$_.kind -ceq 'sleep_ui' -and $_.locale -ceq $locale -and $_.scenario -ceq $scenario})
        Check ($rows.Count -eq 1 -and $rows[0].passed) 'UI sleep coordinate'
    }
    foreach($type in @('normal','broken')){
        $rows=@($ui.cases | Where-Object {$_.kind -ceq 'boot_ui' -and $_.locale -ceq $locale -and $_.reset_type -ceq $type})
        Check ($rows.Count -eq 1 -and $rows[0].passed) 'UI boot coordinate'
    }
}
$receipt=Native 'current-foundation' 'run' 'run_notebook_reset_async_audit.ps1' 'FOUNDATION_SMOKE: PASS'
Check (@(Get-Content (Join-Path $root 'current-foundation/run.out.log') | Where-Object {$_ -ceq 'RESET_ACKNOWLEDGEMENT_CASES: 20'}).Count -eq 1) 'Sync reset regression'
foreach($entry in @(
    @('natural','focused','run_notebook_prologue_natural_async_audit.ps1','PROLOGUE_NATURAL_ASYNC_SMOKE:PASS','PROLOGUE_NATURAL_ASYNC_AUDIT: ',64,1256),
    @('choice','focused','run_notebook_prologue_choice_async_audit.ps1','PROLOGUE_CHOICE_ASYNC_SMOKE:PASS','PROLOGUE_CHOICE_ASYNC_AUDIT: ',152,2128),
    @('history','focused','run_notebook_history_async_audit.ps1','HISTORY_ASYNC_SMOKE:PASS','HISTORY_ASYNC_AUDIT: ',72,870))){
    $receipt=Native ('current-'+$entry[0]) $entry[1] $entry[2] $entry[3]
    $result=Summary (Join-Path $root ('current-'+$entry[0]+'/'+$entry[1]+'.out.log')) $entry[4]
    Check ($result.ok -and @($result.errors).Count -eq 0 -and @($result.cases).Count -eq $entry[5] -and $result.checks -eq $entry[6] -and @($result.cases | Where-Object {-not $_.passed}).Count -eq 0) ('Regression '+$entry[0])
}
foreach($entry in @(@('migration','NOTEBOOK_MIGRATION_SMOKE: PASS','NOTEBOOK_SAVE_SAFETY_CHECKS: 381'),@('host','NOTEBOOK_HOST_SMOKE: PASS','NOTEBOOK_HOST_CHECKS: 548'))){
    $receipt=Native ('current-'+$entry[0]) $entry[0] 'run_notebook_save_preflight_audit.ps1' $entry[1]
    Check (@(Get-Content (Join-Path $root ('current-'+$entry[0]+'/'+$entry[0]+'.out.log')) | Where-Object {$_ -ceq $entry[2]}).Count -eq 1) 'Save/host assertions'
}
if($SelfTest){
    $rejects=0
    foreach($mode in @('duplicate','missing','false_pass','wrong_phase','wrong_locale','historical_reclassified')){
        $copy=$focused | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        switch($mode){
            'duplicate'{$copy.cases[0]=$copy.cases[1]}
            'missing'{$copy.cases=@($copy.cases | Select-Object -Skip 1)}
            'false_pass'{$copy.cases[0].passed=$false}
            'wrong_phase'{$copy.cases[0].phase='invented'}
            'wrong_locale'{$copy.cases[0].locale='ja_JP'}
            'historical_reclassified'{$copy=$failed | ConvertTo-Json -Depth 20 | ConvertFrom-Json}
        }
        $rejected=$false
        try{ResetCoordinates $copy}catch{$rejected=$true}
        Check $rejected ('Mutation accepted '+$mode)
        $rejects++
    }
    Write-Output ('RESET_INDEPENDENT_MUTATIONS_REJECTED: '+$rejects)
}
Write-Output ('RESET_INDEPENDENT_CHECKS: '+$checks)
Write-Output 'RESET_INDEPENDENT_AUDIT: PASS'
