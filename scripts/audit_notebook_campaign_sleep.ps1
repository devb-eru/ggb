param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Check([bool]$value,[string]$label){if(-not $value){throw $label};$script:checks++}
function Json([string]$path){Get-Content -LiteralPath $path -Raw | ConvertFrom-Json}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Coordinates($result,[string]$mode){
    $count=if($mode -eq 'ui'){24}else{76}
    Check ($result.ok -and @($result.errors).Count -eq 0 -and @($result.cases).Count -eq $count -and $result.required_cases -eq $count) 'Case denominator/result'
    foreach($locale in @('ko_KR','en_US')){
        foreach($route in @('chapter','mirror','basement','bedroom','capsule','rest')){
            $faults=if($mode -eq 'ui'){@('success','wake_reject')}else{@('success','wake_reject','wake_ack','reset_reject')}
            foreach($fault in $faults){
                if($route -eq 'rest' -and $fault -eq 'reset_reject'){continue}
                $rows=@($result.cases | Where-Object {$_.locale -ceq $locale -and $_.route -ceq $route -and $_.fault -ceq $fault -and $_.kind -ceq $mode})
                Check ($rows.Count -eq 1 -and $rows[0].passed) ('Route/fault coordinate '+$locale+':'+$route+':'+$fault)
                $kinds=@($rows[0].worker_kinds)
                Check (@($kinds | Where-Object {$_ -ceq 'reset'}).Count -eq $(if($route -eq 'rest'){0}elseif($fault -eq 'reset_reject'){9}else{8})) 'Reset worker count'
                Check (@($kinds | Where-Object {$_ -ceq 'wake'}).Count -eq $(if($fault -eq 'wake_reject'){2}else{1})) 'Wake worker count'
            }
        }
        if($mode -eq 'session'){
            foreach($kind in @('scope','payload')){
                $names=if($kind -eq 'scope'){@('guard','cancel','epoch','revision','busy','payload')}else{@('family','transaction','relation','knowledge','entry','reference','ledger','prune','shape')}
                foreach($name in $names){
                    $rows=@($result.cases | Where-Object {$_.kind -ceq $kind -and $_.locale -ceq $locale -and $(if($kind -eq 'scope'){$_.scenario}else{$_.field}) -ceq $name})
                    Check ($rows.Count -eq 1 -and $rows[0].passed) ('Scope/payload coordinate '+$locale+':'+$kind+':'+$name)
                }
            }
        }
    }
}
function Corpus($receipt){
    Check ($receipt.source_unchanged -and $receipt.source_corpus.file_count -eq 265 -and @($receipt.source_corpus.rows).Count -eq 265) 'Product corpus denominator'
    $paths=@()
    foreach($row in $receipt.source_corpus.rows){
        $parts=$row.Split("`t")
        Check ($parts.Count -eq 2 -and $parts[0].StartsWith('scripts/') -and -not $parts[0].Contains('..') -and $parts[1] -cmatch '^[0-9a-f]{64}$') 'Unsafe corpus path/hash'
        $paths+=$parts[0]
        Check ((Hash (Join-Path $repo ('game/'+$parts[0]))) -ceq $parts[1]) ('Mixed product source '+$parts[0])
    }
    Check (@($paths | Select-Object -Unique).Count -eq 265) 'Duplicate corpus path'
}
$manifest=Json (Join-Path $root 'manifest.json')
$actual=@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')} | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
Check ($actual.Count -eq @($manifest.files).Count -and @($manifest.files.path | Select-Object -Unique).Count -eq $actual.Count -and @(Compare-Object $actual @($manifest.files.path)).Count -eq 0) 'Manifest completeness'
foreach($row in $manifest.files){
    Check ($row.path -is [string] -and -not $row.path.Contains('..') -and -not $row.path.Contains('\')) 'Manifest path'
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Check ($path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)) 'Manifest escape'
    Check ((Hash $path) -ceq $row.sha256 -and (Get-Item -LiteralPath $path).Length -eq $row.bytes) 'Evidence changed'
}
$source=Json (Join-Path $root 'source.json')
Check ($source.head -ceq '20d442fe2caa25594d9e86b92f3759c74ea85a65' -and @($source.files).Count -eq 7) 'Baseline/source denominator'
foreach($row in $source.files){
    Check ((Hash (Join-Path $repo $row.path)) -ceq $row.candidate_sha256 -and (Hash (Join-Path $root ('baseline/'+$row.path))) -ceq $row.baseline_sha256) 'Before/after source mismatch'
}
$results=@{}
foreach($name in @('session','ui','reset-focused','reset-ui','reset-foundation','migration','host','history')){
    $dir=Join-Path $root ('final-'+$name)
    $stem=if($name -in @('migration','host')){$name}elseif($name -eq 'history'){'focused'}else{'run'}
    $receipt=Json (Join-Path $dir ($stem+$(if($stem -eq 'run'){'.json'}else{'.run.json'})))
    Check ($receipt.completed -and $receipt.exit_code -eq 0 -and [DateTime]$receipt.finished_utc -gt [DateTime]$receipt.started_utc) 'Native completion'
    Check ($receipt.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $receipt.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Engine fingerprint'
    Corpus $receipt
    $stdout=Join-Path $dir ($stem+'.out.log');$stderr=Join-Path $dir ($stem+'.err.log')
    Check ((Hash $stdout) -ceq $receipt.stdout_sha256 -and (Hash $stderr) -ceq $receipt.stderr_sha256) 'Log fingerprint'
    Check (-not (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|resources still in use|ObjectDB instances leaked' -Quiet)) 'Native/script/resource error'
    $runner=switch($name){ {$_ -in @('session','ui')}{'run_notebook_campaign_sleep_audit.ps1'} {$_ -like 'reset-*'}{'run_notebook_reset_async_audit.ps1'} {$_ -in @('migration','host')}{'run_notebook_save_preflight_audit.ps1'} 'history'{'run_notebook_history_async_audit.ps1'} }
    Check ((Hash (Join-Path $PSScriptRoot $runner)) -ceq $receipt.runner_sha256) 'Executed runner differs'
    foreach($harness in $receipt.harnesses){Check ((Hash (Join-Path $dir $harness.name)) -ceq $harness.sha256) 'Executed harness differs'}
    if($name -eq 'history'){
        Check ((Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.gd')) -ceq $receipt.harness_sha256 -and (Hash (Join-Path $PSScriptRoot 'tests/notebook_history_async_audit.tscn')) -ceq $receipt.scene_sha256) 'History harness fingerprint'
    }
    $marker=switch($name){'session'{'CAMPAIGN_SLEEP_SMOKE:PASS'}'ui'{'CAMPAIGN_SLEEP_UI_SMOKE:PASS'}'reset-focused'{'RESET_ASYNC_SMOKE:PASS'}'reset-ui'{'RESET_UI_SMOKE:PASS'}'reset-foundation'{'FOUNDATION_SMOKE: PASS'}'migration'{'NOTEBOOK_MIGRATION_SMOKE: PASS'}'host'{'NOTEBOOK_HOST_SMOKE: PASS'}'history'{'HISTORY_ASYNC_SMOKE:PASS'}}
    Check (@(Get-Content -LiteralPath $stdout | Where-Object {$_ -ceq $marker}).Count -eq 1) 'Missing/ambiguous terminal marker'
    if($name -in @('session','ui')){
        $prefix=if($name -eq 'ui'){'CAMPAIGN_SLEEP_UI_AUDIT: '}else{'CAMPAIGN_SLEEP_AUDIT: '}
        $lines=@(Get-Content -LiteralPath $stdout | Where-Object {$_.StartsWith($prefix)})
        Check ($lines.Count -eq 1) 'Ambiguous result'
        $result=$lines[0].Substring($prefix.Length) | ConvertFrom-Json
        Coordinates $result $name
        $results[$name]=$result
    }
    if($name -in @('reset-focused','reset-ui','history')){
        $prefix=switch($name){'reset-focused'{'RESET_ASYNC_AUDIT: '}'reset-ui'{'RESET_UI_AUDIT: '}'history'{'HISTORY_ASYNC_AUDIT: '}}
        $count=switch($name){'reset-focused'{136}'reset-ui'{16}'history'{72}}
        $lines=@(Get-Content -LiteralPath $stdout | Where-Object {$_.StartsWith($prefix)})
        Check ($lines.Count -eq 1) 'Regression summary missing'
        $result=$lines[0].Substring($prefix.Length) | ConvertFrom-Json
        Check ($result.ok -and @($result.errors).Count -eq 0 -and $result.required_cases -eq $count -and @($result.cases).Count -eq $count -and @($result.cases | Where-Object {-not $_.passed}).Count -eq 0) 'Regression case denominator/result'
    }
}
$rejected=0
if($SelfTest){
    foreach($name in @('duplicate','missing','false','reset-count','wake-count','locale')){
        $changed=($results.session | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        switch($name){
            'duplicate'{$changed.cases[1]=$changed.cases[0]}
            'missing'{$changed.cases=@($changed.cases | Select-Object -Skip 1)}
            'false'{$changed.cases[0].passed=$false}
            'reset-count'{$changed.cases[0].worker_kinds=@('wake')}
            'wake-count'{$changed.cases[0].worker_kinds+=@('wake')}
            'locale'{$changed.cases[0].locale='unexpected'}
        }
        $failed=$false
        try{Coordinates $changed 'session'}catch{$failed=$true}
        Check $failed ('Auditor accepted mutation '+$name)
        $rejected++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;native_runs=8;session_cases=$results.session.cases.Count;ui_cases=$results.ui.cases.Count;mutation_rejects=$rejected;scope='Fixed source and headless local contracts, not OS/cross-process/performance acceptance'} | ConvertTo-Json
