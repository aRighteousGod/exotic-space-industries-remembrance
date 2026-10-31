# Engine staging is narrower than source discovery: manifests, static audits and
# packaging must still see every pack in this mixed 2.0/2.1 repository.
if (-not (Get-Variable EsirOriginalSyncRunMods -Scope Script -ErrorAction SilentlyContinue)) {
    $script:EsirOriginalSyncRunMods = (Get-Command Sync-FactorioRunMods).ScriptBlock
}

# Exclude generated trees before recursion. The installed harness filters after
# walking them, which can fail on unrelated long pycache paths and junctions.
function Get-RepoFilesByExtension {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$Filter)
    return @(Get-EsirTextFileTargets -Paths ([pscustomobject]@{repo_root=$RepoRoot}) | Where-Object Name -Like $Filter)
}

function Test-PythonFiles {
    param([Parameter(Mandatory)]$Context)
    $failures = @()
    if (-not $Context.python_exe) { return [pscustomobject]@{tool_path=$null; failures=$failures; skipped=$true} }
    foreach ($file in Get-RepoFilesByExtension -RepoRoot $Context.repo_root -Filter '*.py') {
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            # Compile bytes in memory: syntax checks never write into source trees.
            $output = & $Context.python_exe -X utf8 -B -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); compile(p.read_bytes(),str(p),sys.argv[2])' $file.FullName 'exec' 2>&1 | ForEach-Object { "$_" }
        } finally { $ErrorActionPreference = $previousPreference }
        if ($LASTEXITCODE -ne 0) { $failures += [pscustomobject]@{file=$file.FullName; error=($output -join ' ')} }
    }
    return [pscustomobject]@{tool_path=$Context.python_exe; failures=$failures; skipped=$false}
}

function Select-EsirEngineSourceMods {
    param([Parameter(Mandatory)]$Context)
    $engineRoot = Split-Path (Split-Path (Split-Path $Context.factorio_exe))
    $base = Get-Content -LiteralPath (Join-Path $engineRoot 'data/base/info.json') -Raw | ConvertFrom-Json
    $target = ([string]$base.version -split '\.')[0..1] -join '.'
    $included = @(); $excluded = @()
    foreach ($mod in $Context.source_mods) {
        $info = Get-Content -LiteralPath $mod.info_path -Raw | ConvertFrom-Json
        if ($info.factorio_version -eq $target) { $included += $mod }
        else {
            if ($mod.name -eq 'exotic-space-industries-remembrance') {
                throw "ESIR targets Factorio $($info.factorio_version); use a separate compatible staging root for $target tests."
            }
            $excluded += [ordered]@{ name = $mod.name; factorio_version = $info.factorio_version; engine_target = $target }
        }
    }
    return [pscustomobject]@{ included = $included; excluded = $excluded; engine_target = $target }
}

