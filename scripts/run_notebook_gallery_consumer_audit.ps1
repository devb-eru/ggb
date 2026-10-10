param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('consumer','migration','query')][string]$Mode='consumer',
    [switch]$ExpectFailure,
    [ValidateRange(1,3600)][int]$TimeoutSeconds=1200
)
$ErrorActionPreference='Stop'
if ($ExpectFailure -and $Mode -ne 'consumer') { throw 'Expected failure only for focused reproduction' }
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if (-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) { throw 'Use isolated TEMP project' }
if (-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)) { throw 'Use new TEMP evidence directory' }
function Corpus([string]$Folder,[string]$Filter) {
    [string[]]$paths=@(Get-ChildItem -LiteralPath (Join-Path $project $Folder) -Filter $Filter -Recurse -File|ForEach-Object FullName)
    [Array]::Sort($paths,[StringComparer]::Ordinal)
    $rows=@($paths|ForEach-Object {'res://'+$_.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()})
    $sha=[Security.Cryptography.SHA256]::Create()
    try {$hash=[Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))).ToLowerInvariant()} finally {$sha.Dispose()}
    [ordered]@{file_count=$paths.Count;sha256=$hash;rows=$rows}
}
$source=Corpus 'scripts' '*.gd';$data=Corpus 'data' '*'
New-Item -ItemType Directory -Path $evidence|Out-Null
$argsList=@('--headless','--path',('"'+$project+'"'))
$fixture=$null;$scene=$null
if ($Mode -eq 'consumer') {
    $dir=Join-Path $project ('__gallery_consumer_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir|Out-Null
    foreach ($name in @('notebook_gallery_consumer_audit.gd','notebook_gallery_consumer_audit.tscn')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $dir}
    $fixture=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_gallery_consumer_audit.gd')).Hash.ToLowerInvariant()
    $scene=(Get-FileHash -LiteralPath (Join-Path $dir 'notebook_gallery_consumer_audit.tscn')).Hash.ToLowerInvariant()
    $argsList+=('"'+(Join-Path $dir 'notebook_gallery_consumer_audit.tscn')+'"')
}
$argsList+=@('--','--ggb-dev-notebook-v2','--notebook-require-authored')
if ($Mode -eq 'query') {$argsList+='--notebook-query-smoke'}
if ($Mode -eq 'migration') {$argsList+='--notebook-migration-smoke'}
$stdout=Join-Path $evidence ($Mode+'.out.log');$stderr=Join-Path $evidence ($Mode+'.err.log')
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try {
    $env:APPDATA=Join-Path $evidence 'appdata';$env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA|Out-Null
    $version=(& $engine --headless --version|Out-String).Trim()
    $started=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ($Mode+': PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if (-not $finished) {$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{schema_version=1;mode=$Mode;completed=$finished;exit_code=$child.ExitCode;expected_failure=$ExpectFailure.IsPresent;require_authored=$true;
        started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();
        runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();fixture_sha256=$fixture;scene_sha256=$scene;source_corpus=$source;data_corpus=$data;
        source_unchanged=(($source|ConvertTo-Json -Depth 5 -Compress) -ceq ((Corpus 'scripts' '*.gd')|ConvertTo-Json -Depth 5 -Compress));
        data_unchanged=(($data|ConvertTo-Json -Depth 5 -Compress) -ceq ((Corpus 'data' '*')|ConvertTo-Json -Depth 5 -Compress));
        stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence ($Mode+'.run.json')),($receipt|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if (-not $finished -or -not $receipt.source_unchanged -or -not $receipt.data_unchanged -or
        (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)) {throw 'Timeout, script error or corpus mutation'}
    $marker=switch ($Mode) {'consumer' {'NOTEBOOK_GALLERY_CONSUMER_SMOKE:'} 'migration' {'NOTEBOOK_MIGRATION_SMOKE: '} 'query' {'NOTEBOOK_QUERY_SMOKE: '}}
    $lines=@(Get-Content -LiteralPath $stdout)
    if ($Mode -eq 'consumer') {
        $summaries=@($lines|Where-Object {$_.StartsWith('NOTEBOOK_GALLERY_CONSUMER_AUDIT: ')})
        if ($summaries.Count -ne 1) {throw 'Missing consumer summary'}
        $result=$summaries[0].Substring('NOTEBOOK_GALLERY_CONSUMER_AUDIT: '.Length)|ConvertFrom-Json
        [IO.File]::WriteAllText((Join-Path $evidence 'consumer.result.json'),($result|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
        [pscustomobject]@{ok=$result.ok;checks=$result.checks;cases=$result.cases.Count;writes=$result.writes.Count;errors=$result.errors.Count}|ConvertTo-Json
    }
    $expected=$marker+$(if ($ExpectFailure) {'FAIL'} else {'PASS'})
    if (@($lines|Where-Object {$_ -ceq $expected}).Count -ne 1 -or $child.ExitCode -ne $(if ($ExpectFailure) {1} else {0})) {throw 'Native status or exact marker mismatch'}
    if ($Mode -ne 'consumer') {$lines|Where-Object {$_ -match 'SMOKE:|CHECKS:|ASSERTIONS:'}}
} finally {
    if ($null -ne $child -and -not $child.HasExited) {$child.Kill();$child.WaitForExit()}
    $env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal
}
