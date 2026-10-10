param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Assert-Condition([bool]$Value,[string]$Label){if(-not $Value){throw $Label};$script:checks++}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
$manifest=Read-Json (Join-Path $root 'manifest.json')
Assert-Condition (@($manifest.files).Count -ge 17) 'Evidence denominator missing'
Assert-Condition (@($manifest.files.path|Select-Object -Unique).Count -eq @($manifest.files).Count) 'Duplicate manifest paths'
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-Condition ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) 'Escaping evidence path'
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) ('Missing '+$row.path)
    Assert-Condition ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Changed '+$row.path)
}
$source=Read-Json (Join-Path $root 'source.json')
Assert-Condition (@($source.files).Count -eq 4) 'Changed product denominator'
foreach($row in $source.files){Assert-Condition ((Hash (Join-Path $repo $row.path)) -ceq $row.candidate_sha256) ('Product differs '+$row.path)}
foreach($mode in @('focused-final','migration','host')){
    $name=if($mode -eq 'focused-final'){'focused'}else{$mode}
    $run=Read-Json (Join-Path $root ($mode+'/'+$name+'.run.json'))
    Assert-Condition ($run.completed -and $run.exit_code -eq 0 -and $run.source_unchanged) ($mode+' native/source failure')
    Assert-Condition ($run.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $run.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine differs'
    Assert-Condition ($run.source_corpus.file_count -eq 264 -and @($run.source_corpus.rows).Count -eq 264) 'Script corpus denominator differs'
    Assert-Condition (@($run.source_corpus.rows|Select-Object -Unique).Count -eq 264) 'Duplicate source rows'
    foreach($row in $run.source_corpus.rows){
        $columns=$row.Split("`t")
        Assert-Condition ($columns.Count -eq 2 -and $columns[0].StartsWith('scripts/') -and -not $columns[0].Contains('..')) 'Invalid source path'
        Assert-Condition ((Hash (Join-Path $repo ('game/'+$columns[0]))) -ceq $columns[1]) ('Corpus differs '+$columns[0])
    }
    $runner=if($mode -eq 'focused-final'){'run_notebook_history_async_audit.ps1'}else{'run_notebook_save_preflight_audit.ps1'}
    Assert-Condition ((Hash (Join-Path $PSScriptRoot $runner)) -ceq $run.runner_sha256) 'Runner differs'
    if($mode -eq 'focused-final'){
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.gd')) -ceq $run.harness_sha256) 'Harness differs'
        Assert-Condition ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.tscn')) -ceq $run.scene_sha256) 'Scene differs'
    }
    $out=Join-Path $root ($mode+'/'+$name+'.out.log');$err=Join-Path $root ($mode+'/'+$name+'.err.log')
    Assert-Condition ((Hash $out) -ceq $run.stdout_sha256 -and (Hash $err) -ceq $run.stderr_sha256) 'Native log receipt differs'
    Assert-Condition (-not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Script failure'
    $lines=@(Get-Content -LiteralPath $out)
    $marker=switch($mode){'focused-final'{'HISTORY_ASYNC_SMOKE:PASS'}'migration'{'NOTEBOOK_MIGRATION_SMOKE: PASS'}'host'{'NOTEBOOK_HOST_SMOKE: PASS'}}
    Assert-Condition (@($lines|Where-Object {$_ -ceq $marker}).Count -eq 1) 'PASS marker missing'
    if($mode -eq 'migration'){Assert-Condition ($lines -contains 'NOTEBOOK_SAVE_SAFETY_CHECKS: 381') 'Save safety denominator differs'}
}
$result=Read-Json (Join-Path $root 'focused-final/focused.result.json')
$raw=@(Get-Content -LiteralPath (Join-Path $root 'focused-final/focused.out.log')|Where-Object {$_.StartsWith('HISTORY_ASYNC_AUDIT: ')})
Assert-Condition ($raw.Count -eq 1) 'Ambiguous native summary'
$native=$raw[0].Substring('HISTORY_ASYNC_AUDIT: '.Length)|ConvertFrom-Json
Assert-Condition (($native|ConvertTo-Json -Depth 16 -Compress) -ceq ($result|ConvertTo-Json -Depth 16 -Compress)) 'Derived summary differs'
Assert-Condition ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -eq 870) 'Focused result failed'
Assert-Condition (@($result.cases).Count -eq 72 -and @($result.timings).Count -eq 8) 'Case denominator differs'
$api=@('success','cancel','revision','reload','root','guard','disk','backup','pending','temporary','future','missing_id','promotion','ack','busy','unchanged','input_mutation')
$negative=@{cancel='NB_COMMAND_CANCELLED';revision='NB_COMMAND_STALE_REVISION';reload='NB_COMMAND_STALE_REVISION';root='NB_COMMAND_SCOPE';guard='NB_COMMAND_SCOPE';disk='NB_COMMAND_SOURCE_CHANGED';backup='NB_COMMAND_SOURCE_CHANGED';pending='NB_COMMAND_SOURCE_CHANGED';temporary='ERR_SAVE_TEMP_VERIFY';future='ERR_SAVE_FUTURE_SCHEMA';missing_id='NB_PRODUCER_ID_REQUIRED';promotion='ERR_SAVE_PROMOTE'}
foreach($locale in @('ko_KR','en_US')){
    foreach($scenario in $api){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'api' -and $_.locale -ceq $locale -and $_.scenario -ceq $scenario})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) 'Missing/duplicate API condition'
        if($negative.ContainsKey($scenario)){
            Assert-Condition (-not $rows[0].result.ok -and ($rows[0].result.error_id -ceq $negative[$scenario] -or @($rows[0].result.error_ids) -contains $negative[$scenario])) 'Wrong rejection reason'
        }else{Assert-Condition ($rows[0].result.ok) 'Positive API rejected'}
        if($scenario -eq 'ack'){Assert-Condition $rows[0].result.recovered_acknowledgement 'Acknowledgement not recovered'}
        # The harness records the first commit; its internal assertions check the second no-op.
        if($scenario -eq 'unchanged'){Assert-Condition ($rows[0].result.changed -and $rows[0].result.entry_uid.Length -eq 32) 'Initial duplicate fixture commit failed'}
    }
    foreach($family in @(0,1,2)){foreach($scenario in @('success','promotion','replace','locale','storage')){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'ui' -and $_.locale -ceq $locale -and $_.family -ceq $family -and $_.scenario -ceq $scenario})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed) 'Missing/duplicate UI condition'
    }}
    foreach($fixture in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')){
        $rows=@($result.cases|Where-Object {$_.kind -ceq 'large' -and $_.locale -ceq $locale -and $_.fixture -ceq $fixture})
        Assert-Condition ($rows.Count -eq 1 -and $rows[0].passed -and $rows[0].result.ok) 'Large write failed'
        $timing=@($result.timings|Where-Object {$_.locale -ceq $locale -and $_.fixture -ceq $fixture})
        Assert-Condition ($timing.Count -eq 1 -and $timing[0].worker_frames -gt 0 -and $timing[0].total_ms -gt 0 -and $timing[0].begin_ms -gt 0 -and $timing[0].dispatch_ms -gt 0 -and $timing[0].scope.StartsWith('HEADLESS n=1')) 'Timing scope differs'
    }
}
foreach($attempt in @('focused','focused-fixed')){
    $receipt=Read-Json (Join-Path $root ($attempt+'/focused.run.json'))
    Assert-Condition ($receipt.completed -and $receipt.exit_code -ne 0) 'Failed attempt reclassified as PASS'
    Assert-Condition ((Hash (Join-Path $root ($attempt+'/focused.out.log'))) -ceq $receipt.stdout_sha256 -and (Hash (Join-Path $root ($attempt+'/focused.err.log'))) -ceq $receipt.stderr_sha256) 'Failed raw log differs'
    Assert-Condition ((Hash (Join-Path $root ($attempt+'/notebook_history_async_audit.gd'))) -ceq $receipt.harness_sha256) 'Failed harness differs'
}
$negativeCount=0
if($SelfTest){foreach($defect in @('missing_raw','raw_hash','native_failure','case_count','duplicate_case','mixed_source')){
    $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-history-async-negative-'+[guid]::NewGuid().ToString('N'))
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
            $lines=@(Get-Content -LiteralPath $out|ForEach-Object {if($_.StartsWith('HISTORY_ASYNC_AUDIT: ')){'HISTORY_ASYNC_AUDIT: '+($mutated|ConvertTo-Json -Depth 16 -Compress)}else{$_}})
            [IO.File]::WriteAllText($out,($lines -join "`n"),[Text.UTF8Encoding]::new($false))
            $receipt.stdout_sha256=Hash $out
        }
        [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
        $changed=Read-Json (Join-Path $copy 'manifest.json')
        foreach($row in $changed.files){$p=Join-Path $copy $row.path;$row.sha256=Hash $p;$row.bytes=(Get-Item -LiteralPath $p).Length}
        [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($changed|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    }
    $rejected=$false;try{& $PSCommandPath -EvidencePath $copy|Out-Null}catch{$rejected=$true}
    Assert-Condition $rejected ('Negative accepted: '+$defect);$negativeCount++
}}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;cases=72;headless_timings=8}
