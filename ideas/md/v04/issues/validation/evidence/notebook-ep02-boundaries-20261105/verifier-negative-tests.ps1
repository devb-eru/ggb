param([Parameter(Mandatory)][string]$RepoPath)
$ErrorActionPreference='Stop'
$audit=Join-Path $RepoPath 'scripts/audit_notebook_ep02_modal_boundaries.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ggb-ep02-audit-negative-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
function HashBytes([byte[]]$bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
$results=@()
foreach($name in @('archive-hash','source-denominator','raw-hash','selected-observation','ram-disk')){
    $fixture=Join-Path $temp $name
    New-Item -ItemType Directory -Path $fixture|Out-Null
    $archive=Join-Path $fixture 'raw.zip'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'raw.zip') -Destination $archive
    $manifest=Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw|ConvertFrom-Json -AsHashtable
    switch($name){
        'archive-hash' {$manifest.archive_sha256='0'*64;$expected='Archive hash differs'}
        'source-denominator' {$manifest.source_files=@($manifest.source_files|Select-Object -Skip 1);$expected='Frozen source denominator differs'}
        'raw-hash' {$manifest.raw_files[0].sha256='0'*64;$expected='Raw hash differs'}
        default {
            $zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Update)
            try{
                $entry=$zip.GetEntry('boundaries/trace.json')
                $reader=[IO.StreamReader]::new($entry.Open())
                try{$trace=$reader.ReadToEnd()|ConvertFrom-Json -AsHashtable}finally{$reader.Dispose()}
                $row=$trace.cases|Where-Object case_id -CEQ 'answer/0/false'|Select-Object -First 1
                if($name -ceq 'selected-observation'){
                    foreach($state in @($row.snapshot,$row.disk)){
                        $observation=$state.meta_progress.dialogue_history.entries|Where-Object {$_.observation.content_id -ceq 'NB_EP02_CHOICE_C4_COMMIT_SELECT_0'}
                        if(@($observation).Count -ne 1){throw 'Negative fixture selection missing'}
                        $observation.observation.content_id='NB_EP02_CHOICE_C4_COMMIT_SELECT_1'
                    }
                    $expected='Rejected/unselected answer was disclosed'
                }else{
                    $row.disk.loop_state.event_local_states.BLACK_MIRROR.cleaner_ready=$false
                    $expected='Trace RAM/disk differs'
                }
                $entry.Delete()
                $entry=$zip.CreateEntry('boundaries/trace.json')
                $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
                try{$writer.Write(($trace|ConvertTo-Json -Depth 100 -Compress))}finally{$writer.Dispose()}
            }finally{$zip.Dispose()}
            # Reseal the mutation so rejection must come from semantic checks.
            $zip=[IO.Compression.ZipFile]::OpenRead($archive)
            try{
                $manifest.raw_files=@(foreach($entry in $zip.Entries){
                    $stream=$entry.Open();$memory=[IO.MemoryStream]::new()
                    try{$stream.CopyTo($memory);$bytes=$memory.ToArray()}finally{$stream.Dispose();$memory.Dispose()}
                    @{path=$entry.FullName;bytes=$bytes.Length;sha256=(HashBytes $bytes)}
                })
            }finally{$zip.Dispose()}
            $manifest.archive_sha256=(Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant()
        }
    }
    [IO.File]::WriteAllText((Join-Path $fixture 'manifest.json'),($manifest|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
    $rejected=$false;$reason=''
    try{& $audit -EvidencePath $fixture -RepoPath $RepoPath|Out-Null}catch{$rejected=$true;$reason=$_.Exception.Message}
    $results+=@{name=$name;passed=($rejected -and $reason.StartsWith($expected));rejected=$rejected;reason=$reason;expected=$expected}
}
$record=@{utc=[DateTime]::UtcNow.ToString('o');command='./verifier-negative-tests.ps1 -RepoPath <mirror>';fixture_root=$temp;verifier_sha256=(Get-FileHash -LiteralPath $audit).Hash.ToLowerInvariant();tests=$results;passed=@($results|Where-Object passed -EQ $true).Count;total=$results.Count}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'verifier-negative-tests.json'),($record|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
$record|ConvertTo-Json -Depth 10
if($record.passed -ne $record.total){throw 'Verifier negative tests failed'}
