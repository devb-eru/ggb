param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Assert-Condition([bool]$Value,[string]$Label){if(-not $Value){throw $Label};$script:checks++}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
$manifest=Read-Json (Join-Path $root 'manifest.json')
Assert-Condition (@($manifest.files).Count -ge 32 -and @($manifest.files.path|Select-Object -Unique).Count -eq @($manifest.files).Count) 'Evidence denominator/duplicate'
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-Condition ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) 'Escaping evidence path'
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) ('Missing '+$row.path)
    Assert-Condition ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Changed '+$row.path)
}
$source=Read-Json (Join-Path $root 'source.json')
Assert-Condition (@($source.files).Count -eq 5) 'Product denominator'
foreach($row in $source.files){Assert-Condition ((Hash (Join-Path $repo $row.path)) -ceq $row.candidate_sha256) ('Product differs '+$row.path)}
Assert-Condition ((Hash (Join-Path $repo 'game/scripts/systems/prologue_save_candidate.gd.uid')) -ceq $source.generated_uid_sha256) 'Generated UID differs'
$configs=@(
    @('focused-final','focused','run_notebook_prologue_async_audit.ps1','PROLOGUE_ASYNC_SMOKE:PASS'),
    @('history','focused','run_notebook_history_async_audit.ps1','HISTORY_ASYNC_SMOKE:PASS'),
    @('migration','migration','run_notebook_save_preflight_audit.ps1','NOTEBOOK_MIGRATION_SMOKE: PASS'),
    @('host','host','run_notebook_save_preflight_audit.ps1','NOTEBOOK_HOST_SMOKE: PASS'),
    @('prologue','run','ORIGINAL_COMPATIBILITY','NOTEBOOK_PROLOGUE_SMOKE: PASS '),
    @('cursor_seed_final','run','run_notebook_prologue_compatibility.ps1','NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'),
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
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_prologue_async_audit.gd')) -ceq $run.harness_sha256 -and (Hash (Join-Path $PSScriptRoot 'tests/notebook_prologue_async_audit.tscn')) -ceq $run.scene_sha256) 'Focused harness/scene differs'
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.gd')) -ceq $run.base_harness_sha256) 'Base harness differs'
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
$seed=Read-Json (Join-Path $root 'cursor_seed_final/run.json');$reload=Read-Json (Join-Path $root 'cursor_resume/run.json')
Assert-Condition ($seed.profile -ceq $reload.profile -and [DateTime]$reload.started_utc -gt [DateTime]$seed.finished_utc) 'Cursor process pair disconnected'
$completed=Read-Json (Join-Path $root 'cursor_completed/run.json')
Assert-Condition ($completed.profile -ceq $reload.profile -and [DateTime]$completed.started_utc -gt [DateTime]$reload.finished_utc) 'Completed cursor process disconnected'
$failed=Read-Json (Join-Path $root 'cursor_reload/run.json')
Assert-Condition ($failed.completed -and $failed.exit_code -ne 0 -and (Hash (Join-Path $root 'runners/compatibility-original.ps1')) -ceq $failed.runner_sha256) 'Failed wrapper attempt reclassified'
$result=Read-Json (Join-Path $root 'focused-final/focused.result.json')
$raw=@(Get-Content (Join-Path $root 'focused-final/focused.out.log')|Where-Object {$_.StartsWith('PROLOGUE_ASYNC_AUDIT: ')})
Assert-Condition ($raw.Count -eq 1) 'Focused result missing'
$native=$raw[0].Substring('PROLOGUE_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
Assert-Condition (($native|ConvertTo-Json -Depth 16 -Compress) -ceq ($result|ConvertTo-Json -Depth 16 -Compress)) 'Derived summary differs'
Assert-Condition ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 486 -and @($result.cases).Count -eq 42 -and @($result.timings).Count -eq 8) 'Focused result/denominator'
foreach($locale in @('ko_KR','en_US')){
    foreach($kind in @('candidate','ui')){
        $expected=if($kind -eq 'candidate'){@('basic','window','combined','stale_note','malformed','choice')}else{@('success','promotion','ack','replace','locale','service','progress_changed','pending_note_changed','handoff','after_action','after_action_failure')}
        foreach($scenario in $expected){
            $rows=@($result.cases|Where-Object {$_.kind -ceq $kind -and $_.scenario -ceq $scenario -and $_.locale -ceq $locale})
            Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) ('Missing/duplicate condition '+$kind+':'+$scenario)
        }
    }
    foreach($fixture in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'large' -and $_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        $timing=@($result.timings|Where-Object {$_.fixture -ceq $fixture -and $_.locale -ceq $locale})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed -and $timing.Count -eq 1 -and $timing[0].worker_frames -gt 0 -and $timing[0].total_ms -gt 0 -and $timing[0].scope.StartsWith('HEADLESS n=1')) 'Large write/timing failed'
    }
}
foreach($attempt in @('focused','focused-fixed')){
    $run=Read-Json (Join-Path $root ($attempt+'/focused.run.json'))
    Assert-Condition ($run.completed -and $run.exit_code -ne 0) 'Failed attempt reclassified'
    Assert-Condition ((Hash (Join-Path $root ($attempt+'/notebook_prologue_async_audit.gd'))) -ceq $run.harness_sha256) 'Failed harness differs'
}
$negativeCount=0
if($SelfTest){foreach($defect in @('missing_raw','raw_hash','native_failure','case_count','duplicate_case','mixed_source')){
    $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-prologue-async-negative-'+[guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $root -Destination $copy -Recurse
    $out=Join-Path $copy 'focused-final/focused.out.log'
    if($defect -eq 'missing_raw'){Remove-Item -LiteralPath $out}
    elseif($defect -eq 'raw_hash'){[IO.File]::AppendAllText($out,'changed raw')}
    else{
        $receiptPath=Join-Path $copy 'focused-final/focused.run.json';$receipt=Read-Json $receiptPath
        if($defect -eq 'native_failure'){$receipt.exit_code=1}
        elseif($defect -eq 'mixed_source'){$receipt.source_corpus.rows[0]='scripts/autoload/event_manager.gd'+"`t"+('0'*64)}
        else{
            $mutated=Read-Json (Join-Path $copy 'focused-final/focused.result.json')
            if($defect -eq 'case_count'){$mutated.cases=@($mutated.cases|Select-Object -Skip 1)}else{$mutated.cases[1]=$mutated.cases[0]}
            [IO.File]::WriteAllText((Join-Path $copy 'focused-final/focused.result.json'),($mutated|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
            $lines=@(Get-Content -LiteralPath $out|ForEach-Object {if($_.StartsWith('PROLOGUE_ASYNC_AUDIT: ')){'PROLOGUE_ASYNC_AUDIT: '+($mutated|ConvertTo-Json -Depth 16 -Compress)}else{$_}})
            [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false));$receipt.stdout_sha256=Hash $out
        }
        [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
        $changed=Read-Json (Join-Path $copy 'manifest.json')
        foreach($row in $changed.files){$p=Join-Path $copy $row.path;$row.sha256=Hash $p;$row.bytes=(Get-Item -LiteralPath $p).Length}
        [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($changed|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    }
    $rejected=$false;try{& $PSCommandPath -EvidencePath $copy|Out-Null}catch{$rejected=$true}
    Assert-Condition $rejected ('Negative accepted '+$defect);$negativeCount++
}}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;focused_cases=42;native_runs=8}
