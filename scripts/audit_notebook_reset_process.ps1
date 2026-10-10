param([Parameter(Mandatory)][string]$EvidencePath,[string]$RepoPath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
if(Test-Path -LiteralPath (Join-Path $root 'bundle.zip')){
    $bundle=Join-Path $root 'bundle.zip'
    $seal=Get-Content -LiteralPath (Join-Path $root 'bundle.json') -Raw | ConvertFrom-Json
    if((Get-FileHash -LiteralPath $bundle).Hash.ToLowerInvariant() -cne $seal.sha256 -or (Get-Item -LiteralPath $bundle).Length -ne $seal.bytes){throw 'Sealed bundle differs'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $extract=Join-Path ([IO.Path]::GetTempPath()) ('ggb-reset-process-proof-'+[guid]::NewGuid().ToString('N'))
    [IO.Compression.ZipFile]::ExtractToDirectory($bundle,$extract,[Text.Encoding]::UTF8)
    $root=$extract
}
$checks=0
$engineSha='ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
function Assert-True([bool]$Value,[string]$Label){$script:checks++;if(-not $Value){throw $Label}}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable}
function Number($Value){$Value -is [int] -or $Value -is [long] -or $Value -is [double]}
function Same($Left,$Right){
    if($Left -is [System.Collections.IDictionary]){
        if($Right -isnot [System.Collections.IDictionary] -or $Left.Count -ne $Right.Count){return $false}
        $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($key in $Right.Keys){[void]$keys.Add([string]$key)}
        foreach($key in $Left.Keys){if(-not $keys.Contains([string]$key) -or -not (Same $Left[$key] $Right[$key])){return $false}}
        return $true
    }
    if($Left -is [array]){
        if($Right -isnot [array] -or $Left.Count -ne $Right.Count){return $false}
        for($i=0;$i -lt $Left.Count;$i++){if(-not (Same $Left[$i] $Right[$i])){return $false}}
        return $true
    }
    if($null -eq $Left -or $null -eq $Right){return $null -eq $Left -and $null -eq $Right}
    if(Number $Left){
        if(-not (Number $Right)){return $false}
        if([double]::IsNaN([double]$Left) -or [double]::IsInfinity([double]$Left) -or [double]::IsNaN([double]$Right) -or [double]::IsInfinity([double]$Right)){return $false}
        # JSON may change an integral value's type, never its exact value.
        if(($Left -is [double]) -ne ($Right -is [double])){
            if([math]::Abs([double]$Left) -ge 9007199254740992 -or [math]::Abs([double]$Right) -ge 9007199254740992){return $false}
        }
        if($Left -is [double] -or $Right -is [double]){return [double]$Left -ceq [double]$Right}
        return [long]$Left -ceq [long]$Right
    }
    if($Left -is [bool]){return $Right -is [bool] -and $Left -ceq $Right}
    if($Left -is [string]){return $Right -is [string] -and [string]::Equals($Left,$Right,[StringComparison]::Ordinal)}
    return $false
}
function Corpus-Map($Rows){
    $map=@{}
    foreach($row in $Rows){
        $parts=$row.Split("`t")
        Assert-True ($parts.Count -eq 2 -and -not $map.ContainsKey($parts[0])) 'Invalid product source row'
        Assert-True ($parts[0].StartsWith('scripts/') -and $parts[0].EndsWith('.gd') -and $parts[0] -notmatch '(^|/)\.\.(/|$)|\\|:' -and $parts[1] -cmatch '^[0-9a-f]{64}$') 'Unsafe product source identity'
        $map[$parts[0]]=$parts[1]
    }
    return $map
}
$phases=@('sleep_confirmed','player_committed','memory_committed','physical_reset_complete','morning_loaded','route_selected','complete','idle')
function Check-Chain($Coordinate,$Seed,$Resume,$Verify,$Cut,$ResumeDetails,$VerifyDetails,$Resumed,$Verified){
    Assert-True ($Cut.phase -ceq $Coordinate.point -and $Cut.cut -ceq $Coordinate.cut) 'Actual cut boundary differs'
    foreach($receipt in @($Seed,$Resume,$Verify)){
        Assert-True ($receipt.ok -and $receipt.completed -and $receipt.source_unchanged -and $receipt.route -ceq $Coordinate.route -and $receipt.point -ceq $Coordinate.point -and $receipt.cut -ceq $Coordinate.cut) 'Process coordinate/receipt invalid'
    }
    Assert-True ($Seed.phase -ceq 'seed' -and $Seed.terminated_by_runner -and $null -ne $Seed.exit_code -and $Seed.exit_code -ne 0 -and $Cut.ok -and @($Cut.errors).Count -eq 0 -and $Cut.pid -eq $Seed.pid) 'Seed must be an intentional real child termination, not native PASS'
    Assert-True ($Resume.phase -ceq 'resume' -and $Verify.phase -ceq 'verify' -and -not $Resume.terminated_by_runner -and -not $Verify.terminated_by_runner -and $null -ne $Resume.exit_code -and $null -ne $Verify.exit_code -and $Resume.exit_code -eq 0 -and $Verify.exit_code -eq 0) 'Recovery native exits invalid'
    Assert-True ([DateTime]$Seed.finished_utc -lt [DateTime]$Resume.started_utc -and [DateTime]$Resume.finished_utc -lt [DateTime]$Verify.started_utc) 'Independent sequential process lifetimes required'
    Assert-True ($Seed.pid -eq $Cut.pid -and $Resume.pid -eq $ResumeDetails.pid -and $Verify.pid -eq $VerifyDetails.pid) 'Process receipt identities differ'
    Assert-True ($Seed.locale -ceq $Coordinate.locale -and $Verify.locale -ceq $Coordinate.locale -and $Resume.locale -ceq $(if($Coordinate.locale -eq 'ko_KR'){'en_US'}else{'ko_KR'})) 'Cross-language process order invalid'
    if($Coordinate.point -cne 'wake'){
        Assert-True ($Cut.candidate.reset_state.phase -ceq $Coordinate.point) 'Actual prepared reset phase differs'
        if($Coordinate.cut -ceq 'promoted'){Assert-True (Same $Cut.candidate $Cut.snapshot) 'Actual promoted candidate differs from durable main'}
        else{Assert-True ($Coordinate.point -ceq 'physical_reset_complete' -and $Cut.snapshot.reset_state.phase -ceq 'memory_committed' -and [int]$Cut.candidate.loop_state.day_index -eq [int]$Cut.snapshot.loop_state.day_index+1) 'Prepared physical candidate was prematurely installed'}
    }
    $day=[int]$Cut.baseline.loop_state.day_index + $(if($Coordinate.route -eq 'rest'){0}else{1})
    Assert-True ($ResumeDetails.day_after -eq $day -and $VerifyDetails.day_after -eq $day -and $Resumed.loop_state.day_index -eq $day -and $Verified.loop_state.day_index -eq $day) 'Reset repeated/physical day incorrect'
    Assert-True ($ResumeDetails.phase_after -ceq 'idle' -and $VerifyDetails.phase_after -ceq 'idle' -and $Resumed.reset_state.phase -ceq 'idle' -and $Verified.reset_state.phase -ceq 'idle') 'Incomplete reset recovery'
    $expected=@()
    if($Cut.snapshot.reset_state.phase -cne 'idle'){
        $index=[array]::IndexOf($script:phases,$Cut.snapshot.reset_state.phase)
        Assert-True ($index -ge 0) 'Unknown durable phase'
        $expected=@($script:phases | Select-Object -Skip ($index+1))
    }
    Assert-True (Same @($ResumeDetails.reset_events) $expected) 'Resume repeated/skipped durable phase'
    Assert-True (@($VerifyDetails.reset_events).Count -eq 0) 'Second process repeated reset'
    Assert-True (Same $Resumed $Verified) 'Second process altered completed gameplay snapshot'
    Assert-True ($ResumeDetails.reset_receipt -ceq $VerifyDetails.reset_receipt -and $ResumeDetails.reset_receipt -ceq $Resumed.reset_state.last_completed_transaction_id) 'Reset receipt repeated or changed'
    foreach($before in @($Cut.baseline,$Cut.snapshot)){
        Assert-True (Same $before.meta_progress.servants $Resumed.meta_progress.servants) 'Relationship/residual memory changed'
        $old=$before.meta_progress.dialogue_history
        $next=$Resumed.meta_progress.dialogue_history
        foreach($key in @('source_origin_id','branch_id','bookmarks','comparison')){Assert-True (Same $old[$key] $next[$key]) ('Archive identity/ref changed '+$key)}
        $indexed=@{}
        foreach($entry in $next.entries){Assert-True (-not $indexed.ContainsKey($entry.entry_uid)) 'Duplicate entry identity';$indexed[$entry.entry_uid]=$entry}
        foreach($entry in $old.entries){Assert-True ($indexed.ContainsKey($entry.entry_uid) -and (Same $entry $indexed[$entry.entry_uid])) 'Past original changed/lost'}
        foreach($key in $before.meta_progress.knowledge_entries.Keys){
            if($key -ceq 'chapter_notebook'){
                $oldNotes=$before.meta_progress.knowledge_entries[$key]
                $newNotes=$Resumed.meta_progress.knowledge_entries[$key]
                foreach($note in $oldNotes.Keys){Assert-True (Same $oldNotes[$note] $newNotes[$note]) ('Old projected note changed '+$note)}
                foreach($note in $newNotes.Keys){if(-not $oldNotes.ContainsKey($note)){Assert-True ($note -ceq 'NOTE_E1_WAKE' -and $Coordinate.route -in @('bedroom','capsule') -and $newNotes[$note] -ceq '같은 아침이어야 한다.') 'Unrelated projected note added'}}
            }else{Assert-True (Same $before.meta_progress.knowledge_entries[$key] $Resumed.meta_progress.knowledge_entries[$key]) ('Old knowledge changed '+$key)}
        }
    }
    if($Coordinate.route -eq 'p6'){
        Assert-True ($Cut.baseline.meta_progress.knowledge_entries.PROLOGUE_FIRST_WAKE_REQUIRED -ne $true -and $Cut.snapshot.meta_progress.knowledge_entries.PROLOGUE_FIRST_WAKE_REQUIRED -eq $true -and $Resumed.meta_progress.knowledge_entries.PROLOGUE_FIRST_WAKE_COMPLETED -eq $true) 'Actual P6 first-wake provenance/handoff missing'
        $observed=@($Resumed.meta_progress.dialogue_history.entries | Where-Object {$_.record_class -ceq 'authored'} | ForEach-Object {$_.observation.content_id})
        foreach($id in @('NB_PR_R1_WAKE','NB_PR_R1_SAME','NB_PR_R1_NOTES')){Assert-True (($observed | Where-Object {$_ -ceq $id}).Count -eq 1) ('Initial wake skipped/duplicated '+$id)}
    }
    if($Coordinate.route -in @('bedroom','capsule','rest')){Assert-True ($Resumed.fracture_state.broken_reset_triggered -and $Resumed.meta_progress.knowledge_entries.E1_wake_seen) 'Broken wake disclosure missing'}
}
$manifest=Read-Json (Join-Path $root 'manifest.json')
$listed=@{}
foreach($row in $manifest.files){
    $path=[IO.Path]::GetFullPath((Join-Path $root $row.path))
    Assert-True ($path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and -not $listed.ContainsKey($row.path)) 'Unsafe evidence path'
    $listed[$row.path]=$true
    Assert-True ((Get-Item -LiteralPath $path).Length -eq $row.bytes -and (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ceq $row.sha256) ('Evidence digest '+$row.path)
}
Assert-True (@(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.FullName -cne (Join-Path $root 'manifest.json')}).Count -eq $listed.Count) 'Evidence inventory differs'
$matrix=Read-Json (Join-Path $root 'all/batch.json')
Assert-True ($matrix.ok -and $matrix.matrix -ceq 'all' -and @($matrix.completed).Count -eq 132 -and @($matrix.expected).Count -eq 132) 'Full 132-chain matrix incomplete'
$expected=@{}
foreach($route in @('p6','chapter','mirror','basement','bedroom','capsule')){foreach($locale in @('ko_KR','en_US')){
    foreach($point in $phases){$expected[$route+'-'+$point+'-promoted-'+$locale]=$true}
    $expected[$route+'-physical_reset_complete-prepared-'+$locale]=$true
}}
foreach($route in @('chapter','mirror','basement','bedroom','capsule','rest')){foreach($locale in @('ko_KR','en_US')){foreach($cut in @('prepared','promoted')){$expected[$route+'-wake-'+$cut+'-'+$locale]=$true}}}
$seen=@{}
$corpus=$null
$assertions=0
foreach($case in $matrix.completed){
    Assert-True ($expected.ContainsKey($case.name) -and -not $seen.ContainsKey($case.name)) 'Missing/duplicate process coordinate'
    Assert-True ($case.name -ceq ($case.row.route+'-'+$case.row.point+'-'+$case.row.cut+'-'+$case.row.locale)) 'Matrix name/actual coordinate differs'
    $seen[$case.name]=$true
    $path=Join-Path $root ('all/'+$case.name)
    $receipts=@{}
    foreach($phase in @('seed','resume','verify')){
        $receipt=Read-Json ($path+'/'+$phase+'/run.json')
        $receipts[$phase]=$receipt
        Assert-True ($receipt.engine_sha256 -ceq $engineSha) 'Unexpected candidate runtime'
        Assert-True ((Get-FileHash -LiteralPath ($path+'/case/cut.json')).Hash.ToLowerInvariant() -ceq $receipt.cut_sha256) 'Cut receipt changed between processes'
        if($null -eq $corpus){$corpus=Corpus-Map $receipt.source_corpus.rows}
        Assert-True (Same $receipt.source_corpus.rows @($corpus.Keys | Sort-Object | ForEach-Object {$_+"`t"+$corpus[$_]})) 'Product sources differ between processes'
        Assert-True ((Get-FileHash -LiteralPath ($path+'/'+$phase+'/run.out.log')).Hash.ToLowerInvariant() -ceq $receipt.stdout_sha256 -and (Get-FileHash -LiteralPath ($path+'/'+$phase+'/run.err.log')).Hash.ToLowerInvariant() -ceq $receipt.stderr_sha256) 'Process log receipt differs'
        foreach($harness in $receipt.harnesses){Assert-True ((Get-FileHash -LiteralPath (Join-Path $root ('harnesses/'+$harness.sha256+'_'+$harness.name))).Hash.ToLowerInvariant() -ceq $harness.sha256) 'Executed harness digest differs'}
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root ('harnesses/'+$receipt.runner_sha256+'_runner.ps1'))).Hash.ToLowerInvariant() -ceq $receipt.runner_sha256) 'Executed runner digest differs'
        Assert-True (-not (Select-String -LiteralPath ($path+'/'+$phase+'/run.out.log'),($path+'/'+$phase+'/run.err.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet)) 'Process script/leak warning'
        if($phase -ne 'seed'){
            $result=Read-Json ($path+'/'+$phase+'/run.result.json')
            Assert-True ($result.ok -and @($result.errors).Count -eq 0 -and $result.phase -ceq $phase) 'Recovery assertions failed'
            $printed=@(Get-Content -LiteralPath ($path+'/'+$phase+'/run.out.log') | Where-Object {$_.StartsWith('RESET_PROCESS_AUDIT: ')})
            Assert-True ($printed.Count -eq 1 -and (Same $result ($printed[0].Substring('RESET_PROCESS_AUDIT: '.Length) | ConvertFrom-Json -AsHashtable))) 'Recovery result differs from native output'
            Assert-True ((Get-FileHash -LiteralPath ($path+'/case/'+$phase+'_details.json')).Hash.ToLowerInvariant() -ceq $receipt.details_sha256 -and (Get-FileHash -LiteralPath ($path+'/case/resumed_snapshot.json')).Hash.ToLowerInvariant() -ceq $receipt.resumed_sha256) 'Recovery detail/snapshot receipt differs'
            Assert-True (@(Get-Content -LiteralPath ($path+'/'+$phase+'/run.out.log') | Where-Object {$_ -ceq 'RESET_PROCESS_SMOKE:PASS'}).Count -eq 1) 'Exact native PASS missing'
            $assertions+=$result.checks
        }
    }
    $cut=Read-Json ($path+'/case/cut.json')
    $rd=Read-Json ($path+'/case/resume_details.json')
    $vd=Read-Json ($path+'/case/verify_details.json')
    $resumed=Read-Json ($path+'/case/resumed_snapshot.json')
    $verified=Read-Json ($path+'/case/verified_snapshot.json')
    Check-Chain $case.row $receipts.seed $receipts.resume $receipts.verify $cut $rd $vd $resumed $verified
}
Assert-True ($seen.Count -eq $expected.Count -and $corpus.Count -eq 265) 'Independent denominator/source count differs'
if($RepoPath){foreach($path in $corpus.Keys){Assert-True ((Get-FileHash -LiteralPath (Join-Path $RepoPath ('game/'+$path))).Hash.ToLowerInvariant() -ceq $corpus[$path]) ('Repository product differs '+$path)}}
$baselineRun=Read-Json (Join-Path $root 'probe/resume/run.json')
Assert-True ($baselineRun.completed -and $baselineRun.exit_code -eq 1 -and -not $baselineRun.terminated_by_runner) 'Historical R1 failure native result differs'
$baselineLines=@(Get-Content -LiteralPath (Join-Path $root 'probe/resume/run.out.log') | Where-Object {$_.StartsWith('RESET_PROCESS_AUDIT: ')})
Assert-True ($baselineLines.Count -eq 1) 'Historical R1 failure summary missing'
$baseline=$baselineLines[0].Substring('RESET_PROCESS_AUDIT: '.Length) | ConvertFrom-Json -AsHashtable
Assert-True (-not $baseline.ok -and @($baseline.errors).Count -eq 1 -and $baseline.errors[0] -ceq 'first P6 cold recovery must restore unobserved R1 instead of skipping into campaign') 'Historical R1 skip missing'
$old=Corpus-Map (Read-Json (Join-Path $root 'probe/seed/run.json')).source_corpus.rows
$changed=@('scripts/systems/bootstrap.gd','scripts/systems/notebook_presentation.gd','scripts/systems/prologue_save_candidate.gd')
foreach($path in $corpus.Keys){Assert-True (($old[$path] -cne $corpus[$path]) -eq ($path -in $changed)) ('Unexpected product delta '+$path)}
$regressionRuns=0
foreach($label in @('retained-reset-ui','retained-reset-foundation','retained-prologue','retained-choice','retained-surface','retained-natural','retained-owner','retained-migration','retained-presentation')){
    $directory=Join-Path $root $label
    $receipts=@(Get-ChildItem -LiteralPath $directory -File | Where-Object {$_.Name -ceq 'run.json' -or $_.Name -clike '*.run.json'})
    Assert-True ($receipts.Count -eq 1) ('Ambiguous regression receipt '+$label)
    $receipt=Read-Json $receipts[0].FullName
    Assert-True ($receipt.completed -and $null -ne $receipt.exit_code -and $receipt.exit_code -eq 0) ('Regression native failure '+$label)
    Assert-True ($receipt.engine_sha256 -ceq $engineSha) ('Regression engine differs '+$label)
    if($receipt.ContainsKey('source_unchanged')){Assert-True $receipt.source_unchanged ('Regression source changed '+$label)}
    foreach($harness in $receipt.harnesses){
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root ('harnesses/'+$harness.sha256+'_'+$harness.name))).Hash.ToLowerInvariant() -ceq $harness.sha256) ('Regression harness digest differs '+$label)
    }
    foreach($field in @('base_harness_sha256','parent_harness_sha256','harness_sha256','scene_sha256')){
        if($receipt.ContainsKey($field)){
            if($label -ceq 'retained-migration' -and $field -ceq 'harness_sha256'){
                Assert-True ($receipt.mode -ceq 'migration' -and $null -eq $receipt[$field] -and $corpus.ContainsKey('scripts/tests/notebook_migration_smoke.gd')) 'Built-in migration provenance differs'
                continue
            }
            $captured=@(Get-ChildItem -LiteralPath (Join-Path $root 'harnesses') -File -Filter ($receipt[$field]+'_*'))
            Assert-True ($captured.Count -gt 0 -and @($captured | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -cne $receipt[$field]}).Count -eq 0) ('Regression captured harness missing '+$label+'/'+$field)
        }
    }
    if($receipt.ContainsKey('runner_sha256')){
        $captured=@(Get-ChildItem -LiteralPath (Join-Path $root 'regression-replay') -File | Where-Object {(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() -ceq $receipt.runner_sha256})
        Assert-True ($captured.Count -eq 1) ('Regression captured runner missing '+$label)
    }
    Assert-True (Same $receipt.source_corpus.rows @($corpus.Keys | Sort-Object | ForEach-Object {$_+"`t"+$corpus[$_]})) ('Regression source differs '+$label)
    $out=@(Get-ChildItem -LiteralPath $directory -File -Filter '*.out.log')
    $err=@(Get-ChildItem -LiteralPath $directory -File -Filter '*.err.log')
    Assert-True ($out.Count -eq 1 -and $err.Count -eq 1) ('Ambiguous regression logs '+$label)
    Assert-True ((Get-FileHash -LiteralPath $out[0].FullName).Hash.ToLowerInvariant() -ceq $receipt.stdout_sha256 -and (Get-FileHash -LiteralPath $err[0].FullName).Hash.ToLowerInvariant() -ceq $receipt.stderr_sha256) ('Regression log digest differs '+$label)
    Assert-True (-not (Select-String -LiteralPath $out[0].FullName,$err[0].FullName -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet)) ('Regression script/leak error '+$label)
    $lines=@(Get-Content -LiteralPath $out[0].FullName)
    $marker=switch($label){
        'retained-reset-ui'{'RESET_UI_SMOKE:PASS'}
        'retained-reset-foundation'{'FOUNDATION_SMOKE: PASS'}
        'retained-prologue'{'PROLOGUE_ASYNC_SMOKE:PASS'}
        'retained-choice'{'PROLOGUE_CHOICE_ASYNC_SMOKE:PASS'}
        'retained-surface'{'PROLOGUE_SURFACE_ASYNC_SMOKE:PASS'}
        'retained-natural'{'PROLOGUE_NATURAL_ASYNC_SMOKE:PASS'}
        'retained-owner'{'RESET_OWNER_SMOKE:PASS'}
        'retained-migration'{'NOTEBOOK_MIGRATION_SMOKE: PASS'}
        'retained-presentation'{'NOTEBOOK_PROLOGUE_PRESENTATION_SMOKE: PASS'}
    }
    Assert-True (@($lines | Where-Object {$_ -ceq $marker}).Count -eq 1) ('Exact regression PASS missing '+$label)
    $spec=switch($label){
        'retained-reset-ui'{@{prefix='RESET_UI_AUDIT: ';cases=16}}
        'retained-prologue'{@{prefix='PROLOGUE_ASYNC_AUDIT: ';cases=42}}
        'retained-choice'{@{prefix='PROLOGUE_CHOICE_ASYNC_AUDIT: ';cases=152}}
        'retained-surface'{@{prefix='PROLOGUE_SURFACE_ASYNC_AUDIT: ';cases=54}}
        'retained-natural'{@{prefix='PROLOGUE_NATURAL_ASYNC_AUDIT: ';cases=64}}
        'retained-owner'{@{prefix='RESET_OWNER_AUDIT: ';cases=136}}
        default{$null}
    }
    if($null -ne $spec){
        $summary=@($lines | Where-Object {$_.StartsWith($spec.prefix)})
        Assert-True ($summary.Count -eq 1) ('Ambiguous regression summary '+$label)
        $result=$summary[0].Substring($spec.prefix.Length) | ConvertFrom-Json -AsHashtable
        Assert-True ($result.ok -and @($result.errors).Count -eq 0 -and $result.required_cases -eq $spec.cases -and @($result.cases).Count -eq $spec.cases -and @($result.cases | Where-Object {-not $_.passed}).Count -eq 0) ('Regression denominator/assertions differ '+$label)
    }
    if($label -ceq 'retained-migration'){Assert-True (@($lines | Where-Object {$_ -ceq 'NOTEBOOK_SAVE_SAFETY_CHECKS: 381'}).Count -eq 1) 'Migration safety denominator differs'}
    if($label -ceq 'retained-reset-foundation'){Assert-True (@($lines | Where-Object {$_ -ceq 'RESET_ACKNOWLEDGEMENT_CASES: 20'}).Count -eq 1) 'Foundation ACK denominator differs'}
    $regressionRuns++
}
$beforeFixture=Read-Json (Join-Path $root 'before-prologue-fixture/focused.run.json')
Assert-True ($beforeFixture.completed -and $beforeFixture.exit_code -eq 1 -and (Select-String -LiteralPath (Join-Path $root 'before-prologue-fixture/focused.err.log') -Pattern "Invalid access to property or key 'snapshot'" -Quiet)) 'Original fixture failure not retained'
$mutations=0
$valueComparisons=0
if($SelfTest){
    foreach($pair in @(
        @{a=[long]90;b=[double]90;equal=$true},@{a=[long]0;b=[double]0;equal=$true},
        @{a=[long]2;b=[double]1.5;equal=$false},@{a=$true;b=1;equal=$false},
        @{a=$null;b=0;equal=$false},@{a='90';b=90;equal=$false},
        @{a=[double]::NaN;b=[double]::NaN;equal=$false},
        @{a=[long]9007199254740992;b=[double]9007199254740992;equal=$false},
        @{a='original';b='Original';equal=$false},
        @{a=@{value=1};b=@{Value=1};equal=$false},
        @{a=[double]1.5;b=[double]1.5;equal=$true},
        @{a=[double]1.5;b=[double]1.500001;equal=$false},
        @{a=[string][char]0xE9;b=('e'+[char]0x301);equal=$false},
        @{a=@{([string][char]0xE9)=1};b=@{('e'+[char]0x301)=1};equal=$false}
    )){
        Assert-True ((Same $pair.a $pair.b) -eq $pair.equal) 'Exact persisted-value comparison failed'
        $valueComparisons++
    }
    $last=$matrix.completed[-1]
    $p=Join-Path $root ('all/'+$last.name)
    $seed=Read-Json ($p+'/seed/run.json');$resume=Read-Json ($p+'/resume/run.json');$verify=Read-Json ($p+'/verify/run.json');$cut=Read-Json ($p+'/case/cut.json')
    $rd=Read-Json ($p+'/case/resume_details.json');$vd=Read-Json ($p+'/case/verify_details.json');$rs=Read-Json ($p+'/case/resumed_snapshot.json');$vs=Read-Json ($p+'/case/verified_snapshot.json')
    foreach($fault in @('null_exit','fake_seed','same_lifetime','repeated_day','relation','original')){
        $s=Read-Json ($p+'/seed/run.json');$r=Read-Json ($p+'/resume/run.json');$v=Read-Json ($p+'/verify/run.json');$after=Read-Json ($p+'/case/resumed_snapshot.json')
        switch($fault){
            'null_exit'{$r.exit_code=$null}
            'fake_seed'{$s.exit_code=0}
            'same_lifetime'{$r.started_utc=$s.started_utc}
            'repeated_day'{$after.loop_state.day_index+=1}
            'relation'{$after.meta_progress.servants.edgar.bond+=1}
            'original'{$after.meta_progress.dialogue_history.entries[0].entry_uid='replaced'}
        }
        $rejected=$false
        try{Check-Chain $last.row $s $r $v $cut $rd $vd $after $vs}catch{$rejected=$true}
        Assert-True $rejected ('Invalid evidence accepted '+$fault)
        $mutations++
    }
}
[pscustomobject]@{ok=$true;checks=$checks;chains=$seen.Count;intentional_terminations=132;normal_native_zero=264;recovery_assertions=$assertions;rejected_mutations=$mutations;value_comparisons=$valueComparisons;product_sources=$corpus.Count;regression_runs=$regressionRuns}|ConvertTo-Json
