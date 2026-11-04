# Repository-owned final-data and Gaia acceptance. The generic QC result shape is retained.
function Invoke-EsirOwnedProcess {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$OutputPath,
        [int]$TimeoutSeconds = 600)
    $requestPath = $OutputPath + '.request.json'
    $reportPath = $OutputPath + '.process.json'
    if ((Test-Path -LiteralPath $requestPath) -or (Test-Path -LiteralPath $reportPath) -or (Test-Path -LiteralPath $OutputPath)) {
        throw 'Owned process output must be fresh.'
    }
    Write-EsirJson -Path $requestPath -Data @{
        run_id=$Context.qc_run_id;command=@($FilePath)+$Arguments;output=$OutputPath
        report=$reportPath;timeout_seconds=$TimeoutSeconds
    }
    $requestHash = (Get-FileHash -LiteralPath $requestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $started = [DateTime]::UtcNow
    $bridge = Invoke-NativeProcess -FilePath $Context.python_exe -Arguments @('-B',
        (Join-Path $PSScriptRoot 'qc/native-tests/process.py'), $requestPath)
    if ($bridge.exit_code -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) {
        throw ('Owned process supervisor failed: ' + ($bridge.output -join "`n"))
    }
    $process = Read-EsirJson -Path $reportPath
    if ($process.run_id -ne $Context.qc_run_id -or $process.request_sha256 -ne $requestHash -or
        (Get-FileHash -LiteralPath $requestPath).Hash.ToLowerInvariant() -ne $requestHash -or
        (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $started) {
        throw 'Owned process returned stale or mismatched evidence.'
    }
    $process | Add-Member -NotePropertyName output -NotePropertyValue @(Get-Content -LiteralPath $OutputPath -Encoding UTF8)
    return $process
}

function Invoke-EsirFinalDataContracts {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Result)
    $reportPath = Join-Path $Context.evidence_root 'data-contracts.json'
    $outputPath = Join-Path $Context.evidence_root 'data-contracts-host.log'
    try {
        $process = Invoke-EsirOwnedProcess -Context $Context -FilePath $Context.python_exe -OutputPath $outputPath -Arguments @(
            '-B', (Join-Path $PSScriptRoot 'qc/native-tests/data_contracts.py'),
            '--dump', $Result.artifacts.data_raw_dump, '--report', $reportPath, '--run-id', $Context.qc_run_id)
        $report = Read-EsirJson -Path $reportPath
        if ($process.exit_code -ne 0 -or $process.timed_out -or $process.fatal -or
            $report.run_id -ne $Context.qc_run_id -or $report.complete -ne $true -or $report.passed -ne $true -or
            @($report.checks).Count -eq 0 -or @($report.checks | Where-Object passed -ne $true).Count) {
            throw ('Required final-data contracts failed: ' + $reportPath)
        }
        Add-FactorioQCArtifact -Result $Result -Name 'data_contracts' -Value $report
    } catch { Add-FactorioQCError -Result $Result -Message $_.Exception.Message }
    Add-FactorioQCArtifact -Result $Result -Name 'data_contracts_report' -Value $reportPath
}

function Get-EsirGaiaResourcePolicy {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $policy = Read-EsirJson (Join-Path $RepoRoot '.codex/skills/esir-dev/assets/gaia-resource-qc.json')
    if ($policy.format_version -ne 1 -or $policy.planet -ne 'gaia' -or $policy.preview_size -ne 4096 -or
        $policy.minimum_entity_count -ne 1 -or @($policy.resources).Count -ne 6 -or
        @($policy.resources | Select-Object -Unique).Count -ne 6 -or
        $policy.control_probe.seed -ne 1000 -or $policy.control_probe.preview_size -ne 2048 -or
        @($policy.control_probe.disabled_resources).Count -ne 6 -or
        (Compare-Object @($policy.resources) @($policy.control_probe.disabled_resources))) {
        throw 'Gaia resource policy has an incomplete or unsupported required matrix.'
    }
    return $policy
}

