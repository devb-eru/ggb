param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [Parameter(Mandatory)][string]$RepoPath,
    [switch]$SelfTest
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=(Resolve-Path -LiteralPath $RepoPath).Path
$checks=0
function Assert-True([bool]$Value,[string]$Message){
    $script:checks++
    if(-not $Value){throw $Message}
}
function Read-Json([string]$Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -AsHashtable}
function Equal-Rows($Left,$Right){[string]::Join("`n",@($Left)) -ceq [string]::Join("`n",@($Right))}
function Validate-Run($Row,$Receipt,[string]$Out,[string]$Err,$Corpus,[string]$Engine){
    Assert-True ($Receipt.completed -is [bool] -and $Receipt.completed) 'Native execution incomplete'
    Assert-True ($Receipt.exit_code -is [long] -and $Receipt.exit_code -eq 0) 'Native exit not zero'
    Assert-True ($Receipt.source_unchanged -is [bool] -and $Receipt.source_unchanged) 'Source mutation'
    Assert-True ($Receipt.engine_sha256 -ceq $Engine) 'Engine mismatch'
    Assert-True ($Receipt.source_corpus.file_count -eq 265 -and (Equal-Rows $Receipt.source_corpus.rows $Corpus)) 'Product corpus mismatch'
    Assert-True (-not [regex]::IsMatch($Out+"`n"+$Err,'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use')) 'Script error or shutdown leak'
    $lines=@($Out -split '\r?\n')
    if($Row.kind -ne 'scroll'){Assert-True (@($lines|Where-Object {$_ -ceq $Row.marker}).Count -eq 1) 'Exact PASS marker missing'}
    if($Row.kind -eq 'scroll'){
        $results=@($lines|Where-Object {$_.StartsWith('LEGACY_SCROLL_LIFETIME: ')})
        Assert-True ($results.Count -eq 1) 'Scroll result ambiguous'
        $result=$results[0].Substring('LEGACY_SCROLL_LIFETIME: '.Length)|ConvertFrom-Json -AsHashtable
        Assert-True ($result.ok -is [bool] -and $result.ok -and $result.cases -eq 10 -and $result.checks -eq 16 -and @($result.errors).Count -eq 0) 'Scroll denominator mismatch'
    }elseif($Row.kind -in @('prologue','choice')){
        $prefix=if($Row.kind -eq 'prologue'){'PROLOGUE_ASYNC_AUDIT: '}else{'PROLOGUE_CHOICE_ASYNC_AUDIT: '}
        $results=@($lines|Where-Object {$_.StartsWith($prefix)})
        Assert-True ($results.Count -eq 1) 'Focused result ambiguous'
        $result=$results[0].Substring($prefix.Length)|ConvertFrom-Json -AsHashtable
        Assert-True ($result.ok -is [bool] -and $result.ok -and $result.checks -eq $Row.checks -and @($result.cases).Count -eq $Row.cases) 'Focused denominator mismatch'
    }else{
        $results=@($lines|Where-Object {$_.StartsWith($Row.prefix)})
        Assert-True ($results.Count -eq 1 -and $results[0] -ceq ($Row.prefix+[string]$Row.checks+[string]$Row.suffix)) 'Native assertion denominator mismatch'
    }
}
$manifest=Read-Json (Join-Path $root 'manifest.json')
Assert-True ($manifest.schema_version -eq 1 -and $manifest.base_commit -ceq '65b3c798e5636cde53d8ff5450eb3b3c5da05810') 'Wrong baseline'
Assert-True ($manifest.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00') 'Wrong candidate runtime'
$zip=Join-Path $root 'raw.zip'
Assert-True ((Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant() -ceq $manifest.archive_sha256) 'Raw archive mismatch'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('ggb-basement-proof-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch|Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try{
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $archive.Entries){
        $name=$entry.FullName
        Assert-True (-not [IO.Path]::IsPathRooted($name) -and $name -notmatch '(^|[\\/])\.\.([\\/]|$)' -and $name -notmatch '[:\\]' -and $seen.Add($name)) 'Unsafe or duplicate archive path'
    }
}finally{$archive.Dispose()}
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$scratch,[Text.Encoding]::UTF8)
$actual=@(Get-ChildItem -LiteralPath $scratch -Recurse -File|ForEach-Object {$_.FullName.Substring($scratch.Length+1).Replace('\','/')})
Assert-True ($actual.Count -eq $manifest.files.Count -and @(Compare-Object $actual @($manifest.files|ForEach-Object {$_.path})).Count -eq 0) 'Archive inventory mismatch'
foreach($row in $manifest.files){
    $file=Join-Path $scratch $row.path
    Assert-True ((Get-Item -LiteralPath $file).Length -eq $row.bytes -and (Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -ceq $row.sha256) ('Raw file mismatch: '+$row.path)
}
$corpus=@(Get-ChildItem -LiteralPath (Join-Path $repo 'game/scripts') -Recurse -Filter '*.gd' -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring((Join-Path $repo 'game').Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
Assert-True ($corpus.Count -eq 265 -and (Equal-Rows $manifest.source_corpus $corpus)) 'Delivered source differs from candidate'
foreach($delta in $manifest.changes){
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $scratch ('source/baseline/'+$delta.path))).Hash.ToLowerInvariant() -ceq $delta.baseline_sha256) 'Baseline source mismatch'
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $scratch ('source/candidate/'+$delta.path))).Hash.ToLowerInvariant() -ceq $delta.candidate_sha256 -and (Get-FileHash -LiteralPath (Join-Path $repo $delta.path)).Hash.ToLowerInvariant() -ceq $delta.candidate_sha256) 'Candidate source mismatch'
}
Assert-True ($manifest.runs.Count -eq 8 -and @($manifest.runs|Group-Object name|Where-Object {$_.Count -ne 1}).Count -eq 0) 'Eight final runs required'
$names=@('final-field-v2','final-scroll-ko_KR','final-scroll-en_US','final-full-v2-ko','final-full-ordinary-ko_KR','final-prologue','final-choice','final-save-safety')
Assert-True (@(Compare-Object $names @($manifest.runs|ForEach-Object {$_.name})).Count -eq 0) 'Final execution identity mismatch'
foreach($row in $manifest.runs){
    $receipt=Read-Json (Join-Path $scratch $row.receipt)
    $out=Get-Content -LiteralPath (Join-Path $scratch $row.stdout) -Raw
    $err=Get-Content -LiteralPath (Join-Path $scratch $row.stderr) -Raw
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $scratch $row.stdout)).Hash.ToLowerInvariant() -ceq $receipt.stdout_sha256 -and (Get-FileHash -LiteralPath (Join-Path $scratch $row.stderr)).Hash.ToLowerInvariant() -ceq $receipt.stderr_sha256) 'Receipt/log binding mismatch'
    foreach($key in @('runner_sha256','harness_sha256','base_harness_sha256','scene_sha256')){
        if($receipt[$key]){Assert-True (@($manifest.files|Where-Object {$_.sha256 -ceq $receipt[$key]}).Count -gt 0) ('Executed tool not archived: '+$key)}
    }
    foreach($harness in @($receipt.harnesses)){if($null -ne $harness){Assert-True (@($manifest.files|Where-Object {$_.sha256 -ceq $harness.sha256}).Count -gt 0) 'Executed scroll harness missing'}}
    if($row.kind -in @('field','full')){
        Assert-True ($receipt.mode -ceq $row.kind -and $receipt.arguments -contains '--basement-session-smoke') 'Wrong basement mode'
        if($row.kind -eq 'field'){Assert-True ($receipt.arguments -contains '--basement-field-regression-only') 'Wrong field diagnostic mode'}
        else{Assert-True ($receipt.arguments -notcontains '--basement-field-regression-only') 'Field-only run counted as full'}
        $v2=$row.name -in @('final-field-v2','final-full-v2-ko')
        Assert-True (($receipt.arguments -contains '--ggb-dev-notebook-v2') -eq $v2 -and (($receipt.arguments -contains '--notebook-require-authored') -eq $v2)) 'Notebook mode or authored strictness mismatch'
        $expected=if($row.kind -eq 'field'){203}elseif($v2){14080}else{13925}
        Assert-True ($row.checks -eq $expected) 'Final baseline denominator changed'
    }
    Validate-Run $row $receipt $out $err $corpus $manifest.engine_sha256
}
$baseline=Get-Content -LiteralPath (Join-Path $scratch 'baseline-scroll-expanded/run.out.log') -Raw
$baselineErr=Get-Content -LiteralPath (Join-Path $scratch 'baseline-scroll-expanded/run.err.log') -Raw
$line=@($baseline -split '\r?\n'|Where-Object {$_.StartsWith('LEGACY_SCROLL_LIFETIME: ')})
Assert-True ($line.Count -eq 1) 'Baseline scroll result missing'
$result=$line[0].Substring('LEGACY_SCROLL_LIFETIME: '.Length)|ConvertFrom-Json -AsHashtable
Assert-True ($result.ok -eq $false -and $result.cases -eq 10 -and $result.checks -eq 16 -and @($result.errors).Count -eq 4 -and $baselineErr.Contains('ObjectDB instances leaked')) 'Baseline lifetime failure missing'
foreach($action in @('detach','reenter','replacement','hidden')){Assert-True ($result.errors -contains ('stale history does not change scroll: '+$action)) 'Baseline stale condition missing'}
$field=Get-Content -LiteralPath (Join-Path $scratch 'baseline-field-v2/run.out.log') -Raw
Assert-True ($field.Contains('BASEMENT_FIELD_DIAGNOSTIC_CHECKS: 194') -and $field.Contains('Field notebook leads to physical exit')) 'Baseline field failure missing'
$rejected=0
if($SelfTest){
    $row=$manifest.runs|Where-Object {$_.kind -eq 'field'}|Select-Object -First 1
    $receipt=Read-Json (Join-Path $scratch $row.receipt)
    $out=Get-Content -LiteralPath (Join-Path $scratch $row.stdout) -Raw
    $err=Get-Content -LiteralPath (Join-Path $scratch $row.stderr) -Raw
    foreach($name in @('exit','incomplete','mutated_source','engine','corpus','pass','leak','count')){
        $bad=$receipt|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable
        $badOut=$out;$badErr=$err
        switch($name){
            'exit' {$bad.exit_code=1L}
            'incomplete' {$bad.completed=$false}
            'mutated_source' {$bad.source_unchanged=$false}
            'engine' {$bad.engine_sha256='0'*64}
            'corpus' {$bad.source_corpus.rows=@()}
            'pass' {$badOut=$badOut.Replace($row.marker,'MISSING_PASS')}
            'leak' {$badErr+="`nObjectDB instances leaked"}
            'count' {$badOut=$badOut.Replace($row.prefix+[string]$row.checks,$row.prefix+'0')}
        }
        $caught=$false
        try{Validate-Run $row $bad $badOut $badErr $corpus $manifest.engine_sha256}catch{$caught=$true}
        Assert-True $caught ('Mutation accepted: '+$name)
        $rejected++
    }
}
[ordered]@{ok=$true;checks=$checks;runs=$manifest.runs.Count;source_files=$corpus.Count;archive_files=$actual.Count;rejected_mutations=$rejected;scope='Local basement readiness and legacy scroll lifetime, not OS input or engine adoption';raw_extract=$scratch}|ConvertTo-Json
