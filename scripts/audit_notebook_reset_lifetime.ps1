param([Parameter(Mandatory)][string]$EvidencePath,[string]$RepoPath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$checks=0
function Assert-True([bool]$Value,[string]$Label){
    $script:checks++
    if(-not $Value){throw $Label}
}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json}
function Corpus-Map($Rows){
    $map=@{}
    foreach($row in $Rows){
        $parts=$row.Split("`t")
        Assert-True ($parts.Count -eq 2 -and -not $map.ContainsKey($parts[0])) 'Invalid or duplicate source row'
        $map[$parts[0]]=$parts[1]
    }
    return $map
}
function Expected-Coordinates {
    $coordinates=@()
    foreach($locale in @('ko_KR','en_US')){
        foreach($type in @('normal','broken')){
            foreach($scenario in @('control','epoch','revision','game_free','game_queue','service_queue','service_detach','guard')){
                $coordinates+=('completed|'+$locale+'|'+$type+'|'+$scenario)
            }
        }
        foreach($scenario in @('queued_begin','queued_pending','detached_pending','game_queued_pending','queued_reference_begin','detached_reference_begin')){$coordinates+=('service|'+$locale+'||'+$scenario)}
        foreach($scenario in @('queue','detach','free')){$coordinates+=('writer|'+$locale+'||'+$scenario)}
    }
    return $coordinates
}
function Check-Lifetime($Result,$Receipt){
    if(-not $Result.ok -or @($Result.errors).Count -ne 0 -or $Result.required_cases -ne 50 -or @($Result.cases).Count -ne 50 -or $Receipt.exit_code -ne 0 -or -not $Receipt.completed -or -not $Receipt.source_unchanged){throw 'Invalid lifetime result/receipt'}
    $seen=@{}
    foreach($case in $Result.cases){
        $key=$case.kind+'|'+$case.locale+'|'+$case.reset_type+'|'+$case.scenario
        if($seen.ContainsKey($key) -or -not $case.passed){throw 'Duplicate/failed lifetime coordinate'}
        $seen[$key]=$true
        if($case.kind -eq 'completed'){
            if(-not $case.returned -or $case.result.ok -ne ($case.scenario -eq 'control')){throw 'Wrong completion outcome'}
            if($case.scenario -ne 'control' -and 'NB_COMMAND_SCOPE' -notin $case.result.error_ids){throw 'Wrong completion boundary'}
        }
    }
    foreach($coordinate in (Expected-Coordinates)){if(-not $seen.ContainsKey($coordinate)){throw 'Missing independent lifetime coordinate'}}
}
$manifest=Read-Json (Join-Path $root 'manifest.json')
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-True ($path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Evidence path escapes root'
    Assert-True ((Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Evidence length '+$row.path)
    Assert-True ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ceq $row.sha256) ('Evidence hash '+$row.path)
}
$final=Read-Json (Join-Path $root 'final-lifetime/run.result.json')
$receipt=Read-Json (Join-Path $root 'final-lifetime/run.json')
Check-Lifetime $final $receipt
$checks+=50
$before=Read-Json (Join-Path $root 'before-lifetime-2/run.json')
$lines=@(Get-Content -LiteralPath (Join-Path $root 'before-lifetime-2/run.out.log'))
$prefix='RESET_LIFETIME_AUDIT: '
$baselineRows=@($lines | Where-Object {$_.StartsWith($prefix)})
Assert-True ($baselineRows.Count -eq 1) 'Missing baseline terminal result'
$baseline=$baselineRows[0].Substring($prefix.Length) | ConvertFrom-Json
Assert-True (-not $baseline.ok -and $baseline.required_cases -eq 40 -and @($baseline.cases).Count -eq 40 -and @($baseline.cases | Where-Object {-not $_.passed}).Count -eq 22) 'Baseline failures changed'
Assert-True ($before.completed -and $before.exit_code -ne 0 -and $before.source_unchanged) 'Baseline native/source receipt'
Assert-True ((Get-FileHash -LiteralPath (Join-Path $root 'baseline-harness/run_notebook_reset_async_audit.ps1')).Hash.ToLowerInvariant() -ceq $before.runner_sha256) 'Baseline runner reconstruction does not match recorded bytes'
$oldCorpus=Corpus-Map $before.source_corpus.rows
$corpus=Corpus-Map $receipt.source_corpus.rows
Assert-True ($oldCorpus.Count -eq 265 -and $corpus.Count -eq 265) 'Unexpected product source count'
$changed=@('scripts/systems/reset_coordinator.gd','scripts/systems/dialogue_history_writer.gd','scripts/autoload/save_manager.gd')
foreach($path in $corpus.Keys){
    Assert-True ($oldCorpus.ContainsKey($path)) ('Missing baseline product '+$path)
    Assert-True (($oldCorpus[$path] -cne $corpus[$path]) -eq ($path -in $changed)) ('Unexpected product delta '+$path)
    if($RepoPath){Assert-True ((Get-FileHash -LiteralPath (Join-Path $RepoPath ('game/'+$path))).Hash.ToLowerInvariant() -ceq $corpus[$path]) ('Repository differs '+$path)}
}
$runs=@(
    @{name='final-lifetime';prefix='RESET_LIFETIME_AUDIT: ';marker='RESET_LIFETIME_SMOKE:PASS';cases=50},
    @{name='regress-reset-focused';prefix='RESET_ASYNC_AUDIT: ';marker='RESET_ASYNC_SMOKE:PASS';cases=136},
    @{name='regress-reset-ui';prefix='RESET_UI_AUDIT: ';marker='RESET_UI_SMOKE:PASS';cases=16},
    @{name='regress-sleep-session';prefix='CAMPAIGN_SLEEP_AUDIT: ';marker='CAMPAIGN_SLEEP_SMOKE:PASS';cases=76},
    @{name='regress-sleep-ui';prefix='CAMPAIGN_SLEEP_UI_AUDIT: ';marker='CAMPAIGN_SLEEP_UI_SMOKE:PASS';cases=24},
    @{name='regress-history';prefix='HISTORY_ASYNC_AUDIT: ';marker='HISTORY_ASYNC_SMOKE:PASS';cases=72},
    @{name='regress-reset-foundation';marker='FOUNDATION_SMOKE: PASS'},
    @{name='regress-host';marker='NOTEBOOK_HOST_SMOKE: PASS'},
    @{name='regress-migration';marker='NOTEBOOK_MIGRATION_SMOKE: PASS'}
)
foreach($run in $runs){
    $dir=Join-Path $root $run.name
    $receiptPaths=@(Get-ChildItem -LiteralPath $dir -Filter '*run.json' -File)
    Assert-True ($receiptPaths.Count -eq 1) ('Ambiguous receipt '+$run.name)
    $r=Read-Json $receiptPaths[0].FullName
    Assert-True ($r.completed -and $r.exit_code -eq 0 -and $r.source_unchanged) ('Native/source failure '+$run.name)
    Assert-True ($r.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') ('Wrong engine '+$run.name)
    $runners=@(Get-ChildItem -LiteralPath (Join-Path $root 'replay') -Filter '*.ps1' -File | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -ceq $r.runner_sha256})
    Assert-True ($runners.Count -eq 1) ('Executed runner missing '+$run.name)
    if($r.harnesses){
        foreach($h in $r.harnesses){
            $copies=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $h.name | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -ceq $h.sha256})
            Assert-True ($copies.Count -gt 0) ('Executed harness missing '+$h.name)
        }
    }
    $currentCorpus=Corpus-Map $r.source_corpus.rows
    Assert-True ($currentCorpus.Count -eq $corpus.Count) ('Different source count '+$run.name)
    foreach($key in $corpus.Keys){Assert-True ($currentCorpus[$key] -ceq $corpus[$key]) ('Mixed source '+$run.name+' '+$key)}
    $outPaths=@(Get-ChildItem -LiteralPath $dir -Filter '*.out.log' -File)
    $errPaths=@(Get-ChildItem -LiteralPath $dir -Filter '*.err.log' -File)
    Assert-True ($outPaths.Count -eq 1 -and $errPaths.Count -eq 1) ('Ambiguous logs '+$run.name)
    Assert-True ((Get-FileHash -LiteralPath $outPaths[0].FullName).Hash.ToLowerInvariant() -ceq $r.stdout_sha256) 'stdout receipt mismatch'
    Assert-True ((Get-FileHash -LiteralPath $errPaths[0].FullName).Hash.ToLowerInvariant() -ceq $r.stderr_sha256) 'stderr receipt mismatch'
    Assert-True (-not (Select-String -LiteralPath $outPaths[0].FullName,$errPaths[0].FullName -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) ('Script failure '+$run.name)
    $outLines=@(Get-Content -LiteralPath $outPaths[0].FullName)
    Assert-True (@($outLines | Where-Object {$_ -ceq $run.marker}).Count -eq 1) ('Exact terminal missing '+$run.name)
    if($run.cases){
        $rows=@($outLines | Where-Object {$_.StartsWith($run.prefix)})
        Assert-True ($rows.Count -eq 1) 'Ambiguous result'
        $result=$rows[0].Substring($run.prefix.Length) | ConvertFrom-Json
        Assert-True ($result.ok -and @($result.errors).Count -eq 0 -and $result.required_cases -eq $run.cases -and @($result.cases).Count -eq $run.cases -and @($result.cases | Where-Object {-not $_.passed}).Count -eq 0) ('Result denominator '+$run.name)
    }
}
$rejections=0
if($SelfTest){
    foreach($mutation in @('missing','duplicate','failed','outcome','error','native')){
        $mutated=$final | ConvertTo-Json -Depth 32 -Compress | ConvertFrom-Json
        $mutatedReceipt=$receipt | ConvertTo-Json -Depth 32 -Compress | ConvertFrom-Json
        switch($mutation){
            'missing'{$mutated.cases=@($mutated.cases | Select-Object -Skip 1)}
            'duplicate'{$mutated.cases[1]=$mutated.cases[0]}
            'failed'{$mutated.cases[0].passed=$false}
            'outcome'{$mutated.cases[1].result.ok=$true}
            'error'{$mutated.cases[1].result.error_ids=@('OTHER')}
            'native'{$mutatedReceipt.exit_code=1}
        }
        $rejected=$false
        try{Check-Lifetime $mutated $mutatedReceipt}catch{$rejected=$true}
        Assert-True $rejected ('Accepted mutation '+$mutation)
        $rejections++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;mutation_rejections=$rejections;native_runs=$runs.Count;lifetime_cases=50;baseline_failures=22;scope='Local callback/service lifetime and same-source regression only'}