function Read-EsirResourceQuantities {
    param([Parameter(Mandatory)][string[]]$Lines, [Parameter(Mandatory)][string[]]$Targets)
    $alternation = @($Targets | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $measurements = @{}
    foreach ($line in $Lines) {
        if ($line -match "(?<name>$alternation): totalEntityCount=(?<count>\d+), totalRichness=(?<richness>\d+)") {
            $name = $Matches.name
            $measurement = [ordered]@{entity_count=[uint64]$Matches.count;richness=[uint64]$Matches.richness}
            if ($measurements.ContainsKey($name) -and
                ($measurements[$name].entity_count -ne $measurement.entity_count -or $measurements[$name].richness -ne $measurement.richness)) {
                throw "Conflicting native quantity reports for $name"
            }
            $measurements[$name] = $measurement
        }
    }
    return $measurements
}

function Invoke-EsirResourcePreviewRow {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Planet, [Parameter(Mandatory)][uint32]$Seed,
        [Parameter(Mandatory)][int]$Size, [Parameter(Mandatory)][string[]]$Targets,
        [string]$DisabledResource, [switch]$RequirePresence)
    $errors = [Collections.Generic.List[string]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $config = New-FactorioWriteDataConfig -Context $Context -Label $Id
    $dataPath = Join-Path (Split-Path (Split-Path (Split-Path $Context.factorio_exe))) 'data'
    Write-FactorioQCTextFile -Path $config.config_path -Value ("[path]`nread-data=" + $dataPath.Replace('\','/') +
        "`nwrite-data=" + $config.write_data_dir.Replace('\','/') + "`n[other]`ncheck-updates=false`n")
    $preview = Join-Path $Context.evidence_root ($Id + '.png')
    $output = Join-Path $Context.evidence_root ($Id + '.log')
    $arguments = @('--config', $config.config_path, '--mod-directory', $Context.run_mod_directory,
        '--disable-audio', '--generate-map-preview', $preview, '--map-preview-size', [string]$Size,
        '--map-preview-planet', $Planet, '--map-gen-seed', [string]$Seed, '--report-quantities', ($Targets -join ','))
    if ($DisabledResource) {
        if ($DisabledResource -notin $Targets) { throw 'Unknown disabled resource.' }
        $controls = @{}; $controls[$DisabledResource] = @{frequency=0;size=0;richness=0}
        $settingsPath = Join-Path $Context.evidence_root ($Id + '-settings.json')
        Write-EsirJson -Path $settingsPath -Data @{autoplace_controls=$controls}
        $arguments += @('--map-gen-settings', $settingsPath)
    }
    [void](Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action validate -Data @{run_id=$Context.qc_run_id})
    $started = [DateTime]::UtcNow
    $process = Invoke-EsirOwnedProcess -Context $Context -FilePath $Context.factorio_exe -Arguments $arguments -OutputPath $output
    [void](Invoke-EsirQcStorage -RepoRoot $Context.repo_root -Action validate -Data @{run_id=$Context.qc_run_id})
    $classification = Get-ClassifiedFactorioLog -LogPath (Join-Path $config.write_data_dir 'factorio-current.log') -OutputLines $process.output
    if ($process.exit_code -ne 0 -or $process.timed_out -or $process.fatal) { $errors.Add("Native preview process failed for $Id") }
    foreach ($line in $classification.fatal) { $errors.Add($line) }
    foreach ($line in $classification.needs_review) { $warnings.Add($line) }
    $fresh = (Test-Path -LiteralPath $preview) -and (Get-Item -LiteralPath $preview).Length -gt 0 -and
        (Get-Item -LiteralPath $preview).LastWriteTimeUtc -ge $started
    if (-not $fresh) { $errors.Add("Missing or stale preview for $Id") }
    $measurements = Read-EsirResourceQuantities -Lines $process.output -Targets $Targets
    $resources = @()
    foreach ($name in $Targets) {
        $measurement = $measurements[$name]
        $passed = $null -ne $measurement
        if ($passed -and $RequirePresence) {
            $passed = if ($name -eq $DisabledResource) { $measurement.entity_count -eq 0 } else { $measurement.entity_count -ge 1 }
        }
        if (-not $passed) { $errors.Add("Missing or invalid required quantity for $name in $Id") }
        $resources += [ordered]@{name=$name;measurement=$measurement;passed=[bool]$passed;expected=if ($name -eq $DisabledResource) {'disabled'} elseif ($RequirePresence) {'present'} else {'reported'}}
    }
    $row = [ordered]@{id=$Id;run_id=$Context.qc_run_id;engine_version='2.1.24';planet=$Planet;seed=$Seed;preview_size=$Size;
        disabled_resource=$DisabledResource;resources=$resources;process=$process;errors=@($errors);warnings=@($warnings);
        preview=$preview;preview_sha256=if ($fresh) {(Get-FileHash -LiteralPath $preview).Hash.ToLowerInvariant()} else {$null};
        status=if ($errors.Count) {'failed'} elseif ($warnings.Count) {'warning'} else {'ok'}}
    # Console content is retained once in the owned log, with the parsed measurements here.
    $row.process.PSObject.Properties.Remove('output')
    Write-EsirJson -Path (Join-Path $Context.evidence_root ($Id + '.json')) -Data $row
    return $row
}

function Assert-EsirGaiaAggregate {
    param([Parameter(Mandatory)]$Aggregate, [Parameter(Mandatory)][string]$SourceHash)
    if ($Aggregate.task -ne 'qc-test' -or $Aggregate.overall_status -ne 'ok' -or
        $Aggregate.source_fingerprint.sha256 -ne $SourceHash -or @($Aggregate.source_errors).Count -ne 0 -or
        @($Aggregate.results).Count -ne 1) { throw 'Missing or failed required Gaia aggregate.' }
    $row = $Aggregate.results[0]
    if ($row.suite -ne 'gaia-resources' -or $row.profile -ne 'default' -or $row.overall_status -ne 'ok' -or
        @($row.phases).Count -ne 1 -or $row.phases[0].phase -ne 'candidate' -or
        $row.phases[0].passed -ne $true -or $row.phases[0].assertions -lt 1) {
        throw 'Missing or incomplete Gaia candidate phase.'
    }
}

function Resolve-EsirPreviewScope {
    param([string]$Mode, [string]$PreviewScope, [string]$Planet, [Nullable[int]]$Seed)
    if ($Mode -eq 'full') { return 'gaia-acceptance' }
    if ($PreviewScope) {
        if ($PreviewScope -notin @('requested','gaia-acceptance')) { throw 'Unknown preview scope.' }
        return $PreviewScope
    }
    if ($Planet -or $null -ne $Seed) { return 'requested' }
    return 'gaia-acceptance'
}

function Invoke-EsirGaiaPreviewCompanion {
    param([Parameter(Mandatory)]$Context, [Nullable[int]]$Seed, [string]$Planet, [string]$Save, [switch]$Strict)
    $result = New-FactorioQCResult -Name 'preview'
    $paths = Get-EsirPaths $Context.repo_root
    try {
        if ($null -ne $Seed -and $Seed -lt 0) { throw 'Preview seed must be nonnegative.' }
        $policy = Get-EsirGaiaResourcePolicy $Context.repo_root
        $common = Get-EsirCommonTestInputs -Paths $paths
        $null = Sync-FactorioRunMods -Context $Context -Result $result
        $explicitScope = if ($Context.PSObject.Properties.Name -contains 'preview_scope') { $Context.preview_scope } else { $null }
        $scope = Resolve-EsirPreviewScope -Mode preview -PreviewScope $explicitScope -Planet $Planet -Seed $Seed
        Add-FactorioQCArtifact -Result $result -Name 'preview_scope' -Value $scope
        if ($scope -eq 'requested') {
            $requestedPlanet = if ($Planet) { $Planet } else { 'gaia' }
            $requestedSeed = if ($null -ne $Seed) { [uint32]$Seed } else { [uint32]1000 }
            $targets = if ($requestedPlanet -eq 'gaia') { $policy.resources } else { Get-PreviewTargets -Context $Context -Planet $requestedPlanet }
            $requested = Invoke-EsirResourcePreviewRow -Context $Context -Id 'requested-preview' -Planet $requestedPlanet `
                -Seed $requestedSeed -Size 1024 -Targets $targets
            Add-FactorioQCArtifact -Result $result -Name 'requested_preview' -Value $requested
            Add-FactorioQCArtifact -Result $result -Name 'preview' -Value $requested.preview
            Add-FactorioQCArtifact -Result $result -Name 'evidence_boundary' -Value 'Requested preview only; Gaia acceptance and native resource coverage were not selected.'
            foreach ($message in $requested.errors) { Add-FactorioQCError -Result $result -Message $message }
            foreach ($message in $requested.warnings) { Add-FactorioQCWarning -Result $result -Message $message }
            if ((Get-EsirCommonTestInputs -Paths $paths).sha256 -ne $common.sha256) { throw 'Source inputs changed during requested preview.' }
            Add-FactorioQCArtifact -Result $result -Name 'source_fingerprint' -Value $common
            return (Finalize-FactorioQCResult -Result $result -Strict:$Strict)
        }
        $required = Invoke-EsirResourcePreviewRow -Context $Context -Id 'gaia-required-seed-1000' -Planet gaia -Seed 1000 `
            -Size $policy.preview_size -Targets $policy.resources -RequirePresence
        Add-FactorioQCArtifact -Result $result -Name 'gaia_required_preview' -Value $required
        foreach ($message in $required.errors) { Add-FactorioQCError -Result $result -Message $message }
        foreach ($message in $required.warnings) { Add-FactorioQCWarning -Result $result -Message $message }
        if ($required.status -eq 'failed') { throw 'Required Gaia preview failed before native acceptance.' }

        $requestedPlanet = if ($Planet) { $Planet } else { 'gaia' }
        $requestedSeed = if ($null -ne $Seed) { [uint32]$Seed } else { [uint32]1000 }
        if ($requestedPlanet -ne 'gaia' -or $requestedSeed -ne 1000) {
            $targets = if ($requestedPlanet -eq 'gaia') { $policy.resources } else { Get-PreviewTargets -Context $Context -Planet $requestedPlanet }
            $requested = Invoke-EsirResourcePreviewRow -Context $Context -Id 'requested-preview' -Planet $requestedPlanet `
                -Seed $requestedSeed -Size 1024 -Targets $targets
            Add-FactorioQCArtifact -Result $result -Name 'requested_preview' -Value $requested
            foreach ($message in $requested.errors) { Add-FactorioQCError -Result $result -Message $message }
            foreach ($message in $requested.warnings) { Add-FactorioQCWarning -Result $result -Message $message }
            Add-FactorioQCArtifact -Result $result -Name 'preview' -Value $requested.preview
        } else { Add-FactorioQCArtifact -Result $result -Name 'preview' -Value $required.preview }

        $child = Invoke-NativeProcess -FilePath $Context.python_exe -Arguments @('-B',
            (Join-Path $PSScriptRoot 'qc/native-tests/runner.py'), 'qc-test', '--repo', $Context.repo_root,
            '--suite', 'gaia-resources', '--case', 'candidate', '--profile', 'default',
            '--engine', $Context.factorio_exe, '--expected-source-sha256', $common.sha256)
        $jsonLine = @($child.output | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)
        if ($jsonLine.Count -ne 1) { throw 'Required Gaia child returned no aggregate.' }
        $aggregate = $jsonLine[0] | ConvertFrom-Json
        Add-FactorioQCArtifact -Result $result -Name 'gaia_native' -Value $aggregate
        if ($child.exit_code -ne 0) { throw 'Required Gaia native child failed.' }
        Assert-EsirGaiaAggregate -Aggregate $aggregate -SourceHash $common.sha256
        if ((Get-EsirCommonTestInputs -Paths $paths).sha256 -ne $common.sha256) { throw 'Source inputs changed during Gaia acceptance.' }
        Add-FactorioQCArtifact -Result $result -Name 'source_fingerprint' -Value $common
    } catch { Add-FactorioQCError -Result $result -Message $_.Exception.Message }
    return (Finalize-FactorioQCResult -Result $result -Strict:$Strict)
}

function Invoke-EsirGaiaResourceMatrix {
    param([Parameter(Mandatory)]$Paths, [uint32[]]$Seeds, [Nullable[int]]$PreviewSize, [string]$FactorioPath, [switch]$Strict)
    $policy = Get-EsirGaiaResourcePolicy $Paths.repo_root
    $effectiveSeeds = @(if ($Seeds -and $Seeds.Count) { $Seeds } else { $policy.seeds })
    $size = if ($null -ne $PreviewSize) { [int]$PreviewSize } else { [int]$policy.preview_size }
    if ($size -lt 256 -or $size -gt 8192 -or $effectiveSeeds.Count -eq 0 -or
        @($effectiveSeeds | Select-Object -Unique).Count -ne $effectiveSeeds.Count) { throw 'Invalid Gaia preview size or seed selection.' }
    $common = Get-EsirCommonTestInputs -Paths $Paths
    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath -EnsureArtifactRoot
    $managed = Start-EsirManagedQc -RepoRoot $Paths.repo_root -Context $context -Workflow 'qc-gaia-resources' `
        -Scenario ('gaia|' + $size + '|' + ($effectiveSeeds -join ',')) `
        -Reproduction ('invoke-esir-dev -Task qc-gaia-resources -Seeds ' + ($effectiveSeeds -join ',') + ' -PreviewSize ' + $size)
    if (-not $managed.run) { throw $managed.error }
    $result = [ordered]@{task='qc-gaia-resources';overall_status='failed';run_id=$managed.run.id;
        engine_version='2.1.24';source_fingerprint=$common;planet='gaia';preview_size=$size;minimum_entity_count=1;
        seeds=$effectiveSeeds;resources=$policy.resources;runs=@();control_probes=@();failures=@();warnings=@()}
    try {
        $sync = New-FactorioQCResult -Name gaia-resources
        $null = Sync-FactorioRunMods -Context $context -Result $sync
        foreach ($seedValue in $effectiveSeeds) {
            $result.runs += Invoke-EsirResourcePreviewRow -Context $context -Id ('gaia-seed-' + $seedValue) `
                -Planet gaia -Seed $seedValue -Size $size -Targets $policy.resources -RequirePresence
        }
        foreach ($disabled in $policy.control_probe.disabled_resources) {
            $result.control_probes += Invoke-EsirResourcePreviewRow -Context $context -Id ('gaia-control-' + $disabled) `
                -Planet gaia -Seed $policy.control_probe.seed -Size $policy.control_probe.preview_size `
                -Targets $policy.resources -DisabledResource $disabled -RequirePresence
        }
        $rows = @($result.runs) + @($result.control_probes)
        $result.failures = @($rows | ForEach-Object { $_.errors })
        $result.warnings = @($rows | ForEach-Object { $_.warnings })
        Assert-EsirGaiaPreviewMatrix -Runs $result.runs -ControlProbes $result.control_probes -Seeds $effectiveSeeds -Targets $policy.resources -Size $size
        if ((Get-EsirCommonTestInputs -Paths $Paths).sha256 -ne $common.sha256) { throw 'Source inputs changed during Gaia matrix.' }
        $result.overall_status = if ($result.failures.Count -or @($rows | Where-Object status -eq 'failed').Count -or ($Strict -and $result.warnings.Count)) { 'failed' }
            elseif ($result.warnings.Count) { 'warning' } else { 'ok' }
    } catch { $result.overall_status='failed'; $result.failures += $_.Exception.Message }
    $exitCode = if ($result.overall_status -eq 'failed') { 1 } else { 0 }
    Write-EsirJson -Path (Join-Path $context.evidence_root 'gaia-resource-matrix.json') -Data $result
    $result.housekeeping = Finish-EsirManagedQc -RepoRoot $Paths.repo_root -State $managed -ExitCode $exitCode -Result $result
    try {
        $closed = Set-EsirArtifactRunState -RepoRoot $Paths.repo_root -RunId $managed.run.id -Action close
        if ($closed.cleanup_status -eq 'protected-error' -or $result.housekeeping.status -ne 'success') {
            $result.overall_status='failed'
        }
        $result.housekeeping.task_open = $closed.task_open
        $result.housekeeping.cleanup_status = $closed.cleanup_status
    } catch { $result.overall_status='failed';$result.failures += $_.Exception.Message }
    Write-EsirJson -Path (Join-Path $context.evidence_root 'final-result.json') -Data $result
    return $result
}

function Assert-EsirGaiaPreviewMatrix {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Runs,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ControlProbes,
        [Parameter(Mandatory)][uint32[]]$Seeds, [Parameter(Mandatory)][string[]]$Targets,
        [Parameter(Mandatory)][int]$Size)
    if ($Runs.Count -ne $Seeds.Count -or $ControlProbes.Count -ne 6 -or
        @($Runs.id | Select-Object -Unique).Count -ne $Seeds.Count -or
        @($ControlProbes.disabled_resource | Select-Object -Unique).Count -ne 6) { throw 'Incomplete Gaia resource matrix.' }
    foreach ($seed in $Seeds) {
        $matching = @($Runs | Where-Object { $_.id -eq ('gaia-seed-' + $seed) -and $_.seed -eq $seed -and $_.preview_size -eq $Size })
        if ($matching.Count -ne 1) { throw "Missing Gaia seed row $seed" }
    }
    foreach ($name in $Targets) {
        $matching = @($ControlProbes | Where-Object { $_.id -eq ('gaia-control-' + $name) -and $_.disabled_resource -eq $name -and $_.seed -eq 1000 -and $_.preview_size -eq 2048 })
        if ($matching.Count -ne 1) { throw "Missing Gaia control row $name" }
    }
    foreach ($row in (@($Runs) + @($ControlProbes))) {
        if ($row.status -notin @('ok','warning','failed') -or @($row.resources).Count -ne 6 -or
            @($row.resources.name | Select-Object -Unique).Count -ne 6 -or
            (Compare-Object @($row.resources.name) $Targets)) { throw "Incomplete resource inventory in $($row.id)" }
    }
}
