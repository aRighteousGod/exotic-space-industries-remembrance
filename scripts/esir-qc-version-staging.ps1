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
    $selection = Select-EsirEngineSourceMods -Context $Context
    $profile = if ($Context.PSObject.Properties.Name -contains 'esir_development_profile') { $Context.esir_development_profile } else { $null }
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
        $expected = @($lock.file) + @('dependency-lock-2.1.json', 'mod-list.json', 'mod-settings.dat')
        foreach ($entry in Get-ChildItem -LiteralPath $seed -Force) {
            if ($entry.PSIsContainer -or $entry.Name -notin $expected) { throw "Unexpected dependency seed content: $($entry.Name)" }
        }
        foreach ($dependency in $lock) {
            $zip = Join-Path $seed $dependency.file
            if ($dependency.info.factorio_version -ne '2.1' -or -not (Test-Path -LiteralPath $zip) -or
                (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $dependency.sha256) {
                throw "Unverified or incompatible dependency seed: $($dependency.name)"
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $seed 'mod-list.json'))) { throw 'The core seed requires an explicit mod list.' }
    }
    $stagingContext = $Context.PSObject.Copy()
    $stagingContext.source_mods = @($selection.included)
    foreach ($mod in $selection.excluded) {
        Add-FactorioQCNote -Result $Result -Message "Not staged: $($mod.name) targets $($mod.factorio_version), engine is $($mod.engine_target). Compatible legacy dependency seeds remain available."
    }
    $target = & $script:EsirOriginalSyncRunMods -Context $stagingContext -Result $Result
    if ($profile) {
        $source = [IO.Path]::GetFullPath((Join-Path $Context.repo_root $profile.nsbc_source))
        $info = Get-Content -LiteralPath (Join-Path $source 'info.json') -Raw | ConvertFrom-Json
        if ($info.name -ne 'zzz-nonstandard-beacons-continued' -or $info.factorio_version -ne '2.1' -or $info.version -ne '1.0.0') {
            throw 'NSBC live source identity/version does not match the accepted continuation candidate.'
        }
        $destination = Join-Path $target $info.name
        & robocopy $source $destination /E /XD .git .qc dist tests __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw 'Clean NSBC dependency staging failed.' }
        Add-FactorioQCNote -Result $Result -Message 'Staged live NSBC dependency with development-output exclusions; it is not part of repo package discovery.'
    }
    return $target
}
