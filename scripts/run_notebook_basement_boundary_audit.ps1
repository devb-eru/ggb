param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateSet('scroll','field','full')][string]$Mode='full',
    [ValidateSet('ordinary','v2')][string]$Notebook='v2',
    [ValidateSet('ko_KR','en_US')][string]$Locale='ko_KR',
    [ValidateRange(1,1800)][int]$TimeoutSeconds=1200,
    [switch]$Baseline
)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use an isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
function Get-Corpus {
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File|Sort-Object FullName|ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    @{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence|Out-Null
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $evidence 'runner.ps1')
$source=Get-Corpus
$arguments=@('--headless','--verbose','--language',$Locale,'--path',('"'+$project+'"'))
$harnesses=@()
if($Mode -eq 'scroll'){
    $name='__legacy_scroll_'+[guid]::NewGuid().ToString('N')
    $directory=Join-Path $project $name
    New-Item -ItemType Directory -Path $directory|Out-Null
    foreach($file in @('notebook_legacy_scroll_lifetime.gd','notebook_legacy_scroll_lifetime.tscn')){
        $target=Join-Path $directory $file
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$file)) -Destination $target
        if($file.EndsWith('.tscn')){
            $text=[IO.File]::ReadAllText($target)
            if(-not $text.Contains('res://__boundary/')){throw 'Unexpected scene template'}
            [IO.File]::WriteAllText($target,$text.Replace('res://__boundary/','res://'+$name+'/'),[Text.UTF8Encoding]::new($false))
        }
        Copy-Item -LiteralPath $target -Destination (Join-Path $evidence $file)
        $harnesses+=@{name=$file;sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()}
    }
    $arguments+=('"'+(Join-Path $directory 'notebook_legacy_scroll_lifetime.tscn')+'"')
    if($Notebook -eq 'v2'){$arguments+=@('--','--ggb-dev-notebook-v2','--notebook-require-authored')}
}else{
    $arguments+=@('--','--basement-session-smoke')
    if($Mode -eq 'field'){$arguments+='--basement-field-regression-only'}
    if($Notebook -eq 'v2'){$arguments+=@('--ggb-dev-notebook-v2','--notebook-require-authored')}
}
$out=Join-Path $evidence 'run.out.log';$err=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $evidence 'appdata';$env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA|Out-Null
    $started=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    Write-Output ('Basement boundary PID='+$child.Id+' mode='+$Mode+' notebook='+$Notebook+' locale='+$Locale+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $clean=$finished -and $null -ne $child.ExitCode -and $child.ExitCode -eq 0 -and -not (Select-String -LiteralPath $out,$err -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ObjectDB instances leaked|resources still in use' -Quiet)
    $lines=@(Get-Content -LiteralPath $out)
    if($Mode -eq 'scroll'){
        $summaries=@($lines|Where-Object {$_.StartsWith('LEGACY_SCROLL_LIFETIME: ')})
        if($summaries.Count -eq 1){$result=$summaries[0].Substring('LEGACY_SCROLL_LIFETIME: '.Length)|ConvertFrom-Json;$clean=$clean -and $result.ok -and $result.cases -eq 10 -and $result.checks -eq 16 -and @($result.errors).Count -eq 0}else{$clean=$false}
    }else{
        $clean=$clean -and @($lines|Where-Object {$_ -ceq 'BASEMENT_SESSION_SMOKE: PASS'}).Count -eq 1
        $prefix=if($Mode -eq 'field'){'BASEMENT_FIELD_DIAGNOSTIC_CHECKS: '}else{'BASEMENT_SESSION_CHECKS: '}
        $clean=$clean -and @($lines|Where-Object {$_.StartsWith($prefix)}).Count -eq 1
    }
    $unchanged=([string]::Join("`n",$source.rows) -ceq [string]::Join("`n",(Get-Corpus).rows))
    $receipt=@{schema_version=1;baseline=[bool]$Baseline;mode=$Mode;notebook=$Notebook;locale=$Locale;arguments=$arguments;pid=$child.Id;started_utc=$started;finished_utc=[DateTime]::UtcNow.ToString('o');completed=$finished;terminated_by_runner=(-not $finished);exit_code=$child.ExitCode;ok=($clean -and $unchanged);source_corpus=$source;source_unchanged=$unchanged;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;stdout_sha256=(Get-FileHash -LiteralPath $out).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $err).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    if(-not $unchanged){throw 'Product source changed during execution'}
    if(-not $Baseline -and -not $receipt.ok){throw 'Basement boundary execution failed; raw evidence retained'}
    Write-Output ('BASEMENT_BOUNDARY_RECEIPT: '+($receipt|Select-Object mode,notebook,locale,completed,exit_code,ok|ConvertTo-Json -Compress))
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