function Sync-FactorioRunMods {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Result)
    if ($Context.PSObject.Properties.Name -notcontains 'qc_run_id' -or
        $Context.PSObject.Properties.Name -notcontains 'source_mode') {
        throw 'QC staging requires managed ownership and an explicit read-only/private-mutable source mode. Initialize the managed QC context first.'
    }
    $selection = Select-EsirEngineSourceMods -Context $Context
    $profile = if ($Context.PSObject.Properties.Name -contains 'esir_development_profile') { $Context.esir_development_profile } else { $null }
    $packages = @(); $sources = @(); $modList = $null; $settings = $null
    if ($profile) {
        $version = & $Context.factorio_exe --version
        if ($LASTEXITCODE -ne 0 -or $version -notmatch ('Version: ' + [regex]::Escape($profile.engine_version) + ' ')) {
            throw 'Configured executable and exact development profile disagree.'
        }
        $seed = $Context.cache_seed_directories[0]
        $lockPath = Join-Path $seed 'dependency-lock-2.1.json'
        if (-not (Test-Path -LiteralPath $lockPath) -or
            (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash -ne $profile.dependency_lock_sha256) {
            throw 'Missing or changed 2.1 dependency lock; prepare the explicit development seed before QC.'
        }
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        # Legacy ZIP leaves can be imported once, without deleting or adopting
        # the seed. New seed preparation writes only selection/lock metadata.
        $expected = @($lock.file) + @('dependency-lock-2.1.json', 'mod-list.json', 'mod-settings.dat', 'store-manifest.json')
        foreach ($entry in Get-ChildItem -LiteralPath $seed -Force) {
            if ($entry.PSIsContainer -or $entry.Name -notin $expected) { throw "Unexpected dependency seed content: $($entry.Name)" }
        }
        foreach ($dependency in $lock) {
            $zip = Join-Path $seed $dependency.file
            if ($dependency.info.factorio_version -ne '2.1') {
                throw "Unverified or incompatible dependency seed: $($dependency.name)"
            }
            $artifact = @{sha256=$dependency.sha256; name=$dependency.name; version=$dependency.info.version; factorio_version='2.1'}
            if (Test-Path -LiteralPath $zip) { $artifact.path = $zip }
            $packages += $artifact
        }
        if (-not (Test-Path -LiteralPath (Join-Path $seed 'mod-list.json'))) { throw 'The core seed requires an explicit mod list.' }
        $modList = Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
        if (Test-Path -LiteralPath (Join-Path $seed 'mod-settings.dat')) { $settings = Join-Path $seed 'mod-settings.dat' }
        [void](Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action profile -Data @{name='development'; packages=$packages})
    } elseif ($Context.PSObject.Properties.Name -contains 'dependency_packages' -and $Context.PSObject.Properties.Name -contains 'qc_mod_list') {
        $packages = @($Context.dependency_packages); $modList = $Context.qc_mod_list
    } elseif (-not $Context.is_esir) {
        # Tiny repository-owned tooling fixtures need only base and their live
        # sources. Third-party packages still require an explicit selection.
        $modList = @{mods=@(@{name='base';enabled=$true}) + @($selection.included | ForEach-Object { @{name=$_.name;enabled=$true} })}
    } else {
        throw 'Non-profile QC needs an explicit dependency_packages selection and qc_mod_list; cached run directories are not automatic seeds.'
    }
    foreach ($mod in $selection.excluded) {
        Add-FactorioQCNote -Result $Result -Message "Not staged: $($mod.name) targets $($mod.factorio_version), engine is $($mod.engine_target). Compatible legacy dependency seeds remain available."
    }
    $mutableNames = if ($Context.PSObject.Properties.Name -contains 'mutable_source_names') { @($Context.mutable_source_names) } else { @('exotic-space-industries-remembrance') }
    foreach ($mod in $selection.included) {
        $mode = if ($Context.source_mode -eq 'private-mutable' -and ('*' -in $mutableNames -or $mod.name -in $mutableNames)) { 'private-mutable' } else { 'read-only' }
        $sources += @{path=$mod.directory; name=$mod.name; mode=$mode}
    }
    if ($profile) {
        $source = [IO.Path]::GetFullPath((Join-Path $Context.repo_root $profile.nsbc_source))
        $info = Get-Content -LiteralPath (Join-Path $source 'info.json') -Raw | ConvertFrom-Json
        if ($info.name -ne 'zzz-nonstandard-beacons-continued' -or $info.factorio_version -ne '2.1' -or $info.version -ne '1.0.0') {
            throw 'NSBC live source identity/version does not match the accepted continuation candidate.'
        }
        $mode = if ($Context.source_mode -eq 'private-mutable' -and ('*' -in $mutableNames -or $info.name -in $mutableNames)) { 'private-mutable' } else { 'read-only' }
        $sources += @{path=$source; name=$info.name; mode=$mode}
        Add-FactorioQCNote -Result $Result -Message 'Staged the accepted NSBC source through the shared source-view contract.'
    }
    if ($Context.PSObject.Properties.Name -contains 'extra_dependency_packages') {
        foreach ($extra in $Context.extra_dependency_packages) {
            $artifact = Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action import -Data @{path=$extra.path;run_id=$Context.qc_run_id}
            if ($artifact.factorio_version -ne $selection.engine_target) { throw "Incompatible fixture dependency: $($artifact.name)" }
            $packages = @($packages | Where-Object { $_.name -ne $artifact.name }) + @{sha256=$artifact.sha256;name=$artifact.name}
        }
    }
    $request = @{run_id=$Context.qc_run_id; packages=$packages; sources=$sources; mod_list=$modList}
    if ($settings) { $request.settings_path = $settings }
    $storage = Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action stage -Data $request
    foreach ($property in @('store_root', 'mod_view_root', 'scratch_root', 'evidence_root')) {
        $Context | Add-Member -NotePropertyName $property -NotePropertyValue $storage.$property -Force
    }
    $Context.run_mod_directory = $storage.mod_view_root
    Add-FactorioQCNote -Result $Result -Message 'Managed mod view uses canonical ZIP hardlinks and declared source mutability.'
    return $storage.mod_view_root
}

function New-FactorioWriteDataConfig {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Label)
    if ($Context.PSObject.Properties.Name -notcontains 'qc_run_id') { throw 'Engine output requires a managed QC context.' }
    if ($Label -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid QC output label.' }
    $storage = Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action inspect -Data @{run_id=$Context.qc_run_id}
    $timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
    $writeData = Join-Path $storage.scratch_root "$Label-$timestamp"
    [void][IO.Directory]::CreateDirectory($writeData)
    $config = Join-Path $writeData 'config.ini'
    Write-FactorioQCTextFile -Path $config -Value "[path]`nwrite-data=$writeData`n[other]`ncheck-updates=false`n[graphics]`ncache-sprite-atlas=false`n" -NoNewline
    return [pscustomobject]@{write_data_dir=$writeData; config_path=$config; timestamp=$timestamp}
}
