param([Parameter(Mandatory)][string]$EvidencePath,[string]$ArtifactRoot,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $EvidencePath).Path
$repo=Split-Path -Parent $PSScriptRoot
$checks=0
function Require([bool]$Ok,[string]$Message) {$script:checks++;if (-not $Ok) {throw $Message}}
function Sha([string]$Path) {(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
function HashText([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try {[Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()} finally {$sha.Dispose()}
}
$provenance=Get-Content -LiteralPath (Join-Path $root 'provenance.json') -Raw|ConvertFrom-Json
Require ($provenance.head -ceq 'f5ffcfb34e0ad82121592ee9b443f6a198b9f39e' -and $provenance.product_files -eq 640 -and @($provenance.rows).Count -eq 640) 'Product provenance/denominator'
$official=Get-Content (Join-Path $root 'official_release.json') -Raw|ConvertFrom-Json
$template=@($official.assets|Where-Object {$_.name -ceq 'Godot_v4.6.3-stable_export_templates.tpz'})
Require ($official.tag_name -ceq '4.6.3-stable' -and $template.Count -eq 1 -and $template[0].id -eq $provenance.template_asset_id -and $template[0].digest -ceq ('sha256:'+$provenance.templates_sha256) -and $template[0].size -eq 1255918323 -and $provenance.templates_sha256 -ceq '3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8') 'Official archive provenance'
$expected=@{}
foreach ($row in $provenance.rows) {
    $parts=$row.Split("`t")
    Require ($parts.Count -eq 2 -and $parts[0].StartsWith('game/') -and $parts[0] -notmatch '\.\.' -and -not $expected.ContainsKey($parts[0].Substring(5))) 'Safe unique committed path'
    Require ((Sha (Join-Path $repo $parts[0])) -ceq $parts[1]) 'Current product differs from committed candidate'
    $expected[$parts[0].Substring(5)]=$parts[1]
}
$projectText=[IO.File]::ReadAllText((Join-Path $repo 'game/project.godot'))
$probeText=$projectText.Replace('run/main_scene="res://scenes/main/main.tscn"','run/main_scene="res://__release_probe/windows_release_probe.tscn"')
Require ($probeText -cne $projectText) 'Probe entry mapping missing'
$probeProjectHash=HashText $probeText
$uids=@('scripts/tests/notebook_runtime_audit.gd.uid','scripts/tests/notebook_scope_smoke.gd.uid','scripts/tests/notebook_substitution_smoke.gd.uid','scripts/tests/notebook_view_future_smoke.gd.uid')
$probeFiles=@('__release_probe/windows_release_probe.gd','__release_probe/windows_release_probe.tscn')
$receipts=@{}
function Check-Receipt($Receipt,[string]$Id) {
    $probe=$Id.StartsWith('compatibility') -or $Id.StartsWith('probe_')
    $mode=if ($Id -eq 'startup_verified') {'startup'} elseif ($Id.StartsWith('probe_')) {'probe'} else {'build'}
    Require ($Receipt.schema_version -eq 1 -and $Receipt.ok -eq $true -and $Receipt.mode -ceq $mode -and $Receipt.source_unchanged -eq $true) 'Native receipt status/mode'
    Require ($Receipt.engine_version -ceq '4.6.3.stable.official.7d41c59c4' -and $Receipt.engine_sha256 -ceq 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00' -and
        $Receipt.template_version -ceq '4.6.3.stable' -and $Receipt.template_sha256 -ceq '91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6') 'Exact official engine/release template'
    Require ($Receipt.runner_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'run_windows_release_candidate.ps1'))) 'Current runner provenance'
    $requiredExtra=if ($Id -eq 'compatibility_build') {$probeFiles} elseif ($probe) {$probeFiles+$uids+@('__release_probe/windows_release_probe.gd.uid')} else {$uids}
    $seen=@{}
    foreach ($row in $Receipt.source_rows) {
        $parts=$row.Split("`t")
        Require ($parts.Count -eq 2 -and -not $seen.ContainsKey($parts[0])) 'Unique native source row'
        $path=$parts[0];$seen[$path]=$true
        if ($expected.ContainsKey($path)) {
            $hash=if ($probe -and $path -ceq 'project.godot') {$probeProjectHash} else {$expected[$path]}
            Require ($parts[1] -ceq $hash) 'Original product source differs in release probe'
        } elseif ($path -in $probeFiles -and $probe) {
            Require ($parts[1] -ceq (Sha (Join-Path $PSScriptRoot ('tests/'+[IO.Path]::GetFileName($path))))) 'Probe fixture differs'
        } else {
            Require ($path -in $requiredExtra -and $path.EndsWith('.uid')) 'Unexpected additional native source'
            $artifact=Join-Path $root ('generated/'+$(if ($probe) {'probe/'} else {'production/'})+$path)
            Require ((Sha $artifact) -ceq $parts[1] -and (Get-Content -LiteralPath $artifact -Raw) -match '^uid://[a-z0-9]+\s*$') 'Generated UID evidence differs'
        }
    }
    Require ($seen.Count -eq 640+$requiredExtra.Count -and -not @($expected.Keys|Where-Object {-not $seen.ContainsKey($_)}).Count -and -not @($requiredExtra|Where-Object {-not $seen.ContainsKey($_)}).Count) 'Product and generated source denominators'
    $ids=@($Receipt.steps|ForEach-Object id)
    $requiredSteps=if ($mode -eq 'build') {@('import','export')} else {@($mode)}
    Require (($ids -join '|') -ceq ($requiredSteps -join '|')) 'Exact required native steps'
    foreach ($step in $Receipt.steps) {
        Require ($step.completed -eq $true -and $step.exit_code -eq 0 -and $step.pid -gt 0) 'Native process did not complete successfully'
        foreach ($stream in @('out','err')) {
            $path=Join-Path $root ($Id+'__'+$step.id+'.'+$stream+'.log')
            $hash=if ($stream -eq 'out') {$step.stdout_sha256} else {$step.stderr_sha256}
            Require ((Sha $path) -ceq $hash) 'Raw native log hash'
            Require (-not (Select-String -LiteralPath $path -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' -Quiet)) 'Native script/engine error'
        }
        if ($step.id -eq 'export') {Require ('--export-release' -in $step.arguments -and '--export-debug' -notin $step.arguments) 'Actual export is not release'}
        if ($step.id -in @('startup','probe')) {
            Require ('--path' -notin $step.arguments -and '--main-pack' -notin $step.arguments -and '--ggb-dev-notebook-v2' -in $step.arguments -and '--foundation-smoke' -in $step.arguments -and '--dev-jump=CREDITS_REALITY' -in $step.arguments) 'Release invocation/developer gate conditions'
        }
    }
    Require ($Receipt.exe_sha256 -cmatch '^[a-f0-9]{64}$' -and $Receipt.pack_sha256 -cmatch '^[a-f0-9]{64}$' -and $Receipt.exe_bytes -gt 0 -and $Receipt.pack_bytes -gt 0) 'Release artifacts absent'
    if ($mode -eq 'startup') {
        $log=Get-Content -LiteralPath (Join-Path $root ($Id+'__startup.out.log')) -Raw
        Require ($log -match 'GGB title bootstrap initialized\.' -and $log -notmatch 'FOUNDATION_SMOKE: PASS') 'Production release did not retain normal entry'
        Require ((Get-Content (Join-Path $root ($Id+'__startup.err.log')) -Raw) -match 'Foundation smoke is unavailable in release builds\.') 'Release debug gate warning missing'
    }
    if ($mode -eq 'probe') {
        $locale=if ($Id -ceq 'probe_ko_verified') {'ko-KR'} else {'en-US'}
        Require ($Receipt.locale -ceq $locale -and $Receipt.probe_script_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/windows_release_probe.gd')) -and $Receipt.probe_scene_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'tests/windows_release_probe.tscn'))) 'Probe fixture/locale provenance'
        $raw=@(Get-Content (Join-Path $root ($Id+'__probe.out.log'))|Where-Object {$_.StartsWith('WINDOWS_RELEASE_PROBE: ')})
        Require ($raw.Count -eq 1) 'Exact release probe summary'
        $result=$raw[0].Substring('WINDOWS_RELEASE_PROBE: '.Length)|ConvertFrom-Json
        $saved=Get-Content (Join-Path $root ($Id+'.result.json')) -Raw|ConvertFrom-Json
        Require (($result|ConvertTo-Json -Depth 10 -Compress) -ceq ($saved|ConvertTo-Json -Depth 10 -Compress)) 'Raw/saved release result differs'
        Require ($result.ok -eq $true -and $result.debug_build -eq $false -and $result.locale -ceq $locale -and @($result.errors).Count -eq 0 -and $result.checks -eq 27) 'Release probe success/denominator'
        Require (($result.stages -join '|') -ceq 'title_and_developer_gate|ordinary_new_game_and_history|ordinary_history_read_only|v2_continue_and_original_retention|ordinary_history_read_only') 'Release compatibility stage omitted'
    }
}
foreach ($id in @('build_verified','startup_verified','compatibility_build','probe_ko_verified','probe_en_verified')) {
    $receipts[$id]=Get-Content (Join-Path $root ($id+'.run.json')) -Raw|ConvertFrom-Json
    Check-Receipt $receipts[$id] $id
}
Require ($receipts.build_verified.pack_sha256 -ceq $receipts.startup_verified.pack_sha256 -and $receipts.compatibility_build.pack_sha256 -ceq $receipts.probe_ko_verified.pack_sha256 -and $receipts.compatibility_build.pack_sha256 -ceq $receipts.probe_en_verified.pack_sha256 -and $receipts.build_verified.pack_sha256 -cne $receipts.compatibility_build.pack_sha256) 'Production/probe artifacts conflated'
$artifacts=@(Get-Content (Join-Path $root 'artifacts.json') -Raw|ConvertFrom-Json)
Require ($artifacts.Count -eq 4) 'Artifact denominator'
foreach ($kind in @('production','compatibility_test_only')) {
    $receipt=if ($kind -ceq 'production') {$receipts.build_verified} else {$receipts.compatibility_build}
    foreach ($file in @('GGB_release.exe','GGB_release.pck')) {
        $selected=@($artifacts|Where-Object {$_.kind -ceq $kind -and $_.file -ceq $file})
        Require ($selected.Count -eq 1) 'Unique retained artifact'
        $artifact=$selected[0]
        $path=if ($ArtifactRoot) {Join-Path $ArtifactRoot ($kind+'/'+$file)} else {$artifact.path}
        $hash=if ($file.EndsWith('.pck')) {$receipt.pack_sha256} else {$receipt.exe_sha256}
        Require ($artifact.sha256 -ceq $hash -and (Sha $path) -ceq $hash -and (Get-Item -LiteralPath $path).Length -eq $artifact.bytes) 'Retained EXE/PCK bytes differ'
    }
}
foreach ($id in @('policy7','policy5')) {
    $log=Get-Content (Join-Path $root ($id+'.out.log')) -Raw
    Require ($log -match '(?m)^GODOT_TEMPLATE_POLICY_CHECKS: 19\r?$' -and $log -match '(?m)^GODOT_TEMPLATE_POLICY: PASS\r?$') 'Template policy regression missing'
    $receipt=Get-Content (Join-Path $root ($id+'.run.json')) -Raw|ConvertFrom-Json
    Require ($receipt.exit_code -eq 0 -and $receipt.policy_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'godot_windows_template_policy.ps1')) -and $receipt.test_sha256 -ceq (Sha (Join-Path $PSScriptRoot 'test_godot_windows_template_policy.ps1')) -and $receipt.stdout_sha256 -ceq (Sha (Join-Path $root ($id+'.out.log')))) 'Policy native provenance'
    Require ($receipt.stderr_sha256 -ceq (Sha (Join-Path $root ($id+'.err.log'))) -and -not (Select-String -LiteralPath (Join-Path $root ($id+'.err.log')) -Pattern 'Error|Exception' -Quiet)) 'Policy native stderr'
}
$negative=@()
if ($SelfTest) {
    foreach ($kind in @('native_failure','debug_export','other_template','product_mutation','missing_stage','raw_hash')) {
        $copy=$receipts.build_verified|ConvertTo-Json -Depth 12|ConvertFrom-Json
        switch ($kind) {
            'native_failure' {$copy.steps[0].exit_code=1}
            'debug_export' {$copy.steps[1].arguments=@('--headless','--export-debug')}
            'other_template' {$copy.template_version='4.7.2.stable'}
            'product_mutation' {$copy.source_rows[0]=$copy.source_rows[0].Split("`t")[0]+"`t"+('0'*64)}
            'missing_stage' {$copy.steps=@($copy.steps|Select-Object -Skip 1)}
            'raw_hash' {$copy.steps[0].stdout_sha256='0'*64}
        }
        try {Check-Receipt $copy 'build_verified';throw ('Accepted malformed evidence: '+$kind)}
        catch {if ($_.Exception.Message.StartsWith('Accepted malformed evidence:')) {throw};$negative+=@{id=$kind;rejected=$true;reason=$_.Exception.Message}}
    }
}
[ordered]@{ok=$true;checks=$checks;receipts=5;native_steps=7;policy_cases_per_shell=19;probe_checks_per_locale=27;product_files=640;negative=$negative;production_pack_sha256=$receipts.build_verified.pack_sha256;probe_pack_sha256=$receipts.compatibility_build.pack_sha256}|ConvertTo-Json -Depth 6
