param([Parameter(Mandatory)][string]$EvidencePath,[string]$RepoPath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$checks=0
function Assert-True([bool]$Value,[string]$Label){$script:checks++;if(-not $Value){throw $Label}}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json}
function Corpus-Map($Rows){
    $map=@{}
    foreach($row in $Rows){
        $parts=$row.Split("`t")
        Assert-True ($parts.Count -eq 2 -and -not $map.ContainsKey($parts[0])) 'Invalid product row'
        $map[$parts[0]]=$parts[1]
    }
    return $map
}
function Check-Owner($Result,$Receipt){
    if(-not $Result.ok -or @($Result.errors).Count -or $Result.required_cases -ne 136 -or @($Result.cases).Count -ne 136 -or $null -eq $Receipt.exit_code -or $Receipt.exit_code -ne 0 -or -not $Receipt.completed -or -not $Receipt.source_unchanged){throw 'Invalid owner terminal result'}
    $seen=@{}
    foreach($case in $Result.cases){
        $key=$case.locale+'|'+$case.kind+'|'+$case.reset_type+'|'+$case.boundary+'|'+$case.scenario
        if($seen.ContainsKey($key) -or -not $case.passed){throw 'Duplicate or failed coordinate'}
        $seen[$key]=$true
        if($case.scenario -ne 'control' -and ($case.day_after -ne $case.day_before -or $case.phase_after -cne $case.phase_before)){throw 'Retired owner changed persisted boundary'}
        if($case.scenario -eq 'control' -and ($case.day_after -ne 1 -or $case.phase_after -cne 'idle')){throw 'Wrong live reset boundary'}
    }
    foreach($locale in @('ko_KR','en_US')){
        foreach($boundary in @('fade','write','reveal')){
            foreach($scenario in @('control','view_queue','view_free','view_detach','view_reenter','view_reparent','host_queue','host_free','host_detach','host_reenter','coordinator_replace','slot_replace')){
                if(-not $seen.ContainsKey($locale+'|p6|normal|'+$boundary+'|'+$scenario)){throw 'Missing P6 coordinate'}
            }
        }
        foreach($type in @('normal','broken')){
            foreach($boundary in @('write','complete')){
                foreach($scenario in @('control','host_queue','host_free','host_detach','host_reenter','host_reparent','coordinator_replace','epoch_replace')){
                    if(-not $seen.ContainsKey($locale+'|boot|'+$type+'|'+$boundary+'|'+$scenario)){throw 'Missing bootstrap coordinate'}
                }
            }
        }
    }
}
$manifest=Read-Json (Join-Path $root 'manifest.json')
$listed=@{}
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-True ($path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and -not $listed.ContainsKey($row.path)) 'Unsafe evidence path'
    $listed[$row.path]=$true
    Assert-True ((Get-Item -LiteralPath $path).Length -eq $row.bytes) ('Evidence length '+$row.path)
    Assert-True ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ceq $row.sha256) ('Evidence hash '+$row.path)
}
$actual=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')})
Assert-True ($actual.Count -eq $listed.Count) 'Evidence inventory differs'
$final=Read-Json (Join-Path $root 'retained-owner-full/run.result.json')
$receipt=Read-Json (Join-Path $root 'retained-owner-full/run.json')
Check-Owner $final $receipt
$checks+=136
$before=Read-Json (Join-Path $root 'before-owner-2/run.json')
$baseline=Read-Json (Join-Path $root 'before-owner-2/run.result.json')
Assert-True (-not $baseline.ok -and $baseline.required_cases -eq 12 -and @($baseline.cases).Count -eq 12 -and @($baseline.cases | Where-Object {-not $_.passed}).Count -eq 10) 'Baseline 10/12 changed'
Assert-True ($before.completed -and $null -ne $before.exit_code -and $before.exit_code -ne 0 -and $before.source_unchanged) 'Baseline receipt'
Assert-True (@($baseline.cases | Where-Object {$_.scenario -eq 'control' -and $_.passed}).Count -eq 2) 'Baseline controls missing'
Assert-True (Select-String -LiteralPath (Join-Path $root 'before-owner-2/run.err.log') -Pattern 'instances leaked' -Quiet) 'Baseline exit leak missing'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'before-owner/run.result.json')) 'Initial fixture failure missing'
Assert-True (Select-String -LiteralPath (Join-Path $root 'candidate-full/run.err.log') -Pattern "Invalid type in function '_dispose'" -Quiet) 'Interrupted fixture error missing'
$oldCorpus=Corpus-Map $before.source_corpus.rows
$corpus=Corpus-Map $receipt.source_corpus.rows
Assert-True ($oldCorpus.Count -eq 265 -and $corpus.Count -eq 265) 'Unexpected product count'
$changed=@('scripts/prologue/prologue_controller.gd','scripts/systems/bootstrap.gd','scripts/chapters/chapter_one_controller.gd')
foreach($path in $corpus.Keys){
    Assert-True ($oldCorpus.ContainsKey($path) -and (($oldCorpus[$path] -cne $corpus[$path]) -eq ($path -in $changed))) ('Unexpected product delta '+$path)
    if($RepoPath){Assert-True ((Get-FileHash -LiteralPath (Join-Path $RepoPath ('game/'+$path))).Hash.ToLowerInvariant() -ceq $corpus[$path]) ('Repository source differs '+$path)}
    if($path -in $changed){
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root ('baseline/game/'+$path))).Hash.ToLowerInvariant() -ceq $oldCorpus[$path]) 'Baseline bytes differ'
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root ('retained/game/'+$path))).Hash.ToLowerInvariant() -ceq $corpus[$path]) 'Candidate bytes differ'
    }
}
$runs=@(
    @{name='retained-owner-full';marker='RESET_OWNER_SMOKE:PASS';prefix='RESET_OWNER_AUDIT: ';cases=136},
    @{name='retained-owner-probe';marker='RESET_OWNER_SMOKE:PASS';prefix='RESET_OWNER_AUDIT: ';cases=12},
    @{name='retained-reset-focused';marker='RESET_ASYNC_SMOKE:PASS';prefix='RESET_ASYNC_AUDIT: ';cases=136},
    @{name='retained-reset-ui';marker='RESET_UI_SMOKE:PASS';prefix='RESET_UI_AUDIT: ';cases=16},
    @{name='retained-reset-lifetime';marker='RESET_LIFETIME_SMOKE:PASS';prefix='RESET_LIFETIME_AUDIT: ';cases=50},
    @{name='retained-reset-foundation';marker='FOUNDATION_SMOKE: PASS'},
    @{name='retained-sleep-owner';marker='CAMPAIGN_OWNER_SMOKE:PASS';prefix='CAMPAIGN_OWNER_AUDIT: ';cases=176},
    @{name='retained-sleep-session';marker='CAMPAIGN_SLEEP_SMOKE:PASS';prefix='CAMPAIGN_SLEEP_AUDIT: ';cases=76},
    @{name='retained-sleep-ui';marker='CAMPAIGN_SLEEP_UI_SMOKE:PASS';prefix='CAMPAIGN_SLEEP_UI_AUDIT: ';cases=24},
    @{name='retained-natural';marker='PROLOGUE_NATURAL_ASYNC_SMOKE:PASS';prefix='PROLOGUE_NATURAL_ASYNC_AUDIT: ';cases=64},
    @{name='retained-history';marker='HISTORY_ASYNC_SMOKE:PASS';prefix='HISTORY_ASYNC_AUDIT: ';cases=72},
    @{name='retained-host';marker='NOTEBOOK_HOST_SMOKE: PASS'},
    @{name='retained-migration';marker='NOTEBOOK_MIGRATION_SMOKE: PASS'}
)
foreach($run in $runs){
    $dir=Join-Path $root $run.name
    $receipts=@(Get-ChildItem -LiteralPath $dir -Filter '*run.json' -File)
    Assert-True ($receipts.Count -eq 1) ('Ambiguous receipt '+$run.name)
    $r=Read-Json $receipts[0].FullName
    Assert-True ($r.completed -and $null -ne $r.exit_code -and $r.exit_code -eq 0 -and $r.source_unchanged) ('Native/source failure '+$run.name)
    Assert-True ($r.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') ('Wrong engine '+$run.name)
    $runners=@(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -ceq $r.runner_sha256})
    Assert-True ($runners.Count -gt 0) ('Executed runner missing '+$run.name)
    foreach($h in $r.harnesses){
        $copies=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $h.name | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -ceq $h.sha256})
        Assert-True ($copies.Count -gt 0) ('Executed harness missing '+$h.name)
    }
    $current=Corpus-Map $r.source_corpus.rows
    Assert-True ($current.Count -eq 265) ('Different source count '+$run.name)
    foreach($path in $corpus.Keys){Assert-True ($current[$path] -ceq $corpus[$path]) ('Mixed source '+$run.name+' '+$path)}
    $out=@(Get-ChildItem -LiteralPath $dir -Filter '*.out.log' -File)
    $err=@(Get-ChildItem -LiteralPath $dir -Filter '*.err.log' -File)
    Assert-True ($out.Count -eq 1 -and $err.Count -eq 1) ('Ambiguous logs '+$run.name)
    Assert-True ((Get-FileHash -LiteralPath $out[0].FullName).Hash.ToLowerInvariant() -ceq $r.stdout_sha256) 'stdout hash differs'
    Assert-True ((Get-FileHash -LiteralPath $err[0].FullName).Hash.ToLowerInvariant() -ceq $r.stderr_sha256) 'stderr hash differs'
    Assert-True (-not (Select-String -LiteralPath $out[0].FullName,$err[0].FullName -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|instances leaked|Leaked instance:|resources still in use|Orphan StringName:' -Quiet)) ('Script/lifetime failure '+$run.name)
    $lines=@(Get-Content -LiteralPath $out[0].FullName)
    Assert-True (@($lines | Where-Object {$_ -ceq $run.marker}).Count -eq 1) ('Exact terminal marker '+$run.name)
    if($run.cases){
        $rows=@($lines | Where-Object {$_.StartsWith($run.prefix)})
        Assert-True ($rows.Count -eq 1) 'Ambiguous summary'
        $result=$rows[0].Substring($run.prefix.Length) | ConvertFrom-Json
        Assert-True ($result.ok -and @($result.errors).Count -eq 0 -and $result.required_cases -eq $run.cases -and @($result.cases).Count -eq $run.cases -and @($result.cases | Where-Object {-not $_.passed}).Count -eq 0) ('Wrong denominator '+$run.name)
    }
}
$rejections=0
if($SelfTest){
    foreach($mutation in @('missing','duplicate','failed','day','phase','native','null_native')){
        $result=$final | ConvertTo-Json -Depth 32 -Compress | ConvertFrom-Json
        $r=$receipt | ConvertTo-Json -Depth 32 -Compress | ConvertFrom-Json
        switch($mutation){
            'missing'{$result.cases=@($result.cases | Select-Object -Skip 1)}
            'duplicate'{$result.cases[1]=$result.cases[0]}
            'failed'{$result.cases[0].passed=$false}
            'day'{$result.cases[1].day_after+=1}
            'phase'{$result.cases[1].phase_after='changed'}
            'native'{$r.exit_code=1}
            'null_native'{$r.exit_code=$null}
        }
        $rejected=$false
        try{Check-Owner $result $r}catch{$rejected=$true}
        Assert-True $rejected ('Accepted mutation '+$mutation)
        $rejections++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;mutation_rejections=$rejections;native_runs=$runs.Count;owner_cases=136;baseline_failures=10;scope='HEADLESS P6/bootstrap callbacks and same-source regressions; no OS input/cross-process/full acceptance'}
