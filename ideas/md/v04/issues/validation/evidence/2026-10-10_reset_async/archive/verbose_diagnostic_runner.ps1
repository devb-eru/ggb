$ErrorActionPreference='Stop'
$m=Get-Content (Join-Path $PSScriptRoot '.tmp-reset-worker-run.json') -Raw | ConvertFrom-Json
$receipt=Get-Content (Join-Path $m.root 'final-ui-cleanup/run.json') -Raw | ConvertFrom-Json
$sha=($receipt.harnesses | Where-Object {$_.name -eq 'notebook_reset_ui_audit.gd'}).sha256
$dirs=@(Get-ChildItem -LiteralPath $m.project -Directory -Filter '__reset_async_*' | Where-Object {(Test-Path -LiteralPath (Join-Path $_.FullName 'notebook_reset_ui_audit.gd')) -and ((Get-FileHash -LiteralPath (Join-Path $_.FullName 'notebook_reset_ui_audit.gd')).Hash.ToLowerInvariant()) -ceq $sha})
if($dirs.Count -ne 1){throw 'UI harness identity unclear'}
$dir=Join-Path $m.root 'ui-verbose'
New-Item -ItemType Directory -Path $dir | Out-Null
$out=Join-Path $dir 'run.out.log';$err=Join-Path $dir 'run.err.log'
$oldApp=$env:APPDATA;$oldLocal=$env:LOCALAPPDATA;$child=$null
try{
    $env:APPDATA=Join-Path $dir 'appdata';$env:LOCALAPPDATA=Join-Path $dir 'localappdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $child=Start-Process -FilePath $m.engine -ArgumentList @('--headless','--verbose','--path',('"'+$m.project+'"'),('"'+(Join-Path $dirs[0].FullName 'notebook_reset_ui_audit.tscn')+'"'),'--','--ggb-dev-notebook-v2','--ggb-dev-notebook-async','--notebook-require-authored') -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    'Owned verbose PID='+$child.Id
    $finished=$child.WaitForExit(180000)
    if(-not $finished){$child.Kill();$child.WaitForExit()}
    if(-not $finished -or $child.ExitCode -ne 0){throw 'Verbose UI failed'}
    Select-String -LiteralPath $out,$err -Pattern 'Leaked|leaked|resources still|Orphan' -Context 0,2
}finally{if($null -ne $child -and -not $child.HasExited){$child.Kill();$child.WaitForExit()};$env:APPDATA=$oldApp;$env:LOCALAPPDATA=$oldLocal}
