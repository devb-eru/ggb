param([Parameter(Mandatory)][string]$EnginePath,[Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$EvidencePath,[ValidateSet('focused','foundation','ui')][string]$Mode='focused',[ValidateRange(1,1800)][int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$engine=(Resolve-Path -LiteralPath $EnginePath).Path
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not ($project+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))){throw 'Use isolated TEMP project'}
if(-not ($evidence+'\').StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $evidence)){throw 'Use new TEMP evidence'}
function Get-Corpus {
    $rows=@(Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Filter '*.gd' -Recurse -File | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($project.Length+1).Replace('\','/')+"`t"+(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()})
    [ordered]@{file_count=$rows.Count;rows=$rows}
}
New-Item -ItemType Directory -Path $evidence | Out-Null
$source=Get-Corpus
$harnesses=@()
$argsList=@('--headless','--path',('"'+$project+'"'))
if($Mode -ne 'foundation'){
    $dir=Join-Path $project ('__reset_async_'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $names=@('notebook_history_async_audit.gd','notebook_reset_async_audit.gd','notebook_reset_async_audit.tscn')
    if($Mode -eq 'ui'){$names+=@('notebook_prologue_async_audit.gd','notebook_prologue_surface_async_audit.gd','notebook_prologue_natural_async_audit.gd','notebook_reset_ui_audit.gd','notebook_reset_ui_audit.tscn')}
    foreach($name in $names){
        $destination=Join-Path $dir $name
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tests/'+$name)) -Destination $destination
        $harnesses+=@{name=$name;sha256=(Get-FileHash -LiteralPath $destination).Hash.ToLowerInvariant()}
    }
    $argsList+=('"'+(Join-Path $dir $(if($Mode -eq 'ui'){'notebook_reset_ui_audit.tscn'}else{'notebook_reset_async_audit.tscn'}))+'"')
}
$argsList+=@('--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored')
if($Mode -eq 'foundation'){$argsList+='--foundation-smoke'}
$stdout=Join-Path $evidence 'run.out.log';$stderr=Join-Path $evidence 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $evidence 'appdata';$env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $version=(& $engine --headless --version | Out-String).Trim()
    $start=[DateTime]::UtcNow.ToString('o')
    $child=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Output ('Reset '+$Mode+' PID='+$child.Id+' evidence='+$evidence)
    $finished=$child.WaitForExit($TimeoutSeconds*1000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    $receipt=[ordered]@{mode=$Mode;completed=$finished;exit_code=$child.ExitCode;started_utc=$start;finished_utc=[DateTime]::UtcNow.ToString('o');engine_version=$version;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant();runner_sha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();harnesses=$harnesses;source_corpus=$source;source_unchanged=(($source | ConvertTo-Json -Depth 6 -Compress) -ceq ((Get-Corpus) | ConvertTo-Json -Depth 6 -Compress));stdout_sha256=(Get-FileHash -LiteralPath $stdout).Hash.ToLowerInvariant();stderr_sha256=(Get-FileHash -LiteralPath $stderr).Hash.ToLowerInvariant()}
    [IO.File]::WriteAllText((Join-Path $evidence 'run.json'),($receipt | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    if(-not $finished -or $child.ExitCode -ne 0 -or -not $receipt.source_unchanged -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet)){throw 'Native/script/source failure'}
    $lines=@(Get-Content -LiteralPath $stdout)
    $marker=switch($Mode){'focused'{'RESET_ASYNC_SMOKE:PASS'}'ui'{'RESET_UI_SMOKE:PASS'}'foundation'{'FOUNDATION_SMOKE: PASS'}}
    if(@($lines | Where-Object {$_ -ceq $marker}).Count -ne 1){throw 'Exact PASS missing'}
    if($Mode -ne 'foundation'){
        $prefix=if($Mode -eq 'focused'){'RESET_ASYNC_AUDIT: '}else{'RESET_UI_AUDIT: '}
        $summary=@($lines | Where-Object {$_.StartsWith($prefix)})
        if($summary.Count -ne 1){throw 'Ambiguous focused result'}
        $result=$summary[0].Substring($prefix.Length) | ConvertFrom-Json
        [IO.File]::WriteAllText((Join-Path $evidence 'run.result.json'),($result | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
        $count=if($Mode -eq 'focused'){136}else{16}
        if(-not $result.ok -or $result.required_cases -ne $count -or @($result.cases).Count -ne $count){throw 'Result/denominator mismatch'}
        [pscustomobject]@{checks=$result.checks;cases=$result.cases.Count;native=$child.ExitCode}
    }else{$lines | Where-Object {$_ -match 'SMOKE:|CASES:'}}
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
