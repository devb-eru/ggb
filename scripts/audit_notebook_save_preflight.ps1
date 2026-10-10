param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$manifest=Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json
$checks=0
function Assert-Condition([bool]$Value,[string]$Label) {if(-not $Value){throw $Label};$script:checks++}
foreach($file in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $file.path))
    Assert-Condition ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) 'Manifest path escapes evidence'
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) ('Missing '+$file.path)
    Assert-Condition ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ceq $file.sha256) ('Changed '+$file.path)
    Assert-Condition ((Get-Item -LiteralPath $path).Length -eq $file.bytes) ('Changed length '+$file.path)
}
$source=Get-Content -LiteralPath (Join-Path $root 'source.json') -Raw|ConvertFrom-Json
$scriptPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'game/scripts/autoload/save_manager.gd'
Assert-Condition ((Get-FileHash -LiteralPath $scriptPath).Hash.ToLowerInvariant() -ceq $source.candidate_save_sha256) 'Audited save implementation differs'
$fixtures=@('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')
foreach($mode in @('focused','migration','host')){
    $dir=if($mode -eq 'focused'){'focused-fixed'}else{$mode}
    $run=Get-Content -LiteralPath (Join-Path $root ($dir+'/'+$mode+'.run.json')) -Raw|ConvertFrom-Json
    Assert-Condition ($run.completed -and $run.exit_code -eq 0 -and $run.source_unchanged) ($mode+' native/source failure')
    Assert-Condition ($run.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine differs'
    Assert-Condition ($run.source_corpus.file_count -eq 264) 'Product script denominator differs'
    foreach($row in $run.source_corpus.rows){
        $columns=$row.Split("`t")
        Assert-Condition ($columns.Count -eq 2 -and $columns[0].StartsWith('scripts/')) 'Invalid corpus row'
        $product=Join-Path (Split-Path -Parent $PSScriptRoot) ('game/'+$columns[0])
        Assert-Condition ((Get-FileHash -LiteralPath $product).Hash.ToLowerInvariant() -ceq $columns[1]) 'Product corpus differs'
    }
    Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'run_notebook_save_preflight_audit.ps1')).Hash.ToLowerInvariant() -ceq $run.runner_sha256) 'Runner differs'
    if($mode -eq 'focused'){
        Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'tests/notebook_save_preflight_audit.gd')).Hash.ToLowerInvariant() -ceq $run.harness_sha256) 'Focused harness differs'
    }
    Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $root ($dir+'/'+$mode+'.out.log'))).Hash.ToLowerInvariant() -ceq $run.stdout_sha256) 'Native stdout receipt differs'
    Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $root ($dir+'/'+$mode+'.err.log'))).Hash.ToLowerInvariant() -ceq $run.stderr_sha256) 'Native stderr receipt differs'
    $lines=@(Get-Content -LiteralPath (Join-Path $root ($dir+'/'+$mode+'.out.log')))
    $marker=switch($mode){'focused'{'SAVE_PREFLIGHT_SMOKE:PASS'}'migration'{'NOTEBOOK_MIGRATION_SMOKE: PASS'}'host'{'NOTEBOOK_HOST_SMOKE: PASS'}}
    Assert-Condition (@($lines|Where-Object {$_ -ceq $marker}).Count -eq 1) ($mode+' PASS missing')
    $errorLog=Join-Path $root ($dir+'/'+$mode+'.err.log')
    Assert-Condition (-not (Select-String -LiteralPath $errorLog -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) ($mode+' script failure')
}
$result=Get-Content -LiteralPath (Join-Path $root 'focused-fixed/focused.result.json') -Raw|ConvertFrom-Json
$rawLines=@(Get-Content -LiteralPath (Join-Path $root 'focused-fixed/focused.out.log')|Where-Object {$_.StartsWith('SAVE_PREFLIGHT_AUDIT: ')})
Assert-Condition ($rawLines.Count -eq 1) 'Ambiguous native result'
$raw=$rawLines[0].Substring('SAVE_PREFLIGHT_AUDIT: '.Length)|ConvertFrom-Json
Assert-Condition (($raw|ConvertTo-Json -Depth 15 -Compress) -ceq ($result|ConvertTo-Json -Depth 15 -Compress)) 'Derived result differs from native stdout'
Assert-Condition ($result.ok -and @($result.errors).Count -eq 0 -and $result.checks -gt 0) 'Safety result failed'
Assert-Condition (@($result.measurements).Count -eq 48) 'Paired save denominator differs'
foreach($fixture in $fixtures){foreach($locale in @('ko_KR','en_US')){
    $group=@($result.measurements|Where-Object {$_.fixture -ceq $fixture -and $_.locale -ceq $locale})
    Assert-Condition ($group.Count -eq 6) 'Fixture/locale group differs'
    Assert-Condition (@($group.archive_sha256|Select-Object -Unique).Count -eq 1 -and @($group.ledger_sha256|Select-Object -Unique).Count -eq 1) 'Paired inputs differ'
    foreach($mode in @('uncached','certificate')){
        $samples=@($group|Where-Object {$_.mode -ceq $mode})
        Assert-Condition ($samples.Count -eq 3 -and (@($samples.repeat|Sort-Object)-join ',') -ceq '0,1,2') 'Repeat IDs differ'
        foreach($sample in $samples){Assert-Condition ($sample.ok -and $sample.total_ms -gt 0) 'Durable sample failed'}
    }
}}
$negativeCount=0
if($SelfTest){
    foreach($defect in @('missing_raw','raw_hash','native_failure','sample_count','duplicate_repeat','paired_input')){
        $copy=Join-Path ([IO.Path]::GetTempPath()) ('ggb-preflight-negative-'+[guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $root -Destination $copy -Recurse
        $target=Join-Path $copy 'focused-fixed/focused.out.log'
        if($defect -eq 'missing_raw'){Remove-Item -LiteralPath $target}
        elseif($defect -eq 'raw_hash'){[IO.File]::AppendAllText($target,'changed raw')}
        else{
            $receiptPath=Join-Path $copy 'focused-fixed/focused.run.json'
            $receipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
            if($defect -eq 'native_failure'){$receipt.exit_code=1}
            else{
                $mutated=Get-Content -LiteralPath (Join-Path $copy 'focused-fixed/focused.result.json') -Raw|ConvertFrom-Json
                if($defect -eq 'sample_count'){$mutated.measurements=@($mutated.measurements|Select-Object -Skip 1)}
                elseif($defect -eq 'duplicate_repeat'){$mutated.measurements[2].repeat=0}
                else{$mutated.measurements[1].archive_sha256='0'*64}
                [IO.File]::WriteAllText((Join-Path $copy 'focused-fixed/focused.result.json'),($mutated|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
                $changedLines=@(Get-Content -LiteralPath $target|ForEach-Object {
                    if($_.StartsWith('SAVE_PREFLIGHT_AUDIT: ')){'SAVE_PREFLIGHT_AUDIT: '+($mutated|ConvertTo-Json -Depth 15 -Compress)}else{$_}
                })
                [IO.File]::WriteAllText($target,($changedLines -join "`n"),[Text.UTF8Encoding]::new($false))
                $receipt.stdout_sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()
            }
            [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
            $changedManifest=Get-Content -LiteralPath (Join-Path $copy 'manifest.json') -Raw|ConvertFrom-Json
            foreach($file in $changedManifest.files){$p=Join-Path $copy $file.path;$file.sha256=(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant();$file.bytes=(Get-Item -LiteralPath $p).Length}
            [IO.File]::WriteAllText((Join-Path $copy 'manifest.json'),($changedManifest|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        }
        $rejected=$false
        try{& $PSCommandPath -EvidencePath $copy|Out-Null}catch{$rejected=$true}
        Assert-Condition $rejected ('Negative accepted: '+$defect)
        $negativeCount++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;negative_cases=$negativeCount;safety_checks=$result.checks;paired_saves=48;scope='HEADLESS exploratory n=3, not p95 acceptance'}|ConvertTo-Json
