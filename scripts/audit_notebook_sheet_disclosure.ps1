#requires -Version 7.2
param([Parameter(Mandatory)][string]$EvidencePath,[Parameter(Mandatory)][string]$RepoPath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path;$repo=(Resolve-Path -LiteralPath $RepoPath).Path;$checks=0
function Check([bool]$Value,[string]$Message){$script:checks++;if(-not $Value){throw $Message}}
function Json([string]$Path){
    $value=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) -AsHashtable -Depth 100
    Check ($value -is [Collections.IDictionary]) "JSON object required: $Path"
    return $value
}
function Is-True($Value){$Value -is [bool] -and $Value}
function Is-Int($Value){$Value -is [long] -or $Value -is [int] -or $Value -is [bigint]}
function Get-Value($Map,[string]$Key,$Default){
    if($Map -is [Collections.IDictionary] -and $Map.Contains($Key)){return ,$Map[$Key]}
    return ,$Default
}
function Rows($A,$B){@($A).Count -eq @($B).Count -and [string]::Join("`n",@($A)) -ceq [string]::Join("`n",@($B))}
function Canon($Value){
    if($null -eq $Value){return 'null'}
    if($Value -is [Collections.IDictionary]){
        [string[]]$keys=@($Value.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
        return '{'+[string]::Join(',',@($keys|ForEach-Object {($_|ConvertTo-Json -Compress)+':'+(Canon $Value[$_])}))+'}'
    }
    if($Value -is [array]){return '['+[string]::Join(',',@($Value|ForEach-Object {Canon $_}))+']'}
    if($Value -is [bool]){return 'b:'+([string]$Value).ToLowerInvariant()}
    if($Value -is [ValueType]){return 'n:'+([decimal]$Value).ToString('G29',[Globalization.CultureInfo]::InvariantCulture)}
    return 's:'+($Value|ConvertTo-Json -Compress)
}
function Hash-Text([string]$Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()}
function Check-SnapshotShape($State){
    $sections=@{
        meta_progress=@('notebook_persistence_confirmed','journal_stage','knowledge_entries','failure_knowledge','event_history','dialogue_history','servants')
        loop_state=@('day_index','location_id','time_block','inventory','physical_changes','event_local_states','shortcut_context')
        fracture_state=@('broken_reset_triggered','camouflage_filter','world_phase','servant_events_completed','researcher_records','mandatory_e1_observations')
        reset_state=@('phase','reset_type','transaction_id','last_completed_transaction_id','player_commit_complete','memory_commit_complete','physical_reset_complete','route_snapshot_id','pending_reactions_snapshot')
        ending_run=@('final_decision','selected_ending','reselect_used')
    }
    Check ($State -is [Collections.IDictionary] -and $State.Count -eq 5) 'Full five-section snapshot required'
    foreach($section in $sections.Keys){
        Check ($State[$section] -is [Collections.IDictionary]) "Snapshot section missing: $section"
        foreach($key in $sections[$section]){Check ($State[$section].Contains($key)) "Snapshot field missing: $section.$key"}
        if($section -cne 'meta_progress'){Check ($State[$section].Count -eq $sections[$section].Count) "Unexpected snapshot fields: $section"}
    }
    Check ((Is-True $State.meta_progress.notebook_persistence_confirmed) -and (Is-Int $State.meta_progress.journal_stage)) 'Invalid notebook persistence/stage'
    Check ($State.loop_state.day_index -eq 2 -and $State.loop_state.time_block -ceq 'evening_free' -and $State.loop_state.inventory -is [array]) 'Wrong native disclosure fixture'
}
function Check-Case($Doc,[bool]$Success,[switch]$Original){
    Check ($Doc.case -is [string] -and $Doc.case -cmatch '^(c5_(minimal|all_channels|all_channels_historical_v1)|j3_(skip|read|read_historical_v1))/(ko_KR|en_US)$') 'Unknown native case'
    $state=$Doc.state;$known=$state.meta_progress.knowledge_entries;$archive=$state.meta_progress.dialogue_history
    Check ($state -is [Collections.IDictionary] -and $Doc.durable_state -is [Collections.IDictionary] -and $known -is [Collections.IDictionary] -and $archive.entries -is [array]) 'Full native/durable snapshot missing'
    Check-SnapshotShape $state
    Check ((Canon $state) -ceq (Canon $Doc.durable_state)) 'Native snapshot and durable slot differ'
    $byUid=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($entry in $archive.entries){Check ($entry.entry_uid -is [string] -and $entry.entry_uid.Length -gt 0 -and -not $byUid.ContainsKey($entry.entry_uid)) 'Missing or duplicate observation UID';$byUid.Add($entry.entry_uid,$entry)}
    if($Doc.case.StartsWith('c5_')){
        $matches=@($known.notebook_knowledge.revisions|Where-Object {$_.metadata.knowledge_id -ceq 'MIRROR_TRACING'})
        Check ($matches.Count -gt 0 -and (Is-True $known.c5_info_complete) -and (Is-True $known.C5_MIRROR_TRACING)) 'C5 did not complete'
        $tracing=$matches[-1]
        $own=Resolve-Reference $archive $byUid $tracing.observation_ref
        Check ($own.content_id -ceq 'NB_MIRROR_NOTE_C5_INFO' -and $own.content_version -eq $(if($Success){2}else{1})) 'Wrong circuit semantic version'
        $bodies=@($own.segments|Where-Object {$_.segment_id -ceq 'body'})
        Check ($bodies.Count -eq 1) 'Circuit body missing or duplicated'
        $body=$bodies[0]
        Check ($body.viewed_locale -ceq $(if($Doc.case.EndsWith('/en_US')){'en-US'}else{'ko-KR'})) 'Circuit capture locale differs'
        $expected=if($body.viewed_locale -ceq 'en-US'){'c53df11c55b292d9dfc294d53f1becdcf02e194bdac522c57cdc9510a699a9fd'}else{'04fe4d768dad72892b55e551355264c05f71efb9c366caeba1cfe9fb36a9faa1'}
        Check ((Hash-Text $body.captured_text) -ceq $expected) 'Visible circuit/channel wording changed'
        Check ($tracing.source_refs -is [array] -and $tracing.source_refs.Count -gt 0) 'Tracing sources absent'
        $sources=@();$refs=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($reference in $tracing.source_refs){
            Check ($refs.Add((Canon $reference))) 'Duplicate tracing reference'
            $sources+=(Resolve-Reference $archive $byUid $reference).content_id
        }
        Check ((Canon $tracing.observation_ref) -cin @($tracing.source_refs|ForEach-Object {Canon $_})) 'Tracing omits its own observation'
        $inspections=Get-Value $known 'c5_inspections' @()
        Check ($inspections -is [array] -and 'BODY' -cin $inspections -and 'PERSONALITY' -cin $inspections) 'Mandatory inspections disappeared'
        foreach($owner in @('EDGAR','MARA1','LUCA','IRIS','MARA2')){
            $label=@($sources|Where-Object {$_ -cin @("NB_PUZZLE_C_CHANNEL_${owner}_UNCHECKED","NB_PUZZLE_C_CHANNEL_${owner}_CHECKED")}).Count -gt 0
            Check ($label -eq $Success) 'Actual displayed label source mismatch'
            $inspected=$owner -cin $inspections
            Check ($inspected -eq (-not $Doc.case.StartsWith('c5_minimal/'))) 'Display incorrectly granted or removed an inspection'
            if($inspected){
                $spoken=@($sources|Where-Object {$_ -cin @("NB_EP02_C5_CH_${owner}_FIRST","NB_EP02_C5_CH_${owner}_REPEAT","NB_EP02_C5_HOT_${owner}_CHANNEL","NB_MIRROR_SCAN_SURFACE_${owner}","NB_MIRROR_SCAN_COPY_${owner}")}).Count -gt 0
                Check ($spoken -eq $Success) 'Actual individual channel source mismatch'
            }
        }
        if($Doc.case.Contains('historical_v1')){Check (@($archive.entries|Where-Object {$_.observation.content_id -ceq 'NB_MIRROR_NOTE_C5_INFO' -and $_.observation.content_version -eq 1}).Count -eq 1) 'Historical circuit missing or duplicated'}
    }elseif($Doc.case.StartsWith('j3_')){
        Check ($state.meta_progress.journal_stage -eq $(if($Original){2}else{3})) 'J3 restoration does not match candidate/control'
        $read=-not $Doc.case.StartsWith('j3_skip/')
        $seen=@($archive.entries|Where-Object {$_.observation.content_id -ceq 'NB_EP02_J3_MEMORY_003'}).Count -gt 0
        $effects=Get-Value $state.meta_progress.event_history 'EP02_DIALOGUE_EFFECTS' @{}
        $receipt=Get-Value $effects 'EFF_EP02_0046' $false
        Check ($seen -eq $read -and $receipt -is [bool] -and $receipt -eq $read) 'Actual memory scene/receipt does not match choice'
        $gained=(Get-Value $known 'MEM_FATHER_DRAWN_DOOR_FRAGMENT' '') -ceq 'episodic_fragment'
        $note=@($archive.entries|Where-Object {$_.observation.content_id -ceq 'NB_MIRROR_NOTE_J3_MEMORY'}).Count -gt 0
        $memoryExpected=$read -or (-not $Success -and -not $Original)
        $noteExpected=if($Original){$Doc.case.Contains('historical_v1')}else{$memoryExpected}
        Check ($gained -eq $memoryExpected -and $note -eq $noteExpected) 'Memory acquisition does not match actual observation'
        if(-not $Original){
            $journal=@($known.notebook_knowledge.revisions|Where-Object {$_.metadata.knowledge_id -ceq 'MIRROR_J3'})
            Check ($journal.Count -gt 0) 'Restored journal card missing'
            $null=Resolve-Reference $archive $byUid $journal[-1].observation_ref
        }
        if($Doc.case.Contains('historical_v1')){Check (@($archive.entries|Where-Object {$_.observation.content_id -ceq 'NB_MIRROR_NOTE_J3_MEMORY' -and $_.observation.content_version -eq 1}).Count -eq 1) 'Historical memory missing or duplicated'}
    }else{throw 'Unknown native case'}
    if($Doc.case.Contains('historical_v1')){
        $id=if($Doc.case.StartsWith('c5_')){'NB_MIRROR_NOTE_C5_INFO'}else{'NB_MIRROR_NOTE_J3_MEMORY'}
        $historical=@($archive.entries|Where-Object {$_.observation.content_id -ceq $id -and $_.observation.content_version -eq 1})
        $bodies=@($historical[0].observation.segments|Where-Object {$_.segment_id -ceq 'body'})
        Check ($bodies.Count -eq 1) 'Historical body missing or duplicated'
        $locale=if($Doc.case.EndsWith('/en_US')){'en-US'}else{'ko-KR'}
        $hash=if($id -ceq 'NB_MIRROR_NOTE_C5_INFO'){
            if($locale -ceq 'en-US'){'c53df11c55b292d9dfc294d53f1becdcf02e194bdac522c57cdc9510a699a9fd'}else{'04fe4d768dad72892b55e551355264c05f71efb9c366caeba1cfe9fb36a9faa1'}
        }else{
            if($locale -ceq 'en-US'){'d2aaba318ff784577e3bab1aa87fe795a93fd736dec4036fda69277acf34521f'}else{'65f9b2e49ea407f5c1cb90ff839811d97a29986ef07ca819704924a1194ef2eb'}
        }
        Check ($bodies[0].viewed_locale -ceq $locale -and (Hash-Text $bodies[0].captured_text) -ceq $hash) 'Historical captured wording changed'
    }
}
function Resolve-Reference($Archive,$ByUid,$Reference){
    Check ($Reference -is [Collections.IDictionary] -and $Reference.source_origin_id -ceq $Archive.source_origin_id -and $ByUid.ContainsKey($Reference.uid)) 'Broken observation reference'
    $entry=$ByUid[$Reference.uid];$observed=$entry.observation
    Check ($entry.record_class -ceq 'authored' -and $entry.source_origin_id -ceq $Archive.source_origin_id -and $Reference.kind -ceq $observed.entry_kind -and (Is-Int $Reference.content_version) -and $Reference.content_version -eq $observed.content_version) 'Reference kind/version/origin differs'
    Check (@($observed.segments|Where-Object {$_.segment_id -ceq $Reference.segment_id}).Count -eq 1) 'Reference segment missing or duplicated'
    return $observed
}
function Safe-Relative($Path){
    Check ($Path -is [string] -and $Path.Length -gt 0 -and $Path -cnotmatch '[\\:<>"|?*\x00-\x1f]' -and -not [IO.Path]::IsPathRooted($Path)) "Unsafe relative path: $Path"
    foreach($part in $Path.Split('/')){Check ($part -notin @('','.','..') -and $part -notmatch '[. ]$|^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') "Unsafe path component: $Path"}
}
function Raw-Path([string]$Path){
    Safe-Relative $Path
    Check ($script:inventory.ContainsKey($Path)) "Uninventoried evidence: $Path"
    return Join-Path $script:scratch $Path
}
function Check-Hash($Actual,$Expected,[string]$Label){
    Check ($Expected -is [string] -and $Expected -cmatch '^[0-9a-f]{64}$' -and $Actual -ceq $Expected) "Hash mismatch: $Label"
}
function Check-DeliveredTool([string]$Path,[string]$Expected){
    Safe-Relative $Path
    $file=Join-Path $script:repo $Path
    Check (Test-Path -LiteralPath $file -PathType Leaf) ('Delivered tool missing: '+$Path)
    Check-Hash (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() $Expected ('delivered tool '+$Path)
}
function Check-Corpus($Corpus,$Expected,[bool]$ResPrefix=$false){
    Check ($Corpus -is [Collections.IDictionary] -and (Is-Int $Corpus.file_count) -and $Corpus.file_count -eq @($Expected).Count) 'Corpus file count differs'
    if($Corpus.Contains('rows')){Check ($Corpus.rows -is [array] -and (Rows $Corpus.rows $Expected)) 'Corpus rows differ'}
    else{Check $ResPrefix 'Runner omitted required corpus rows'}
    if($Corpus.Contains('sha256')){
        # Compatibility receipts hash ordinal res:// paths; focused runners retain plain rows.
        $rowsToHash=if($ResPrefix){@($Expected|ForEach-Object {'res://'+$_})}else{@($Expected)}
        if($ResPrefix){[string[]]$rowsToHash=$rowsToHash;[Array]::Sort($rowsToHash,[StringComparer]::Ordinal)}
        Check-Hash (Hash-Text ($rowsToHash -join "`n")) $Corpus.sha256 'corpus digest'
    }else{Check (-not $ResPrefix) 'Compatibility runner omitted corpus digest'}
}
function Check-CorpusRows($Corpus,[int]$Count,[string]$Directory){
    Check ($Corpus -is [Collections.IDictionary] -and (Is-Int $Corpus.file_count) -and $Corpus.file_count -eq $Count -and $Corpus.rows -is [array] -and $Corpus.rows.Count -eq $Count) 'Control corpus count differs'
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($row in $Corpus.rows){
        Check ($row -is [string] -and $row -cmatch '^([^\t]+)\t([0-9a-f]{64})$') 'Malformed control corpus row'
        $path=$Matches[1];Safe-Relative $path
        Check ($path.StartsWith($Directory+'/',[StringComparison]::Ordinal) -and $paths.Add($path)) 'Wrong or duplicate control corpus path'
        if($Directory -ceq 'scripts'){Check ($path.EndsWith('.gd',[StringComparison]::Ordinal)) 'Non-GD source corpus row'}
    }
}
function Read-Summary([string]$Out,[string]$Prefix){
    $lines=@([regex]::Split($Out,'\r?\n')|Where-Object {$_.StartsWith($Prefix,[StringComparison]::Ordinal)})
    Check ($lines.Count -eq 1) "Missing or ambiguous native summary: $Prefix"
    $summary=ConvertFrom-Json -InputObject $lines[0].Substring($Prefix.Length) -AsHashtable -Depth 100
    Check ($summary -is [Collections.IDictionary]) 'Native summary must be an object'
    return $summary
}
function Check-Marker([string]$Out,$Declared,[string]$Expected){
    Check ($Declared -is [string] -and $Declared -ceq $Expected) "Incorrect literal manifest marker: $Expected"
    Check (@([regex]::Split($Out,'\r?\n')|Where-Object {$_ -ceq $Expected}).Count -eq 1) "Missing or ambiguous exact PASS marker: $Expected"
}
function Check-DisclosureResult($Result,[string]$Mode){
    Check ($Result.ok -is [bool] -and $Result.ok -eq ($Mode -ceq 'candidate') -and $Result.cases -is [array] -and $Result.cases.Count -eq 12 -and $Result.errors -is [array]) 'Disclosure result failed'
    $expected=@();foreach($locale in @('ko_KR','en_US')){foreach($id in @('c5_minimal','c5_all_channels','c5_all_channels_historical_v1','j3_skip','j3_read','j3_read_historical_v1')){$expected+=$id+'/'+$locale}}
    Check (@(Compare-Object -CaseSensitive $expected @($Result.cases|ForEach-Object {$_.id})).Count -eq 0) 'Disclosure matrix incomplete'
    $total=0
    foreach($case in $Result.cases){
        $fails=$Mode -ceq 'original' -or ($Mode -ceq 'flip_only' -and ($case.id.StartsWith('c5_') -or $case.id.StartsWith('j3_skip/')))
        Check ($case.ok -is [bool] -and $case.ok -eq (-not $fails) -and (Is-Int $case.errors) -and $case.errors -ge 0 -and ($case.errors -eq 0) -eq (-not $fails)) 'Unexpected disclosure case outcome'
        Check (@($Result.errors|Where-Object {$_.case -ceq $case.id}).Count -eq $case.errors) 'Case/global error accounting differs'
        Check ((Is-Int $case.save_events) -and $case.save_events -gt 0 -and (Is-Int $case.checks) -and $case.checks -gt 0) 'Missing native saves/checks'
        $total+=$case.errors
    }
    Check ($total -eq $Result.errors.Count) 'Unattributed native errors'
    foreach($errorRow in $Result.errors){
        Check ($errorRow.check -is [string] -and $errorRow.check.Length -gt 0 -and $errorRow.evidence -is [Collections.IDictionary]) 'Malformed native failure'
        Check ($errorRow.check -notmatch 'watchdog|deadline|setup|cleanup|snapshot|durable slot|production save failed') 'Control failed for infrastructure reasons'
        if($errorRow.case.StartsWith('c5_')){
            Check ($errorRow.check -cin @('tracing cites the channel label actually displayed, without granting an inspection','base tracing links an actually inspected individual channel (not merged prose)')) 'Unexpected C5 control failure'
        }elseif($Mode -ceq 'original'){
            Check ($errorRow.check -ceq 'j3_flip_page: displayed line failed to persist') 'Unexpected original J3 failure'
        }elseif($Mode -ceq 'flip_only'){
            Check ($errorRow.check -cmatch '^after restoration(?: reload)?: (KB never invents or deletes the door fragment|skipped memory has no legacy memory card|notebook material excludes undisclosed body|legacy notebook body also excludes undisclosed material|production memory-seen predicate agrees)$') 'Unexpected flip-only J3 failure'
        }
    }
    if($Mode -ceq 'original'){
        $barriers=@($Result.errors|Where-Object {$_.check -ceq 'j3_flip_page: displayed line failed to persist'})
        Check ($barriers.Count -eq 6 -and @(Compare-Object -CaseSensitive @($expected|Where-Object {$_.StartsWith('j3_')}) @($barriers|ForEach-Object {$_.case})).Count -eq 0) 'Original flip-page barrier not reproduced in six J3 cases'
    }elseif($Mode -ceq 'flip_only'){
        Check (@($Result.errors|Where-Object {$_.check -ceq 'j3_flip_page: displayed line failed to persist'}).Count -eq 0) 'Flip-only barrier not repaired'
    }
}
function Check-ChoiceResult($Result,[bool]$Legacy){
    $count=if($Legacy){152}else{56}
    Check ((Is-True $Result.ok) -and (Is-Int $Result.required_cases) -and $Result.required_cases -eq $count -and $Result.cases -is [array] -and $Result.cases.Count -eq $count -and $Result.errors -is [array] -and $Result.errors.Count -eq 0) 'Choice result/denominator failure'
    $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($case in $Result.cases){
        Check (Is-True $case.passed) 'Native choice failed'
        $identity=@{};foreach($field in @('kind','mode','scenario','locale','phase','answer','fixture')){if($case.Contains($field)){$identity[$field]=$case[$field]}}
        Check ($keys.Add((Canon $identity))) 'Duplicate choice case'
    }
    $modes=if($Legacy){@{p3_journal=@('author','locked','silent');p4_father=@('father_tea','mansion_age','luca_tenure');P1_EXIT=@('confirm','cancel');P6_SLEEP=@('confirm','cancel')}}else{@{ep01_sleep=@('confirm','cancel');ep01_morning=@('same','date','quiet')}}
    foreach($locale in @('ko_KR','en_US')){foreach($mode in $modes.Keys){
        $answers=$modes[$mode]
        foreach($scenario in (@('success','options_fail','selected_fail','ack','options_replace','selected_replace','selected_locale','selected_context')+@($answers|ForEach-Object {'answer_'+$_}))){
            Check ($keys.Contains((Canon @{kind='choice';mode=$mode;locale=$locale;scenario=$scenario}))) 'Choice scenario matrix incomplete'
        }
        Check ($keys.Contains((Canon @{kind='restore';mode=$mode;locale=$locale;phase='choosing';answer=$answers[0]}))) 'Choosing resume missing'
        foreach($answer in $(if($Legacy){@($answers[0])}else{$answers})){
            Check ($keys.Contains((Canon @{kind='restore';mode=$mode;locale=$locale;phase='selection_pending';answer=$answer}))) 'Answer resume missing'
        }
    }}
    if($Legacy){
        Check ($Result.timings -is [array] -and $Result.timings.Count -eq 8) 'Legacy large-fixture timings incomplete'
        foreach($locale in @('ko_KR','en_US')){
            foreach($scenario in @('basic','window','combined','stale_note','malformed')){Check ($keys.Contains((Canon @{kind='candidate';locale=$locale;scenario=$scenario}))) 'Legacy candidate matrix incomplete'}
            foreach($scenario in @('success','promotion','ack','replace','locale','service','progress_changed','pending_note_changed','handoff','after_action','after_action_failure')){Check ($keys.Contains((Canon @{kind='ui';locale=$locale;scenario=$scenario}))) 'Legacy UI matrix incomplete'}
            foreach($scenario in @('same_locale','other_locale','location','occurrence','content','completed')){Check ($keys.Contains((Canon @{kind='retry_identity';locale=$locale;scenario=$scenario}))) 'Legacy retry matrix incomplete'}
            foreach($fixture in @('NB-PERF-N2000','NB-PERF-L10000','NB-PERF-P2001','NB-PERF-LONG')){
                Check ($keys.Contains((Canon @{kind='large';locale=$locale;fixture=$fixture}))) 'Legacy large-fixture matrix incomplete'
                Check (@($Result.timings|Where-Object {$_.fixture -ceq $fixture -and $_.locale -ceq $locale}).Count -eq 1) 'Legacy timing matrix incomplete'
            }
        }
    }
}
function Check-Receipt($Row,[string]$Mode='candidate'){
    $base=$Row.name
    Safe-Relative $base;Check ($base -notmatch '/') 'Run name must be one directory'
    foreach($field in @('receipt','stdout','stderr')){Safe-Relative $Row[$field]}
    $receipt=Json (Raw-Path ($base+'/'+$Row.receipt))
    Check-Completion $receipt $Mode
    Check-Hash $receipt.engine_sha256 $script:engineSha 'official engine'
    if($Mode -ceq 'candidate'){
        Check-Corpus $receipt.source_corpus $script:source
        if($receipt.Contains('data_corpus')){
            Check-Corpus $receipt.data_corpus $script:data
            Check (Is-True $receipt.data_unchanged) 'Native data changed'
        }else{
            # The legacy runner records only GD sources; do not invent a data_unchanged claim.
            Check ($Row.kind -ceq 'legacy') 'Data binding missing'
        }
    }else{
        Check-CorpusRows $receipt.source_corpus 307 'scripts'
        Check-CorpusRows $receipt.data_corpus 61 'data'
        Check (("data/notebook/mirror_v1.json`t42d31ad557c795401bdb0fc5a46785c331e0cee1ec7a5cc38077894c7265db41") -cin $receipt.data_corpus.rows) 'Control original mirror catalog changed'
        Check (-not (Rows $receipt.source_corpus.rows $script:source)) 'Control source is not distinct from candidate'
        Check (Is-True $receipt.data_unchanged) 'Control data changed'
        Check ((Is-True $receipt.baseline) -and $receipt.baseline_kind -ceq $Mode) 'Wrong baseline receipt'
    }
    Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($base+'/runner.ps1'))).Hash.ToLowerInvariant() $receipt.runner_sha256 'archived runner'
    $runnerPath=switch($Row.kind){
        'disclosure' {'scripts/run_notebook_sheet_disclosure_audit.ps1'}
        'original' {'scripts/run_notebook_sheet_disclosure_audit.ps1'}
        'flip_only' {'scripts/run_notebook_sheet_disclosure_audit.ps1'}
        'choice' {'scripts/run_notebook_sheet_choice_async_audit.ps1'}
        'legacy' {'scripts/run_notebook_prologue_choice_async_audit.ps1'}
        default {''}
    }
    if($runnerPath){Check-DeliveredTool $runnerPath $receipt.runner_sha256}
    if($receipt.Contains('harnesses')){
        $expectedHarnesses=if($Row.kind -ceq 'choice'){@('notebook_history_async_audit.gd','notebook_prologue_async_audit.gd','notebook_prologue_choice_async_audit.gd','notebook_sheet_choice_async_audit.gd','notebook_sheet_choice_async_audit.tscn')}else{@('notebook_sheet_disclosure_audit.gd','notebook_sheet_disclosure_audit.tscn')}
        Check ($receipt.harnesses -is [array] -and $receipt.harnesses.Count -eq $expectedHarnesses.Count -and @(Compare-Object -CaseSensitive $expectedHarnesses @($receipt.harnesses|ForEach-Object {$_.name})).Count -eq 0) 'Missing or unexpected harness receipt'
        foreach($h in $receipt.harnesses){
            Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($base+'/'+$h.name))).Hash.ToLowerInvariant() $h.sha256 'archived harness'
            Check-DeliveredTool ('scripts/tests/'+$h.name) $h.sha256
        }
    }elseif($Row.kind -ceq 'legacy'){
        foreach($pair in @(@('base_harness_sha256','notebook_history_async_audit.gd'),@('parent_harness_sha256','notebook_prologue_async_audit.gd'),@('harness_sha256','notebook_prologue_choice_async_audit.gd'),@('scene_sha256','notebook_prologue_choice_async_audit.tscn'))){
            Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($base+'/'+$pair[1]))).Hash.ToLowerInvariant() $receipt[$pair[0]] 'archived legacy harness'
            Check-DeliveredTool ('scripts/tests/'+$pair[1]) $receipt[$pair[0]]
        }
    }else{Check ($Row.kind -ceq 'regression') 'Harness receipt missing'}
    $logs=@{}
    foreach($field in @('stdout','stderr')){
        $p=Raw-Path ($base+'/'+$Row[$field]);$logs[$field]=[IO.File]::ReadAllText($p)
        Check-Hash (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() $receipt[($field+'_sha256')] 'receipt/log binding'
        Check (-not [regex]::IsMatch($logs[$field],'(?im)SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use|^\s*ERROR:|^\s*FATAL:')) 'Native error or shutdown leak'
    }
    return @{receipt=$receipt;stdout=$logs.stdout;stderr=$logs.stderr}
}
function Check-Completion($Receipt,[string]$Mode){
    Check ((Is-True $Receipt.completed) -and (Is-Int $Receipt.exit_code) -and $Receipt.exit_code -eq $(if($Mode -ceq 'candidate'){0}else{1}) -and (Is-True $Receipt.source_unchanged)) 'Native completion/source failure'
}
function Check-Arguments($Arguments,[bool]$Async){
    Check ($Arguments -is [array]) 'Native argument vector missing'
    foreach($flag in @('--headless','--ggb-dev-notebook-v2','--notebook-require-authored')){Check (@($Arguments|Where-Object {$_ -ceq $flag}).Count -eq 1) "Native flag missing or duplicated: $flag"}
    Check (@($Arguments|Where-Object {$_ -ceq '--ggb-dev-notebook-async'}).Count -eq [int]$Async) 'Native async argument differs from receipt'
}
function Audit-Disclosure($Row,[string]$Mode){
    $native=Check-Receipt $Row $Mode
    Check ($Row.marker -ceq 'NOTEBOOK_SHEET_DISCLOSURE_AUDIT:') 'Wrong disclosure marker'
    Check ($native.receipt.async -is [bool] -and $native.receipt.baseline -is [bool] -and $native.receipt.baseline -eq ($Mode -cne 'candidate')) 'Disclosure mode receipt missing'
    Check-Arguments $native.receipt.arguments $native.receipt.async
    $result=Json (Raw-Path ($Row.name+'/result.json'))
    Check ((Canon $result) -ceq (Canon (Read-Summary $native.stdout 'NOTEBOOK_SHEET_DISCLOSURE_AUDIT: '))) 'Result differs from native stdout'
    Check ($result.source_scope.async_history -is [bool] -and $result.source_scope.async_history -eq $native.receipt.async) 'Native summary async mode differs from receipt'
    Check-DisclosureResult $result $Mode
    foreach($case in $result.cases){
        $file=$case.id.Replace('/','_')+'.json'
        Check ($case.evidence.snapshot_file -ceq $file) 'Snapshot filename differs from case identity'
        $doc=Json (Raw-Path ($Row.name+'/snapshots/'+$file))
        Check ($doc.case -ceq $case.id) 'Snapshot identity mismatch'
        Check-Case $doc ($Mode -ceq 'candidate') -Original:($Mode -ceq 'original')
        $script:snapshotCases++
        if($Mode -ceq 'candidate'){$script:candidateDocs+=$doc}
    }
    return $native.receipt
}
function Reject-Mutation([scriptblock]$Action){
    $caught=$false;try{& $Action}catch{$caught=$true}
    Check $caught 'Tamper self-test accepted altered evidence'
    $script:rejected++
}
$engineSha='ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
$m=Json (Join-Path $root 'manifest.json')
Check ($m.schema_version -eq 1 -and $m.integration_base -ceq '8479e9d5584ccb11e4c1934fa63c58bc55695c52') 'Wrong integration base'
Check-Hash $m.engine_sha256 $engineSha 'manifest engine'
$zip=Join-Path $root 'raw.zip'
Check-Hash (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant() $m.archive_sha256 'raw archive'
$inventory=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Check ($m.files -is [array] -and $m.files.Count -gt 0) 'Missing archive inventory'
foreach($f in $m.files){
    Safe-Relative $f.path
    Check ($names.Add($f.path) -and (Is-Int $f.bytes) -and $f.bytes -ge 0 -and $f.sha256 -cmatch '^[0-9a-f]{64}$') 'Invalid or duplicate inventory row'
    $inventory.Add($f.path,$f)
}
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('ggb-sheet-proof-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch|Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z=[IO.Compression.ZipFile]::OpenRead($zip);$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
try{foreach($e in $z.Entries){
    $directory=$e.FullName.EndsWith('/');$path=if($directory){$e.FullName.TrimEnd('/')}else{$e.FullName}
    Safe-Relative $path
    Check ($seen.Add($path) -and (($e.ExternalAttributes -shr 16) -band 0xf000) -ne 0xa000) 'Duplicate archive path or symlink'
    if(-not $directory){Check ($inventory.ContainsKey($path) -and $e.Length -eq $inventory[$path].bytes) 'Archive entry differs from inventory'}
}}finally{$z.Dispose()}
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$scratch,[Text.Encoding]::UTF8)
$files=@(Get-ChildItem -LiteralPath $scratch -Recurse -File -Force|ForEach-Object {$_.FullName.Substring($scratch.Length+1).Replace('\','/')})
Check ($files.Count -eq $m.files.Count -and @(Compare-Object -CaseSensitive $files @($m.files|ForEach-Object {$_.path})).Count -eq 0) 'Archive inventory differs'
foreach($f in $m.files){$p=Raw-Path $f.path;Check ((Get-Item -LiteralPath $p).Length -eq $f.bytes) 'Raw file length differs';Check-Hash (Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() $f.sha256 ('raw file '+$f.path)}
$source=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/scripts') -Recurse -Filter '*.gd' -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
$data=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/data') -Recurse -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
Check ($source.Count -eq 307 -and $data.Count -eq 63 -and $m.source_corpus -is [array] -and $m.data_corpus -is [array] -and (Rows $source $m.source_corpus) -and (Rows $data $m.data_corpus)) 'Delivered product/catalog differs from tested source'
Check-Hash (Get-FileHash -LiteralPath (Join-Path $repo 'game/data/notebook/mirror_v1.json')).Hash.ToLowerInvariant() '42d31ad557c795401bdb0fc5a46785c331e0cee1ec7a5cc38077894c7265db41' 'preserved original mirror catalog'
Check ($m.runs -is [array] -and $m.runs.Count -eq 9 -and $m.controls -is [array] -and $m.controls.Count -eq 2) 'Nine final runs and original/flip_only controls required'
Check ($m.diagnostics -is [array] -and $m.diagnostics.Count -eq 6 -and @(Compare-Object -CaseSensitive @('retained-choice','baseline-disclosure','original-final','flip-only-control','candidate3-basic-v2','candidate4-basic-v2') @($m.diagnostics|ForEach-Object {$_.name})).Count -eq 0) 'Discarded diagnostic inventory differs'
Check (@($m.runs|Where-Object {$_.kind -ceq 'disclosure'}).Count -eq 2 -and @($m.runs|Where-Object {$_.kind -ceq 'choice'}).Count -eq 1 -and @($m.runs|Where-Object {$_.kind -ceq 'legacy'}).Count -eq 1) 'Final run kind matrix differs'
$runNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$modes=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$disclosureModes=@();$snapshotCases=0;$candidateDocs=@();$rejected=0
$regressionSuites=@{mirror='notebook_mirror_smoke';basic='black_mirror_smoke';sheet=$null;inventory='inventory_hud_smoke';campaign='full_campaign_smoke'}
foreach($row in $m.runs){
    Check ($runNames.Add($row.name)) 'Duplicate run directory'
    if($row.kind -ceq 'disclosure'){
        $receipt=Audit-Disclosure $row 'candidate';$disclosureModes+=$receipt.async
    }elseif($row.kind -cin @('choice','legacy')){
        $native=Check-Receipt $row;$legacy=$row.kind -ceq 'legacy'
        if(-not $legacy){Check-Arguments $native.receipt.arguments $true}
        $file=if($legacy){'focused.result.json'}else{'result.json'}
        $prefix=if($legacy){'PROLOGUE_CHOICE_ASYNC_AUDIT: '}else{'SHEET_CHOICE_ASYNC_AUDIT: '}
        $marker=if($legacy){'PROLOGUE_CHOICE_ASYNC_SMOKE:PASS'}else{'SHEET_CHOICE_ASYNC_SMOKE:PASS'}
        Check-Marker $native.stdout $row.marker $marker
        $result=Json (Raw-Path ($row.name+'/'+$file))
        Check ((Canon $result) -ceq (Canon (Read-Summary $native.stdout $prefix))) 'Choice result differs from native stdout'
        Check-ChoiceResult $result $legacy
    }elseif($row.kind -ceq 'regression'){
        $native=Check-Receipt $row;$mode=$native.receipt.mode
        Check ($mode -is [string] -and $mode -cin @('mirror','basic','sheet','inventory','campaign') -and $modes.Add($mode)) 'Unknown or duplicate native regression mode'
        Check-Arguments $native.receipt.arguments $false
        $suiteArgs=@($native.receipt.arguments|Where-Object {$_ -is [string] -and $_.StartsWith('--sheet-regression=',[StringComparison]::Ordinal)})
        if($mode -ceq 'sheet'){
            Check (@($native.receipt.arguments|Where-Object {$_ -ceq 'res://scripts/tests/sheet_sync_smoke.tscn'}).Count -eq 1 -and $suiteArgs.Count -eq 0) 'Wrong sheet regression scene/arguments'
            $summaries=@([regex]::Split($native.stdout,'\r?\n')|Where-Object {$_ -cmatch '^SHEET_SYNC_SMOKE PASS checks=[0-9]+ failures=0$'})
            Check ($summaries.Count -eq 1) 'Missing or ambiguous sheet PASS summary'
            Check-Marker $native.stdout $row.marker $summaries[0]
        }else{
            Check (@($native.receipt.arguments|Where-Object {$_ -ceq 'res://scripts/tests/sheet_sync_regression.tscn'}).Count -eq 1 -and $suiteArgs.Count -eq 1 -and $suiteArgs[0] -ceq ('--sheet-regression='+$regressionSuites[$mode])) 'Wrong regression scene/suite arguments'
            Check-Marker $native.stdout $row.marker 'SHEET_REGRESSION PASS'
        }
    }else{
        throw "Unknown run kind: $($row.kind)"
    }
}
Check ($disclosureModes.Count -eq 2 -and $false -in $disclosureModes -and $true -in $disclosureModes) 'Disclosure sync/async pair missing'
$packRow=$m.pack_validation
Check ($packRow.name -ceq 'latest-pack-catalog' -and $packRow.json_files -eq 50) 'Packed catalogue validation missing'
$packResult=Json (Raw-Path ($packRow.name+'/result.json'))
Check ((Is-True $packResult.ok) -and $packResult.json_files -eq 50 -and $packResult.C5_version -eq 2 -and $packResult.C4_confirmation_version -eq 2 -and $packResult.binary_retained_in_git -is [bool] -and -not $packResult.binary_retained_in_git -and $packResult.pack_bytes -gt 0) 'Wrong packed catalogue scope/result'
Check-Hash $packResult.pack_sha256 $packRow.pack_sha256 'generated PCK fingerprint metadata'
$packedRows=@(ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Raw-Path ($packRow.name+'/catalog-corpus.json')))))
$expectedJson=@($data|Where-Object {$_ -cmatch '\.json\t'})
Check ($packedRows.Count -eq 50 -and (Rows $packedRows $expectedJson)) 'Packed JSON input differs from committed data'
$packReceipts=@{}
foreach($mode in @('export','check')){
    $receipt=Json (Raw-Path ($packRow.name+'/'+$mode+'.run.json'))
    Check ((Is-True $receipt.completed) -and (Is-Int $receipt.exit_code) -and $receipt.exit_code -eq 0) 'Packed catalogue native run incomplete'
    Check-Hash $receipt.engine_sha256 $engineSha 'packed catalogue engine'
    Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($packRow.name+'/runner.ps1'))).Hash.ToLowerInvariant() $receipt.runner_sha256 'packed catalogue runner'
    Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($packRow.name+'/catalog_check.gd'))).Hash.ToLowerInvariant() $receipt.harness_sha256 'packed catalogue harness'
    foreach($field in @('stdout','stderr')){
        $suffix=if($field -ceq 'stdout'){'.out.log'}else{'.err.log'}
        $path=Raw-Path ($packRow.name+'/'+$mode+$suffix)
        Check-Hash (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() $receipt[($field+'_sha256')] 'packed catalogue log'
        $text=[IO.File]::ReadAllText($path)
        Check (-not [regex]::IsMatch($text,'(?im)SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use|^\s*ERROR:|^\s*FATAL:')) 'Packed catalogue native error'
        if($mode -ceq 'check' -and $field -ceq 'stdout'){Check-Marker $text $packRow.marker 'PACK_NOTEBOOK_CATALOGS_PASS json_files=50 C5_version=2 C4_confirmation=2'}
    }
    Check ($receipt.arguments -is [array] -and '--headless' -cin $receipt.arguments) 'Packed catalogue argument vector missing'
    $packReceipts[$mode]=$receipt
}
$exportArgs=$packReceipts.export.arguments;$checkArgs=$packReceipts.check.arguments
Check (@($exportArgs|Where-Object {$_ -ceq '--export-pack'}).Count -eq 1 -and @($checkArgs|Where-Object {$_ -ceq '--main-pack'}).Count -eq 1) 'Export/PCK execution flags missing'
$packIndex=[Array]::IndexOf($checkArgs,'--main-pack')
Check ($packIndex + 1 -lt $checkArgs.Count -and $checkArgs[$packIndex+1] -ceq $exportArgs[-1]) 'PCK check did not use exported pack'
Check ($packRow.runtime_name -ceq 'latest-pack-runtime') 'Packed scene regression missing'
$runtime=Json (Raw-Path ($packRow.runtime_name+'/run.json'))
Check ((Is-True $runtime.completed) -and (Is-Int $runtime.exit_code) -and $runtime.exit_code -eq 0 -and (Is-True $runtime.pack_unchanged)) 'Packed scene regression failed'
Check-Hash $runtime.engine_sha256 $engineSha 'packed scene engine'
Check-Hash $runtime.pack_sha256 $packResult.pack_sha256 'packed scene uses checked PCK'
Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($packRow.runtime_name+'/runner.ps1'))).Hash.ToLowerInvariant() $runtime.runner_sha256 'packed scene runner'
Check-Arguments $runtime.arguments $false
$runtimeIndex=[Array]::IndexOf($runtime.arguments,'--main-pack')
Check ($runtimeIndex -ge 0 -and $runtimeIndex+1 -lt $runtime.arguments.Count -and $runtime.arguments[$runtimeIndex+1] -ceq $exportArgs[-1] -and 'res://scripts/tests/sheet_sync_regression.tscn' -cin $runtime.arguments -and '--sheet-regression=black_mirror_smoke' -cin $runtime.arguments) 'Wrong packed scene/suite/PCK arguments'
foreach($field in @('stdout','stderr')){
    $suffix=if($field -ceq 'stdout'){'run.out.log'}else{'run.err.log'}
    $path=Raw-Path ($packRow.runtime_name+'/'+$suffix)
    Check-Hash (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() $runtime[($field+'_sha256')] 'packed scene log'
    $text=[IO.File]::ReadAllText($path)
    Check (-not [regex]::IsMatch($text,'(?im)SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use|^\s*ERROR:|^\s*FATAL:')) 'Packed scene native error'
    if($field -ceq 'stdout'){
        Check-Marker $text 'SHEET_REGRESSION PASS' 'SHEET_REGRESSION PASS'
        $summary=Read-Summary $text 'SHEET_REGRESSION black_mirror_smoke '
        Check ((Is-True $summary.ok) -and $summary.errors -is [array] -and $summary.errors.Count -eq 0) 'Packed mirror scene failed'
    }
}
Check (@($m.controls|Where-Object {$_.kind -ceq 'original'}).Count -eq 1 -and @($m.controls|Where-Object {$_.kind -ceq 'flip_only'}).Count -eq 1) 'Negative control pair missing'
Check ($packRow.ordinary_name -ceq 'latest-pack-ordinary') 'Ordinary packed regression missing'
$ordinary=Json (Raw-Path ($packRow.ordinary_name+'/run.json'))
Check ((Is-True $ordinary.completed) -and (Is-Int $ordinary.exit_code) -and $ordinary.exit_code -eq 0 -and (Is-True $ordinary.pack_unchanged) -and (Is-True $ordinary.ordinary)) 'Ordinary packed regression failed'
Check-Hash $ordinary.engine_sha256 $engineSha 'ordinary packed engine'
Check-Hash $ordinary.pack_sha256 $packResult.pack_sha256 'ordinary packed PCK'
Check-Hash (Get-FileHash -LiteralPath (Raw-Path ($packRow.ordinary_name+'/runner.ps1'))).Hash.ToLowerInvariant() $ordinary.runner_sha256 'ordinary packed runner'
Check ($ordinary.arguments -is [array] -and '--headless' -cin $ordinary.arguments -and '--black-mirror-smoke' -cin $ordinary.arguments -and '--ggb-dev-notebook-v2' -cnotin $ordinary.arguments -and '--ggb-dev-notebook-async' -cnotin $ordinary.arguments -and '--notebook-require-authored' -cnotin $ordinary.arguments) 'Ordinary packed mode was overridden'
$ordinaryIndex=[Array]::IndexOf($ordinary.arguments,'--main-pack')
Check ($ordinaryIndex -ge 0 -and $ordinaryIndex+1 -lt $ordinary.arguments.Count -and $ordinary.arguments[$ordinaryIndex+1] -ceq $exportArgs[-1]) 'Ordinary runtime did not use checked PCK'
foreach($field in @('stdout','stderr')){
    $suffix=if($field -ceq 'stdout'){'run.out.log'}else{'run.err.log'}
    $path=Raw-Path ($packRow.ordinary_name+'/'+$suffix)
    Check-Hash (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() $ordinary[($field+'_sha256')] 'ordinary packed log'
    $text=[IO.File]::ReadAllText($path)
    Check (-not [regex]::IsMatch($text,'(?im)SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use|^\s*ERROR:|^\s*FATAL:')) 'Ordinary packed native error'
    if($field -ceq 'stdout'){Check-Marker $text 'BLACK_MIRROR_SMOKE: PASS' 'BLACK_MIRROR_SMOKE: PASS'}
}
foreach($row in $m.controls){Check ($runNames.Add($row.name)) 'Duplicate control/run directory';$null=Audit-Disclosure $row $row.kind}
Check (@($m.controls|Where-Object {$_.name -ceq 'latest-original' -and $_.kind -ceq 'original'}).Count -eq 1 -and @($m.controls|Where-Object {$_.name -ceq 'latest-flip-control' -and $_.kind -ceq 'flip_only'}).Count -eq 1) 'Latest control identities differ'
foreach($row in $m.diagnostics){
    Safe-Relative $row.name
    Check ($runNames.Add($row.name) -and @($files|Where-Object {$_.StartsWith($row.name+'/',[StringComparison]::Ordinal)}).Count -gt 0) 'Diagnostic missing or overlaps acceptance evidence'
}
if($SelfTest){
    foreach($id in @('c5_minimal/ko_KR','j3_skip/ko_KR')){
        $doc=@($candidateDocs|Where-Object {$_.case -ceq $id})[0]
        Check-Case $doc $true
        foreach($change in @('state','durable','outcome','missing','identity')){
            $bad=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $doc -Depth 100) -AsHashtable -Depth 100
            if($change -ceq 'durable'){$bad.durable_state.meta_progress.journal_stage=99}
            elseif($change -ceq 'missing'){$bad.Remove('state')}
            elseif($change -ceq 'identity'){$bad.case='c5_minimal/ko-KR'}
            elseif($id.StartsWith('j3_')){$bad.state.meta_progress.knowledge_entries.MEM_FATHER_DRAWN_DOOR_FRAGMENT='episodic_fragment';if($change -ceq 'outcome'){$bad.durable_state=$bad.state}}
            else{$bad.state.meta_progress.knowledge_entries.c5_inspections+=@('EDGAR');if($change -ceq 'outcome'){$bad.durable_state=$bad.state}}
            Reject-Mutation {Check-Case $bad $true}
        }
    }
    Reject-Mutation {Check-Hash ('0'*64) $engineSha 'mutated engine'}
    Check-Completion @{completed=$true;exit_code=0;source_unchanged=$true} 'candidate'
    foreach($badReceipt in @(@{completed='true';exit_code=0;source_unchanged=$true},@{completed=$true;exit_code=$null;source_unchanged=$true},@{completed=$true;exit_code=0;source_unchanged='true'})){Reject-Mutation {Check-Completion $badReceipt 'candidate'}}
    Reject-Mutation {Check-Corpus @{file_count=307;rows=@('forged')} $source}
    Reject-Mutation {Check-Marker 'PREFIX PASS SUFFIX' 'PASS' 'PASS'}
    foreach($badPath in @('../escape','C:/escape','run/../escape','run\escape','run/file.','run/NUL')){Reject-Mutation {Safe-Relative $badPath}}
    $disclosure=@($m.runs|Where-Object {$_.kind -ceq 'disclosure'})[0]
    $good=Json (Raw-Path ($disclosure.name+'/result.json'))
    Check-DisclosureResult $good 'candidate'
    foreach($change in @('duplicate_case','hidden_error','string_boolean')){
        $bad=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $good -Depth 100) -AsHashtable -Depth 100
        switch($change){
            'duplicate_case' {$bad.cases[1]=$bad.cases[0]}
            'hidden_error' {$bad.errors+=@(@{case='not_a_case';check='forged';evidence=@{}})}
            'string_boolean' {$bad.ok='true'}
        }
        Reject-Mutation {Check-DisclosureResult $bad 'candidate'}
    }
}
[ordered]@{ok=$true;checks=$checks;runs=$m.runs.Count;controls=$m.controls.Count;snapshot_cases=$snapshotCases;source_files=$source.Count;data_files=$data.Count;raw_files=$files.Count;packed_json_files=$packedRows.Count;pack_native_runs=4;ordinary_packed_runtime=$true;rejected_mutations=$rejected;scope='native state, matrix, source, durable and packed-catalogue evidence; not OS input, release binary or whole-plan acceptance';raw_extract=$scratch}|ConvertTo-Json
