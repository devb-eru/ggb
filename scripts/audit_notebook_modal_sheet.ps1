param([Parameter(Mandatory)][string]$EvidencePath, [Parameter(Mandatory)][string]$RepoPath)
$ErrorActionPreference = 'Stop'
$manifest = Get-Content (Join-Path $EvidencePath 'manifest.json') -Raw | ConvertFrom-Json
$archivePath = Join-Path $EvidencePath 'raw.zip'
if ((Get-FileHash -LiteralPath $archivePath).Hash.ToLowerInvariant() -cne $manifest.archive_sha256) { throw 'Raw archive changed' }
$checks = 0
foreach ($file in $manifest.source_files) {
    $path = Join-Path $RepoPath ('game/' + $file.path)
    if ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $file.sha256) { throw ('Source changed: '+$file.path) }
    $checks++
}
if ($manifest.source_files.Count -ne 370) { throw 'Unexpected source/data denominator' }
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    if ($zip.Entries.Count -ne $manifest.raw_files.Count) { throw 'Raw file denominator changed' }
    $files = @{}
    foreach ($file in $manifest.raw_files) {
        if ($files.ContainsKey($file.path)) { throw 'Duplicate manifest path' }
        $entry = $zip.GetEntry($file.path)
        if ($null -eq $entry -or $entry.Length -ne $file.bytes) { throw ('Raw file missing or truncated: '+$file.path) }
        $stream = $entry.Open()
        try {
            $buffer = [IO.MemoryStream]::new()
            $stream.CopyTo($buffer)
            $bytes = $buffer.ToArray()
            $buffer.Dispose()
        } finally { $stream.Dispose() }
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        if ($hash -cne $file.sha256) { throw ('Raw file changed: '+$file.path) }
        $files[$file.path] = [Text.Encoding]::UTF8.GetString($bytes)
        $checks++
    }
    $pids = @()
    foreach ($phase in @('seed','resume','completed')) {
        $receipt = $files['final/'+$phase+'.json'] | ConvertFrom-Json
        if (-not $receipt.completed -or $receipt.exit_code -ne 0) { throw ('Native phase failed: '+$phase) }
        if ($receipt.source.changed_sha256 -cne $manifest.test_sha256) { throw 'Receipt source differs' }
        $stdout = $files['final/'+$phase+'.out.log']
        $stderr = $files['final/'+$phase+'.err.log']
        if ($stdout -notmatch 'NOTEBOOK_MODAL_PRESENTATION_SMOKE: PASS' -or ($stdout+$stderr) -match 'SCRIPT ERROR:|Parse Error:|(?m)^ERROR:') { throw ('Phase log failed: '+$phase) }
        $expected = @{seed=980;resume=7;completed=4}[$phase]
        if ($stdout -notmatch ('NOTEBOOK_MODAL_PRESENTATION_CHECKS: '+$phase+' '+$expected+'\b')) { throw 'Assertion denominator changed' }
        $pids += $receipt.pid
        $checks += 4
    }
    if (@($pids | Sort-Object -Unique).Count -ne 3) { throw 'Phases did not use separate processes' }
    $baseline = $files['baseline/run.json'] | ConvertFrom-Json
    $intermediate = $files['intermediate/seed.json'] | ConvertFrom-Json
    if ($baseline.exit_code -ne 1 -or $intermediate.exit_code -ne 1) { throw 'Failed diagnostics were relabeled' }
    $checks += 2
} finally { $zip.Dispose() }
[pscustomobject]@{ok=$true;checks=$checks;native_phases=3;assertions=991;scope='modal regression; not Windows input or full acceptance'} | ConvertTo-Json
