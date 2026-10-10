param([Parameter(Mandatory)][string]$EvidencePath,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$game=Join-Path $repo 'game'
$catalog=Get-Content -LiteralPath (Join-Path $game 'data/notebook/reality_v1.json') -Raw|ConvertFrom-Json -AsHashtable
$objects=@('OBJ_REALITY_HAND','OBJ_REALITY_BREATH_MONITOR','OBJ_REALITY_RESTRAINT')
$checks=0
function Require([bool]$Ok,[string]$Message) { $script:checks++;if (-not $Ok) {throw $Message} }
function Sha([string]$Path) {(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
function HashText([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try {[Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()} finally {$sha.Dispose()}
}
function Check-Result($Result) {
    Require ($Result.schema_version -eq 1 -and $Result.suite_id -ceq 'gallery-consumer' -and $Result.ok -eq $true -and @($Result.errors).Count -eq 0) 'Focused status/schema'
    Require ($Result.required_cases -eq 128 -and @($Result.cases).Count -eq 128 -and $Result.required_writes -eq 18 -and @($Result.writes).Count -eq 18) 'Focused denominator'
    $expected=@()
    foreach ($format in @('legacy','authored')) {foreach ($locale in @('ko-KR','en-US')) {foreach ($mask in 0..7) {foreach ($representation in @('captured','maintained')) {foreach ($display in @('ko-KR','en-US')) {$expected+="$format/$locale/$mask/$representation/$display"}}}}}
    $keys=@($Result.cases|ForEach-Object key)
    Require (@($keys|Sort-Object -Unique).Count -eq 128 -and -not @(Compare-Object $expected $keys).Count) 'Missing, duplicate, or unexpected case'
    foreach ($case in $Result.cases) {
        $parts=$case.key.Split('/')
        $mask=[int]$parts[2];$display=$parts[4]
        Require ($case.passed -eq $true -and @($case.bodies).Count -eq 3 -and -not @(Compare-Object @($case.bodies|ForEach-Object object_id) $objects).Count) 'Body observation denominator/status'
        for ($index=0;$index -lt 3;$index++) {
            $object=$objects[$index]
            $body=@($case.bodies|Where-Object {$_.object_id -ceq $object})
            Require ($body.Count -eq 1 -and $body[0].repeated -eq [bool]($mask -band (1 -shl $index))) 'Object repeat evidence differs from independent mask'
            $first=$catalog.contents['NB_REALITY_BODY_'+$object+'_FIRST']['1'].locales[$display].body
            $repeat=$catalog.contents['NB_REALITY_BODY_'+$object+'_REPEAT']['1'].locales[$display].body
            Require (-not [string]::IsNullOrEmpty($first) -and -not [string]::IsNullOrEmpty($repeat)) 'Public body content is absent'
            $text=$first+$(if ($mask -band (1 -shl $index)) {"`n"+$repeat} else {''})
            Require ($body[0].text_sha256 -ceq (HashText $text) -and -not [string]::IsNullOrEmpty($body[0].title)) 'Displayed body text differs from canonical observed version'
        }
    }
    $expectedWrites=@()
    foreach ($object in $objects) {foreach ($locale in @('ko-KR','en-US')) {foreach ($policy in @('normal','reject_retry','lost_ack')) {$expectedWrites+="$object/$locale/$policy"}}}
    $writeKeys=@($Result.writes|ForEach-Object key)
    Require (@($writeKeys|Sort-Object -Unique).Count -eq 18 -and -not @(Compare-Object $expectedWrites $writeKeys).Count) 'Write policy denominator'
    foreach ($write in $Result.writes) {Require ($write.passed -eq $true -and $write.repeat_records -eq 1) 'Write/retry duplicates or failed record'}
    Require ($Result.checks -ge 3000) 'Focused assertions unexpectedly missing'
}
function Check-Receipt($Receipt,[string]$Mode) {
    Require ($Receipt.schema_version -eq 1 -and $Receipt.mode -ceq $Mode -and $Receipt.completed -eq $true -and $Receipt.exit_code -eq 0 -and $Receipt.expected_failure -eq $false -and $Receipt.require_authored -eq $true) 'Native receipt completion/mode/status'
    Require ($Receipt.engine_version -ceq '4.7.2.stable.steam.ed1daf0bf' -and $Receipt.engine_sha256 -ceq '12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38') 'Engine identity'
    Require ($Receipt.source_unchanged -eq $true -and $Receipt.data_unchanged -eq $true -and $Receipt.source_corpus.sha256 -ceq 'b17f75faffdc18ab660992f5c19773d239595cf4e579e8e521ddefc1e484acc6' -and
        $Receipt.data_corpus.sha256 -ceq 'af1ff4a6fb3c427b8dbc22ea273e2b57904252338e392a05abdb40b8a735660a') 'Runtime source/data cohort'
    foreach ($kind in @('source','data')) {
        $corpus=$Receipt.($kind+'_corpus')
        Require ($corpus.file_count -eq $(if ($kind -eq 'source') {264} else {52}) -and @($corpus.rows).Count -eq $corpus.file_count -and
            @($corpus.rows|Sort-Object -Unique).Count -eq $corpus.file_count -and (HashText (@($corpus.rows) -join "`n")) -ceq $corpus.sha256) 'Corpus rows/hash'
        foreach ($row in $corpus.rows) {
            $parts=$row.Split("`t")
            Require ($parts.Count -eq 2 -and $parts[0].StartsWith('res://') -and $parts[0] -notmatch '\.\.') 'Safe source path'
            Require ((Sha (Join-Path $game $parts[0].Substring(6))) -ceq $parts[1]) 'Current product differs from tested source'
        }
    }
    Require ($Receipt.runner_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'run_notebook_gallery_consumer_audit.ps1'))) 'Runner provenance'
    foreach ($stream in @('out','err')) {Require ($Receipt.($(if ($stream -eq 'out') {'stdout_sha256'} else {'stderr_sha256'})) -ceq (Sha (Join-Path $root ($Mode+'.'+$stream+'.log')))) 'Raw log hash'}
    $logs=@((Join-Path $root ($Mode+'.out.log')),(Join-Path $root ($Mode+'.err.log')))
    Require (-not (Select-String -LiteralPath $logs -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) 'Raw script error'
    $marker=switch ($Mode) {'consumer' {'NOTEBOOK_GALLERY_CONSUMER_SMOKE:PASS'} 'migration' {'NOTEBOOK_MIGRATION_SMOKE: PASS'} 'query' {'NOTEBOOK_QUERY_SMOKE: PASS'}}
    Require (@(Get-Content -LiteralPath $logs[0]|Where-Object {$_ -ceq $marker}).Count -eq 1) 'Exact raw PASS marker'
    if ($Mode -eq 'consumer') {
        Require ($Receipt.fixture_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/notebook_gallery_consumer_audit.gd')) -and
            $Receipt.scene_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/notebook_gallery_consumer_audit.tscn'))) 'Focused fixture provenance'
        $raw=@(Get-Content -LiteralPath $logs[0]|Where-Object {$_.StartsWith('NOTEBOOK_GALLERY_CONSUMER_AUDIT: ')})
        Require ($raw.Count -eq 1) 'Focused summary count'
        $parsed=$raw[0].Substring('NOTEBOOK_GALLERY_CONSUMER_AUDIT: '.Length)|ConvertFrom-Json
        $saved=Get-Content -LiteralPath (Join-Path $root 'consumer.result.json') -Raw|ConvertFrom-Json
        Require (($parsed|ConvertTo-Json -Depth 20 -Compress) -ceq ($saved|ConvertTo-Json -Depth 20 -Compress)) 'Raw/saved summary disagreement'
        Check-Result $saved
    }
}
$receipts=@{}
foreach ($mode in @('consumer','migration','query')) {
    $receipts[$mode]=Get-Content -LiteralPath (Join-Path $root ($mode+'.run.json')) -Raw|ConvertFrom-Json
    Check-Receipt $receipts[$mode] $mode
}
$negative=@()
if ($SelfTest) {
    foreach ($kind in @('missing_case','duplicate_case','repeat_mask','body_text','write_duplicate','native_status','source_hash','log_hash')) {
        try {
            if ($kind -in @('native_status','source_hash','log_hash')) {
                $copy=$receipts.consumer|ConvertTo-Json -Depth 20|ConvertFrom-Json
                switch ($kind) {'native_status' {$copy.exit_code=1} 'source_hash' {$copy.source_corpus.sha256='0'*64} 'log_hash' {$copy.stdout_sha256='0'*64}}
                Check-Receipt $copy 'consumer'
            } else {
                $copy=Get-Content -LiteralPath (Join-Path $root 'consumer.result.json') -Raw|ConvertFrom-Json
                switch ($kind) {
                    'missing_case' {$copy.cases=@($copy.cases|Select-Object -Skip 1)}
                    'duplicate_case' {$copy.cases[1].key=$copy.cases[0].key}
                    'repeat_mask' {$copy.cases[0].bodies[0].repeated=$true}
                    'body_text' {$copy.cases[0].bodies[0].text_sha256='0'*64}
                    'write_duplicate' {$copy.writes[0].repeat_records=2}
                }
                Check-Result $copy
            }
            throw ('Accepted malformed evidence: '+$kind)
        } catch {
            if ($_.Exception.Message.StartsWith('Accepted malformed evidence:')) {throw}
            $negative+=@{id=$kind;rejected=$true;reason=$_.Exception.Message}
        }
    }
}
$result=Get-Content -LiteralPath (Join-Path $root 'consumer.result.json') -Raw|ConvertFrom-Json
[ordered]@{ok=$true;checks=$checks;receipts=3;consumer_cases=128;write_cases=18;runtime_checks=$result.checks;source_sha256=$receipts.consumer.source_corpus.sha256;data_sha256=$receipts.consumer.data_corpus.sha256;negative=$negative}|ConvertTo-Json -Depth 6
