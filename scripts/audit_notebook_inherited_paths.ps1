param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Prefix = 'inherited-paths',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
function Assert-Condition([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Result($Result) {
    Assert-Condition ($Result.schema_version -eq 1 -and $Result.suite_id -ceq 'inherited-paths' -and $Result.ok -and @($Result.errors).Count -eq 0) 'Invalid result status'
    # Required calls follow controller overrides, not the catalog allowed-node Cartesian product.
    $mirror = @('C_SLEEP','C0','C1','C2','C3','C_BELL','C4','CF','C5_INFO','J3')
    $basement = @('D_SLEEP','D0','D0_A','D1','DF','D2','D4')
    $expected = @{}
    $absent = @{}
    foreach ($locale in @('ko-KR','en-US')) {
        foreach ($stage in ($mirror + $basement)) {
            $calls = @()
            foreach ($owner in @('edgar','luca','mara1','mara2')) {
                $calls += ,@('M1_SERVANT_COMMON', ('DOC_' + $owner), ('NB_CH1_CH1_B1_TEXT_' + $owner.ToUpperInvariant()), ('NB_CH1_NOTE_B1_' + $owner.ToUpperInvariant()))
            }
            $calls += ,@('M2_BEDROOM','AS_ROUTINE','NB_CH1_ROUTINE','')
            $calls += ,@('M1_NORTH_ARCHIVE_HALL','MARA2_MEMORY','NB_CH1_MARA2_MEMORY','')
            foreach ($clock in @(@('M1_PARLOR','PARLOR'), @('M1_LIBRARY_OUTER','LIBRARY_OUTER'))) {
                $calls += ,@($clock[0], 'RUB_CLOCK', ('NB_CH1_CH1_CLOCK_' + $clock[1]), ('NB_CH1_NOTE_CLOCK_' + $clock[1]))
            }
            if ($stage -cin $mirror) {
                $calls += ,@('M2_BEDROOM','RUB_CLOCK','NB_CH1_CH1_CLOCK_BEDROOM','NB_CH1_NOTE_CLOCK_BEDROOM')
            } else { $absent["$stage/M2_BEDROOM/RUB_CLOCK/$locale"] = $true }
            foreach ($target in @('desk','index','drawer','alcove','gap','link')) {
                if ($stage -cin $mirror -and $stage -cne 'J3') {
                    $suffix = if ($target -ceq 'link') { 'LINK_OPEN' } else { $target.ToUpperInvariant() }
                    $calls += ,@('M1_LIBRARY_INNER', ('INNER_' + $target), ('NB_CH1_CH1_INNER_' + $suffix), '')
                } else { $absent["$stage/M1_LIBRARY_INNER/INNER_$target/$locale"] = $true }
            }
            $absent["$stage/M1_GREAT_CLOCK/RUB_CLOCK/$locale"] = $true
            foreach ($call in $calls) {
                $key = "$stage/$($call[0])/$($call[1])/$locale"
                $expected[$key] = @{stage=$stage;room=$call[0];button=$call[1];content=$call[2];note=$call[3];locale=$locale}
            }
        }
    }
    Assert-Condition ($expected.Count -eq 400 -and $absent.Count -eq 144) 'Independent denominator changed'
    Assert-Condition ($Result.required_action_cases -eq 400 -and $Result.required_exclusion_cases -eq 144) 'Reported denominator differs'
    Assert-Condition (@($Result.cases).Count -eq 400 -and @($Result.exclusions).Count -eq 144) 'Incomplete result'
    $seen = @{}
    $written = 0
    $baseline = 0
    $tupleCount = 0
    foreach ($case in $Result.cases) {
        Assert-Condition ($expected.ContainsKey($case.key) -and -not $seen.ContainsKey($case.key)) ('Unexpected or duplicate call: ' + $case.key)
        $seen[$case.key] = $true
        $e = $expected[$case.key]
        Assert-Condition ($case.stage -ceq $e.stage -and $case.location -ceq $e.room -and $case.button -ceq $e.button -and $case.content -ceq $e.content -and $case.note -ceq $e.note) 'Reported call identity differs'
        Assert-Condition (@($case.passes).Count -eq 2 -and $case.baseline_count -ge 0) 'First/repeat or baseline missing'
        $baseline += $case.baseline_count
        $attempt = 0
        foreach ($pass in $case.passes) {
            $attempt++
            Assert-Condition ($pass.attempt -eq $attempt -and $pass.new_entry_count -gt 0 -and $pass.archive_sha256 -cmatch '^[0-9a-f]{64}$') 'Missing committed pass'
            $written += $pass.new_entry_count
            $found = $false
            $noteFound = [string]::IsNullOrEmpty($e.note) -or $attempt -eq 2
            foreach ($tuple in $pass.tuples) {
                $tupleCount++
                Assert-Condition (@($tuple).Count -eq 7 -and $tuple[6] -ceq $e.locale) 'Invalid observed tuple'
                if ($tuple[0] -cin @('NP04','NP06')) {
                    Assert-Condition ($tuple[3] -ceq $e.stage) 'Inherited action captured wrong stage'
                }
                if ($tuple[1] -ceq $e.content) { Assert-Condition ($tuple[0] -ceq 'NP04') 'Dialogue producer changed'; $found = $true }
                if ($tuple[1] -ceq $e.note) { Assert-Condition ($tuple[0] -ceq 'NP06') 'Acquisition producer changed'; $noteFound = $true }
            }
            Assert-Condition ($found -and $noteFound) 'Expected actual action/acquisition missing'
        }
    }
    $seenExcluded = @{}
    foreach ($case in $Result.exclusions) {
        Assert-Condition ($absent.ContainsKey($case.key) -and -not $seenExcluded.ContainsKey($case.key)) ('Unexpected or duplicate exclusion: ' + $case.key)
        $seenExcluded[$case.key] = $true
    }
    Assert-Condition ($Result.new_entry_classes.authored -eq $written -and $Result.new_entry_classes.legacy -eq 0 -and $Result.new_entry_classes.unmapped -eq 0) 'New-record classes differ from per-call deltas'
    Assert-Condition (($Result.baseline_entry_classes.authored + $Result.baseline_entry_classes.legacy + $Result.baseline_entry_classes.unmapped) -eq $baseline) 'Baseline incorrectly mixed into new writes'
    return [pscustomobject]@{action_cases=400;actual_dispatches=800;excluded_control_cases=144;new_entries=$written;baseline_entries=$baseline;observed_segment_tuples=$tupleCount}
}
$raw = Join-Path $EvidencePath ($Prefix + '.out.log')
$stderr = Join-Path $EvidencePath ($Prefix + '.err.log')
$receipt = Get-Content -LiteralPath (Join-Path $EvidencePath ($Prefix + '.run.json')) -Raw | ConvertFrom-Json
Assert-Condition ($receipt.schema_version -eq 1 -and $receipt.completed -and $receipt.exit_code -eq 0 -and $receipt.require_authored) 'Incomplete native strict receipt'
Assert-Condition (((Get-FileHash -LiteralPath $raw).Hash -ieq $receipt.stdout_sha256) -and ((Get-FileHash -LiteralPath $stderr).Hash -ieq $receipt.stderr_sha256)) 'Raw evidence hash differs'
$lines = @(Get-Content -LiteralPath $raw)
Assert-Condition (@($lines | Where-Object { $_ -ceq 'NOTEBOOK_INHERITED_PATH_SMOKE:PASS' }).Count -eq 1) 'Exact PASS missing'
Assert-Condition (-not (Select-String -LiteralPath $raw,$stderr -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|INHERITED_PATH_ASSERT:' -Quiet)) 'Runtime error reported'
$summaries = @($lines | Where-Object { $_.StartsWith('NOTEBOOK_INHERITED_PATH_AUDIT: ') })
Assert-Condition ($summaries.Count -eq 1) 'Multiple or missing summaries'
$result = $summaries[0].Substring('NOTEBOOK_INHERITED_PATH_AUDIT: '.Length) | ConvertFrom-Json
$checks = Assert-Result $result
foreach ($pair in @(@('scripts/tests/notebook_inherited_path_audit.gd','harness_sha256'),@('scripts/tests/notebook_inherited_paths.tscn','scene_sha256'),@('scripts/run_notebook_inherited_paths.ps1','runner_sha256'))) {
    Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $Root $pair[0])).Hash -ieq $receipt.($pair[1])) ('Test source differs: ' + $pair[0])
}
Assert-Condition ($result.harness_sha256 -ceq $receipt.harness_sha256) 'Runtime harness differs'
$game = Join-Path $Root 'game'
$paths = [Collections.Generic.List[string]]::new()
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $game 'scripts') -Recurse -File -Filter '*.gd') {
    $paths.Add('res://' + [IO.Path]::GetRelativePath($game, $file.FullName).Replace('\','/'))
}
$paths.Sort([StringComparer]::Ordinal)
$rows = foreach ($path in $paths) { $path + "`t" + (Get-FileHash -LiteralPath (Join-Path $game $path.Substring(6))).Hash.ToLowerInvariant() }
$bytes = [Text.Encoding]::UTF8.GetBytes($rows -join "`n")
$digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
Assert-Condition ($result.source_corpus.file_count -eq $paths.Count -and $result.source_corpus.sha256 -ceq $digest) 'Stale game script corpus'
Assert-Condition (@($result.catalog_fingerprints.PSObject.Properties).Count -eq 29) 'Catalog fingerprint count changed'
foreach ($property in $result.catalog_fingerprints.PSObject.Properties) {
    Assert-Condition ((Get-FileHash -LiteralPath (Join-Path $game $property.Name.Substring(6))).Hash -ieq $property.Value) ('Stale catalog: ' + $property.Name)
}
$negativeChecks = @()
if ($SelfTest) {
    foreach ($kind in @('duplicate_call','missing_repeat','wrong_node','new_unmapped','missing_exclusion')) {
        $mutant = $result | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        switch ($kind) {
            'duplicate_call' { $mutant.cases[1] = $mutant.cases[0] }
            'missing_repeat' { $mutant.cases[0].passes = @($mutant.cases[0].passes[0]) }
            'wrong_node' { $mutant.cases[0].passes[0].tuples[0][3] = 'A1' }
            'new_unmapped' { $mutant.new_entry_classes.unmapped = 1 }
            'missing_exclusion' { $mutant.exclusions = @($mutant.exclusions | Select-Object -Skip 1) }
        }
        $rejected = $false
        try { $null = Assert-Result $mutant } catch { $rejected = $true }
        Assert-Condition $rejected ('Validator accepted invalid evidence: ' + $kind)
        $negativeChecks += $kind
    }
}
[ordered]@{ok=$true;checks=$checks;source_corpus=$result.source_corpus;catalogs=29;test_source_hashes_match=$true;raw_hashes_match=$true;negative_checks=$negativeChecks;not_covered=$result.not_covered} | ConvertTo-Json -Depth 8
