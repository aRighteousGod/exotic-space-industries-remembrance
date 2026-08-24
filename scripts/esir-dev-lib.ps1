Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EsirCodexHome {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return $env:CODEX_HOME
    }

    return (Join-Path $HOME '.codex')
}

$script:EsirRuntimeOverrideMap = $null
$script:EsirFactorioQcLoaded = $false
$script:EsirGlobalSkillRoot = Join-Path (Get-EsirCodexHome) 'skills'
$script:EsirFactorioLibDefault = Join-Path $script:EsirGlobalSkillRoot 'factorio-mod-qc\scripts\factorio-qc-lib.ps1'
$script:EsirReachableLuaCache = @{}
$script:EsirAssignedRequireCache = @{}
$script:EsirBareRequireCache = @{}
$script:EsirLuaStaticReachableContentCache = @{}
$script:EsirResolvedRequireCache = @{}
$script:EsirEnabledLocalMods = $null

if (Test-Path -LiteralPath $script:EsirFactorioLibDefault) {
    . $script:EsirFactorioLibDefault
    $script:EsirFactorioQcLoaded = $true
}

$dependencyLibPath = Join-Path $PSScriptRoot 'esir-dependency-lib.ps1'
if (Test-Path -LiteralPath $dependencyLibPath) {
    . $dependencyLibPath
}

function ConvertTo-EsirArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value)
    }

    return @($Value)
}

function Get-EsirEnabledLocalMods {
    if ($null -ne $script:EsirEnabledLocalMods) {
        return $script:EsirEnabledLocalMods
    }

    $enabledMods = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $modListPath = Join-Path $env:APPDATA 'Factorio\mods\mod-list.json'
    if (Test-Path -LiteralPath $modListPath) {
        try {
            $modList = Get-Content -LiteralPath $modListPath -Raw | ConvertFrom-Json
            foreach ($mod in (ConvertTo-EsirArray $modList.mods)) {
                if ($mod.enabled) {
                    [void]$enabledMods.Add([string]$mod.name)
                }
            }
        } catch {
        }
    }

    $script:EsirEnabledLocalMods = $enabledMods
    return $enabledMods
}

function Get-EsirPaths {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [switch]$EnsureWritableDirs
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $manifestRoot = Join-Path $resolvedRepoRoot '.codex\esir'
    $repoSkillRoot = Join-Path $resolvedRepoRoot '.codex\skills\esir-dev'
    $artifactRoot = Join-Path $resolvedRepoRoot '.factorio-qc'
    $globalSkillRoot = Join-Path (Get-EsirCodexHome) 'skills'

    if ($EnsureWritableDirs) {
        New-Item -ItemType Directory -Force -Path $manifestRoot | Out-Null
        New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    }

    return [pscustomobject]@{
        repo_root              = $resolvedRepoRoot
        manifest_root          = $manifestRoot
        artifact_root          = $artifactRoot
        repo_skill_root        = $repoSkillRoot
        dependency_skill_root  = Join-Path $resolvedRepoRoot '.codex\skills\esir-dependency-intel'
        factorio_skill_root    = Join-Path $globalSkillRoot 'factorio-mod-qc'
        factorio_invoke_script = Join-Path $globalSkillRoot 'factorio-mod-qc\scripts\invoke-factorio-qc.ps1'
        factorio_lib_script    = Join-Path $globalSkillRoot 'factorio-mod-qc\scripts\factorio-qc-lib.ps1'
        portal_search_script   = Join-Path $globalSkillRoot 'factorio-mod-qc\scripts\search-factorio-mod-portal.ps1'
        firefox_skill_root     = Join-Path $globalSkillRoot 'chatgpt-firefox-companion'
        firefox_invoke_script  = Join-Path $globalSkillRoot 'chatgpt-firefox-companion\scripts\invoke-chatgpt-firefox-companion.ps1'
        global_shim_root       = Join-Path $globalSkillRoot 'esir-dev'
        dependency_invoke_script = Join-Path $resolvedRepoRoot 'scripts\invoke-esir-dependency-intel.ps1'
        dependency_lib_script    = Join-Path $resolvedRepoRoot 'scripts\esir-dependency-lib.ps1'
        runtime_manifest_path  = Join-Path $manifestRoot 'runtime-modules.json'
        prototype_index_path   = Join-Path $manifestRoot 'prototype-index.json'
        pack_manifest_path     = Join-Path $manifestRoot 'pack-manifest.json'
        save_catalog_path      = Join-Path $manifestRoot 'save-catalog.json'
        tool_manifest_path     = Join-Path $manifestRoot 'tool-manifest.json'
        portal_shortlist_path  = Join-Path $manifestRoot 'portal-shortlist.json'
        asset_import_plan_path = Join-Path $manifestRoot 'asset-import-plan.json'
        dependency_catalog_path = Join-Path $manifestRoot 'dependency-catalog.json'
    }
}

function Write-EsirJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Data
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $json = $Data | ConvertTo-Json -Depth 16
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Read-EsirJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return ((Get-EsirTextContent -Path $Path) | ConvertFrom-Json)
}

function Get-EsirByteEncodingSignals {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes) {
        $Bytes = @()
    }

    $nulBytes = 0
    $evenNulls = 0
    $oddNulls = 0
    $evenCount = 0
    $oddCount = 0

    for ($index = 0; $index -lt $Bytes.Length; $index++) {
        if (($index % 2) -eq 0) {
            $evenCount += 1
        } else {
            $oddCount += 1
        }

        if ($Bytes[$index] -ne 0) {
            continue
        }

        $nulBytes += 1
        if (($index % 2) -eq 0) {
            $evenNulls += 1
        } else {
            $oddNulls += 1
        }
    }

    $oddNullRatio = if ($oddCount -gt 0) { $oddNulls / [double]$oddCount } else { 0.0 }
    $evenNullRatio = if ($evenCount -gt 0) { $evenNulls / [double]$evenCount } else { 0.0 }

    return [pscustomobject]@{
        nul_bytes       = $nulBytes
        nul_ratio       = if ($Bytes.Length -gt 0) { $nulBytes / [double]$Bytes.Length } else { 0.0 }
        looks_utf16le   = ($Bytes.Length -ge 4 -and $oddNullRatio -ge 0.35 -and $evenNullRatio -le 0.10)
        looks_utf16be   = ($Bytes.Length -ge 4 -and $evenNullRatio -ge 0.35 -and $oddNullRatio -le 0.10)
        odd_null_ratio  = $oddNullRatio
        even_null_ratio = $evenNullRatio
    }
}

function Read-EsirTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$AllowFallback
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)

    $hadBom = $false
    $encodingName = 'utf8'
    $isUtf8 = $true
    $fallbackUsed = $false
    $text = ''
    $writeEncoding = $utf8NoBom
    $payloadOffset = 0
    $signals = Get-EsirByteEncodingSignals -Bytes $bytes

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $hadBom = $true
        $encodingName = 'utf8-bom'
        $writeEncoding = $utf8Bom
        $payloadOffset = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $hadBom = $true
        $encodingName = 'utf16le-bom'
        $isUtf8 = $false
        $payloadOffset = 2
        $text = if ($bytes.Length -gt 2) { [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) } else { '' }
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $hadBom = $true
        $encodingName = 'utf16be-bom'
        $isUtf8 = $false
        $payloadOffset = 2
        $text = if ($bytes.Length -gt 2) { [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2) } else { '' }
    } elseif ($signals.looks_utf16le) {
        $encodingName = 'utf16le-no-bom'
        $isUtf8 = $false
        $text = [System.Text.Encoding]::Unicode.GetString($bytes)
    } elseif ($signals.looks_utf16be) {
        $encodingName = 'utf16be-no-bom'
        $isUtf8 = $false
        $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes)
    }

    if ($encodingName -like 'utf8*') {
        try {
            $payloadLength = $bytes.Length - $payloadOffset
            $text = if ($payloadLength -gt 0) { $utf8Strict.GetString($bytes, $payloadOffset, $payloadLength) } else { '' }
        } catch {
            if (-not $AllowFallback) {
                throw
            }

            $ansiCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
            $ansiEncoding = [System.Text.Encoding]::GetEncoding($ansiCodePage)
            $text = $ansiEncoding.GetString($bytes)
            $encodingName = 'ansi-' + $ansiCodePage
            $isUtf8 = $false
            $fallbackUsed = $true
            $writeEncoding = $utf8NoBom
        }
    }

    return [pscustomobject]@{
        path           = $Path
        bytes          = $bytes
        text           = $text
        encoding       = $encodingName
        had_bom        = $hadBom
        is_utf8        = $isUtf8
        fallback_used  = $fallbackUsed
        signals        = $signals
        write_encoding = $writeEncoding
    }
}

function Get-EsirTextContent {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Read-EsirTextFile -Path $Path -AllowFallback).text
}

function Get-EsirTextLines {
    param([Parameter(Mandatory = $true)][string]$Path)

    return @((Get-EsirTextContent -Path $Path) -split "`r?`n")
}

function Get-EsirNewlineStyle {
    param([AllowEmptyString()][string]$Text)

    if ($Text -match "`r`n") { return "`r`n" }
    if ($Text -match "`n") { return "`n" }
    return [Environment]::NewLine
}

function Get-EsirEncodingHealth {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        $Text = ''
    }

    $patterns = @(
        @{ name = 'replacement-char'; pattern = '\uFFFD'; weight = 5 },
        @{ name = 'latin1-mojibake'; pattern = '\u00C3[\u0080-\u00BF]|\u00C2[\u00A0-\u00BF]'; weight = 4 },
        @{ name = 'punctuation-mojibake'; pattern = '\u00E2[\u0080-\u00BF]{1,2}'; weight = 4 },
        @{ name = 'multibyte-mojibake'; pattern = '\u00F0[\u0080-\u00BF]{1,3}|\u00EF\u00BB\u00BF'; weight = 3 }
    )

    $findings = @()
    $score = 0
    foreach ($entry in $patterns) {
        $count = [regex]::Matches($Text, $entry.pattern).Count
        if ($count -gt 0) {
            $score += ($count * $entry.weight)
            $findings += [ordered]@{ marker = $entry.name; count = $count }
        }
    }

    $c1Controls = [regex]::Matches($Text, '[\u0080-\u009F]').Count
    if ($c1Controls -gt 0) {
        $score += ($c1Controls * 2)
        $findings += [ordered]@{ marker = 'c1-controls'; count = $c1Controls }
    }

    return [pscustomobject]@{
        score    = $score
        findings = @($findings)
    }
}

function Repair-EsirMojibakeText {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        $Text = ''
    }

    $bestText = $Text
    $before = Get-EsirEncodingHealth -Text $Text
    $bestScore = $before.score
    $steps = [System.Collections.Generic.List[string]]::new()
    $cp1252 = [System.Text.Encoding]::GetEncoding(
        1252,
        [System.Text.EncoderExceptionFallback]::new(),
        [System.Text.DecoderExceptionFallback]::new()
    )
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

    for ($pass = 1; $pass -le 2; $pass++) {
        try {
            $candidateBytes = $cp1252.GetBytes($bestText)
            $candidateText = $utf8Strict.GetString($candidateBytes)
        } catch {
            break
        }

        $candidateHealth = Get-EsirEncodingHealth -Text $candidateText
        if ($candidateHealth.score -lt $bestScore) {
            $bestText = $candidateText
            $bestScore = $candidateHealth.score
            $steps.Add("cp1252-utf8-pass-$pass") | Out-Null
            continue
        }

        break
    }

    return [pscustomobject]@{
        text         = $bestText
        score_before = $before.score
        score_after  = $bestScore
        changed      = ($bestText -ne $Text)
        steps        = @($steps)
    }
}

function Get-EsirTextFileTargets {
    param([Parameter(Mandatory = $true)]$Paths)

    $extensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in @('.lua', '.cfg', '.json', '.md', '.txt', '.ps1', '.py', '.yml', '.yaml', '.ini')) {
        [void]$extensions.Add($extension)
    }

    $skipDirectories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($directory in @('.git', '.factorio-qc', '.factorio-lua-docs-cache', '.tmp_inspect', '.tools', '__pycache__', 'output', 'tmp')) {
        [void]$skipDirectories.Add($directory)
    }

    $targets = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $directories = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
    $directories.Push([System.IO.DirectoryInfo]::new($Paths.repo_root))

    while ($directories.Count -gt 0) {
        $directory = $directories.Pop()
        try {
            foreach ($file in $directory.EnumerateFiles()) {
                if ($file.Name -in @('.gitignore', 'AGENTS.md') -or $extensions.Contains($file.Extension)) {
                    $targets.Add($file) | Out-Null
                }
            }

            foreach ($child in $directory.EnumerateDirectories()) {
                if (-not $skipDirectories.Contains($child.Name)) {
                    $directories.Push($child)
                }
            }
        } catch {
            continue
        }
    }

    return @($targets | Sort-Object FullName -Unique)
}

function Invoke-EsirEncodingPass {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [switch]$Fix
    )

    $findings = @()
    foreach ($file in (Get-EsirTextFileTargets -Paths $Paths)) {
        $relativePath = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file.FullName
        $readInfo = Read-EsirTextFile -Path $file.FullName -AllowFallback
        $health = Get-EsirEncodingHealth -Text $readInfo.text

        $issues = [System.Collections.Generic.List[string]]::new()
        if (-not $readInfo.is_utf8) {
            if ($readInfo.fallback_used) {
                $issues.Add('invalid-or-ansi-encoded-source') | Out-Null
            } else {
                $issues.Add('non-utf8-text-encoding') | Out-Null
            }
        }
        if ($health.score -gt 0) {
            $issues.Add('mojibake-suspected') | Out-Null
        }

        if ($issues.Count -eq 0) {
            continue
        }

        $fixed = $false
        $repair = $null
        if ($Fix) {
            $targetText = $readInfo.text
            $repair = Repair-EsirMojibakeText -Text $targetText
            if ($repair.changed -and $repair.score_after -lt $repair.score_before) {
                $targetText = $repair.text
            }

            $postHealth = Get-EsirEncodingHealth -Text $targetText
            $shouldRewrite = ((-not $readInfo.is_utf8) -or ($postHealth.score -lt $health.score))
            if ($shouldRewrite) {
                $withBom = ($readInfo.encoding -eq 'utf8-bom')
                [System.IO.File]::WriteAllText($file.FullName, $targetText, [System.Text.UTF8Encoding]::new($withBom))
                $fixed = $true
                $readInfo = Read-EsirTextFile -Path $file.FullName -AllowFallback
                $health = Get-EsirEncodingHealth -Text $readInfo.text
                $issues = [System.Collections.Generic.List[string]]::new()
                if (-not $readInfo.is_utf8) { $issues.Add('non-utf8-text-encoding') | Out-Null }
                if ($health.score -gt 0) { $issues.Add('mojibake-suspected') | Out-Null }
            }
        }

        $status = if ($issues.Count -gt 0) { 'failed' } elseif ($fixed) { 'warning' } else { 'ok' }
        $findings += [ordered]@{
            file         = $relativePath
            status       = $status
            encoding     = $readInfo.encoding
            fixed        = $fixed
            issues       = @($issues)
            mojibake     = $health.findings
            repair_steps = if ($repair) { @($repair.steps) } else { @() }
        }
    }

    $overallStatus = if (@($findings | Where-Object { $_.status -eq 'failed' }).Count -gt 0) {
        'failed'
    } elseif (@($findings | Where-Object { $_.fixed }).Count -gt 0) {
        'warning'
    } else {
        'ok'
    }

    return [ordered]@{
        scanned_files = @(Get-EsirTextFileTargets -Paths $Paths).Count
        overall_status = $overallStatus
        findings = @($findings)
        fixed_files = @($findings | Where-Object { $_.fixed } | ForEach-Object { $_.file })
    }
}

function Get-RelativeRepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $targetPath = if (Test-Path -LiteralPath $Path) {
        (Resolve-Path -LiteralPath $Path).Path
    } elseif ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $resolvedRepoRoot $Path))
    }

    $baseUri = [System.Uri]($resolvedRepoRoot.TrimEnd('\') + '\')
    $targetUri = [System.Uri]$targetPath
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Resolve-EsirUserPath {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $Paths.repo_root $Path
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Import-EsirFactorioQc {
    param([Parameter(Mandatory = $true)]$Paths)

    if (-not (Get-Command Get-FactorioQCContext -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path -LiteralPath $Paths.factorio_lib_script)) {
            throw "Factorio QC library not found: $($Paths.factorio_lib_script). Install or repair the global factorio-mod-qc skill."
        }
        . $Paths.factorio_lib_script
        $script:EsirFactorioQcLoaded = $true
    }
}

function Get-EsirQcContext {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$FactorioPath,
        [switch]$EnsureArtifactRoot
    )

    Import-EsirFactorioQc -Paths $Paths
    return (Get-FactorioQCContext -RepoRoot $Paths.repo_root -FactorioPath $FactorioPath -EnsureArtifactRoot:$EnsureArtifactRoot)
}

function Get-EsirRuntimeOverrideMap {
    if ($script:EsirRuntimeOverrideMap) {
        return $script:EsirRuntimeOverrideMap
    }

    $script:EsirRuntimeOverrideMap = @{
        'exotic-space-industries-remembrance\lib\echo-codex.lua' = @{ owns = 'startup/configuration messaging, arrival-wave rendering, and visual settings mirrors'; cadence = 'init, configuration-changed, on_load, and every-tick arrival-wave cleanup'; events = @('on_init', 'on_configuration_changed', 'on_load', 'on_tick', 'on_cutscene_cancelled', 'on_cutscene_finished', 'on_player_respawned'); storage_roots = @('storage.ei.arrival_waves', 'storage.ei.lamp_removals', 'storage.ei.que_*', 'storage.ei.em_*_glow*', 'storage.ei.rocket_launch_pollution', 'storage.ei.fulgora_day_length_variation', 'storage.ei.nauvis_pressure'); rebuild_on = @('startup setting changes', 'init', 'configuration migration') }
        'exotic-space-industries-remembrance\scripts\control\tech-scaling.lua' = @{ owns = 'tech cost scaling'; cadence = 'init, configuration-changed, and research-finished'; rebuild_on = @('startup settings', 'prototype changes') }
        'exotic-space-industries-remembrance\scripts\control\global.lua' = @{ owns = 'root storage schema and scheduled runtime sanity'; cadence = 'init, configuration-changed, and scheduled tick step 1'; rebuild_on = @('init', 'configuration change') }
        'exotic-space-industries-remembrance\scripts\control\register-util.lua' = @{ owns = 'shared entity registration helpers'; cadence = 'build/destroy helper dispatch'; rebuild_on = @('init', 'entity rebuilds') }
        'exotic-space-industries-remembrance\scripts\control\teslas-legacy.lua' = @{ owns = 'hybrid Tesla legacy runtime'; cadence = 'init, load, configuration-changed, combat, research, build, destroy, and script triggers'; rebuild_on = @('configuration change') }
        'exotic-space-industries-remembrance\scripts\control\powered-beacon.lua' = @{ owns = 'invalid fluid entity updates and beacon-side fluid maintenance'; cadence = 'scheduled tick step 2 plus build/destroy checks'; rebuild_on = @('entity registration changes') }
        'exotic-space-industries-remembrance\scripts\control\beacon-overload.lua' = @{ owns = 'beacon overload effects and icons'; cadence = 'build, destroy, and configuration refresh'; rebuild_on = @('configuration change', 'beacon-machine topology changes') }
        'exotic-space-industries-remembrance\scripts\control\spidertron-limiter.lua' = @{ owns = 'spidertron logistic slot restriction'; cadence = 'logistic slot change' }
        'exotic-space-industries-remembrance\scripts\control\victory-disabler.lua' = @{ owns = 'victory screen disabling and Better Victory Screen bridge'; cadence = 'init'; remote_interfaces = @('exotic-industries-bvs'); rebuild_on = @('init', 'configuration change') }
        'exotic-space-industries-remembrance\scripts\control\alien-spawner.lua' = @{ owns = 'Gaia alien spawning, queues, and selection tooling'; cadence = 'chunk generation, selected area, console command, destroy hooks, and every-tick queue update'; rebuild_on = @('Gaia mapgen changes', 'Gaia content changes') }
        'exotic-space-industries-remembrance\scripts\control\informatron.lua' = @{ owns = 'main Informatron pages'; cadence = 'load-time remote interface registration'; remote_interfaces = @('exotic-industries-informatron'); rebuild_on = @('Informatron page/content changes') }
        'exotic-space-industries-remembrance\scripts\control\milestone-preset.lua' = @{ owns = 'Milestones integration preset'; cadence = 'load-time remote interface registration'; remote_interfaces = @('exotic-industries-milestones'); rebuild_on = @('progression or milestone changes') }
        'exotic-space-industries-remembrance\scripts\control\matter-stabilizer.lua' = @{ owns = 'matter runtime, queues, and player rendering cleanup'; cadence = 'build/destroy, selection/cursor/player-left, scheduled tick step 4, and configuration rebuild'; rebuild_on = @('init', 'configuration change', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\neutron-collector.lua' = @{ owns = 'neutron collector and source runtime'; cadence = 'build/destroy, scheduled tick step 3, and configuration rebuild'; rebuild_on = @('init', 'configuration change', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\fusion-reactor.lua' = @{ owns = 'fusion reactor GUI and runtime hooks'; cadence = 'build and GUI open/close/click/value-change dispatch'; gui_ids = @('ei-fusion-reactor-console'); rebuild_on = @('entity schema changes', 'GUI schema changes') }
        'exotic-space-industries-remembrance\scripts\control\induction-matrix.lua' = @{ owns = 'induction matrix GUI, runtime, and tile hooks'; cadence = 'build, destroy, tile changes, GUI dispatch, and every-tick runtime updates'; gui_ids = @('ei-induction-matrix-console'); rebuild_on = @('tile topology changes', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\black-hole.lua' = @{ owns = 'black hole GUI and runtime'; cadence = 'build, destroy, GUI dispatch, and every-tick runtime updates'; gui_ids = @('ei-black-hole-console'); rebuild_on = @('entity schema changes', 'GUI schema changes') }
        'exotic-space-industries-remembrance\scripts\control\informatron-messager.lua' = @{ owns = 'research-finished messaging'; cadence = 'research-finished'; rebuild_on = @('progression text changes') }
        'exotic-space-industries-remembrance\scripts\control\gaia.lua' = @{ owns = 'Gaia runtime, spawn command, build hooks, and reforge behavior'; cadence = 'console command, build hooks, scheduled tick step 1, and every-tick Gaia updates'; rebuild_on = @('Gaia mapgen changes', 'Gaia prototype changes', 'configuration changes') }
        'exotic-space-industries-remembrance\scripts\control\gate.lua' = @{ owns = 'gate runtime, GUI, selector flow, and remote dispatch'; cadence = 'init, build/destroy, selection/cursor, GUI, script triggers, player cleanup, scheduled tick step 7, and configuration changes'; gui_ids = @('ei-gate-console'); rebuild_on = @('init', 'configuration change', 'gate topology changes') }
        'exotic-space-industries-remembrance\scripts\control\alien-system.lua' = @{ owns = 'alien-system build, selection, and GUI click dispatch'; cadence = 'build, selected-area, and GUI click dispatch'; gui_ids = @('ei-alien-gui'); rebuild_on = @('alien-system prototype changes') }
        'exotic-space-industries-remembrance\scripts\control\debug.lua' = @{ owns = 'debug console teleport command'; cadence = 'console command' }
        'exotic-space-industries-remembrance\scripts\control\compat.lua' = @{ owns = 'compatibility init and configuration checks'; cadence = 'init and configuration-changed'; rebuild_on = @('mod changes') }
        'exotic-space-industries-remembrance\lib\loaders.lua' = @{ owns = 'runtime loader snapping and loader helper functions'; cadence = 'build dispatch and on-demand helper use'; rebuild_on = @('loader prototype changes', 'loader layout changes') }
        'exotic-space-industries-remembrance\scripts\control\rocket-launch-pollution.lua' = @{ owns = 'rocket launch pollution queues and effects'; cadence = 'launch ordered, launch completed, and every-tick updates'; rebuild_on = @('startup setting changes', 'configuration changes') }
        'exotic-space-industries-remembrance\scripts\control\fulgora-day-length-variation.lua' = @{ owns = 'Fulgora day-length variation'; cadence = 'every tick'; rebuild_on = @('startup setting changes', 'configuration changes') }
        'exotic-space-industries-remembrance\scripts\control\mining-scars.lua' = @{ owns = 'depleted-resource scar behavior'; cadence = 'resource depletion'; rebuild_on = @('resource prototype changes', 'scar prototype changes') }
        'exotic-space-industries-remembrance\scripts\control\vulcanus-fumaroles.lua' = @{ owns = 'auric fumarole runtime generation, depletion, and afterglow cleanup'; cadence = 'init, configuration-changed, chunk generation, resource depletion, and every-tick cleanup'; rebuild_on = @('init', 'configuration change', 'Vulcanus resource prototype changes') }
        'exotic-space-industries-remembrance\scripts\control\nauvis-pressure-grace.lua' = @{ owns = 'Nauvis pressure grace milestone and pollution/evolution pressure'; cadence = 'configuration changes, research-finished, and scheduled tick step 1'; rebuild_on = @('startup settings', 'research progression', 'configuration changes') }
        'exotic-space-industries-remembrance\scripts\control\fueler\fueler.lua' = @{ owns = 'fueler towers, targets, player servicing, and console GUI'; cadence = 'init/config rebuild, build/destroy, scheduled tick step 6, and GUI open/close/click'; gui_ids = @('ei-fueler-console'); rebuild_on = @('init', 'configuration change', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\fueler\informatron.lua' = @{ owns = 'Fueler Informatron page'; cadence = 'load-time remote interface registration'; remote_interfaces = @('exotic-industries-fueler-informatron'); rebuild_on = @('page/content changes') }
        'exotic-space-industries-remembrance\scripts\control\em-trains\charger.lua' = @{ owns = 'EM train and charger runtime, buffs, rebuilds, and research hooks'; cadence = 'init/config rebuild, build/destroy, research-finished, and scheduled tick steps 8 and 9'; rebuild_on = @('init', 'configuration change', 'entity topology changes', 'research changes') }
        'exotic-space-industries-remembrance\scripts\control\em-trains\gui.lua' = @{ owns = 'EM train GUI and dirty refresh'; cadence = 'every-tick dirty refresh and GUI click dispatch'; gui_ids = @('ei_emt_button', 'ei_mod-gui', 'mod_gui'); rebuild_on = @('GUI schema changes', 'EM train runtime changes') }
        'exotic-space-industries-remembrance\scripts\control\em-trains\informatron.lua' = @{ owns = 'EM train Informatron integration'; cadence = 'load-time integration hooks'; rebuild_on = @('page/content changes') }
        'exotic-space-industries-remembrance\scripts\control\steam-train.lua' = @{ owns = 'steam locomotive wheel and helper runtime'; cadence = 'init/config rebuild, build/destroy, train state changes, and every-tick runtime updates'; rebuild_on = @('init', 'configuration change', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\camp-fire.lua' = @{ owns = 'camp-fire periodic fire spawning'; cadence = 'build/destroy and scheduled tick step 1'; rebuild_on = @('init', 'configuration change', 'entity topology changes') }
        'exotic-space-industries-remembrance\scripts\control\orbital-combinator.lua' = @{ owns = 'orbital combinator and platform bank mirroring'; cadence = 'init/config, build/destroy, logistic slot change, settings paste, platform state change, and scheduled tick step 5'; rebuild_on = @('init', 'configuration change', 'platform topology changes', 'combinator topology changes') }
        'exotic-space-industries-remembrance\scripts\control\orbital-logistics.lua' = @{ owns = 'orbital logistics cohort runtime, including platform transponder IDs, selector focus/policy, coordinator arbitration, dispatch uplinks, leased mixed-manifest jobs, cohort GUIs, and QC/runtime snapshots'; cadence = 'event-driven invalidation plus dedicated control.lua step-10 cohort servicing'; events = @('check_init', 'rebuild_runtime_state', 'on_built_entity', 'on_destroyed_entity', 'on_entity_logistic_slot_changed', 'on_entity_settings_pasted', 'on_space_platform_changed_state', 'on_rocket_launch_ordered', 'request_runtime_rescan', 'open_gui', 'close_gui', 'on_player_left_game', 'on_gui_click', 'on_gui_selection_state_changed', 'on_gui_text_changed', 'update', 'get_pending_work_count', 'get_runtime_status', 'get_qc_snapshot'); storage_roots = @('storage.ei.orbital_logistics'); gui_ids = @('ei-orbital-logistics-console'); remote_interfaces = @('exposed indirectly through control.lua QC hooks'); rebuild_on = @('init', 'configuration change', 'admin rescan', 'cohort entity churn') }
    }

    return $script:EsirRuntimeOverrideMap
}

function Get-DirectAssignedRequires {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if ($script:EsirAssignedRequireCache.ContainsKey($FilePath)) {
        return @($script:EsirAssignedRequireCache[$FilePath])
    }

    $content = Get-LuaReachableStaticContentForFile -FilePath $FilePath
    $records = @()
    foreach ($match in [regex]::Matches($content, '(?m)^\s*(?:local\s+)?(?<id>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*require\("(?<req>[^"]+)"\)')) {
        $records += [pscustomobject]@{ id = $match.Groups['id'].Value; require = $match.Groups['req'].Value }
    }

    $script:EsirAssignedRequireCache[$FilePath] = @($records)
    return @($records)
}

function Get-DirectBareRequires {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if ($script:EsirBareRequireCache.ContainsKey($FilePath)) {
        return @($script:EsirBareRequireCache[$FilePath])
    }

    $content = Get-LuaReachableStaticContentForFile -FilePath $FilePath
    $records = @()
    foreach ($match in [regex]::Matches($content, '(?m)^\s*require\("(?<req>[^"]+)"\)')) {
        $records += [pscustomobject]@{ require = $match.Groups['req'].Value }
    }

    $script:EsirBareRequireCache[$FilePath] = @($records)
    return @($records)
}

function Get-LuaStaticScanContent {
    param([string]$Content)

    if ($null -eq $Content) {
        return ''
    }

    $builder = [System.Text.StringBuilder]::new()
    $state = 'normal'
    for ($index = 0; $index -lt $Content.Length; $index++) {
        $char = $Content[$index]
        switch ($state) {
            'normal' {
                if ($char -eq '-' -and $index + 1 -lt $Content.Length -and $Content[$index + 1] -eq '-') {
                    if ($index + 3 -lt $Content.Length -and $Content[$index + 2] -eq '[' -and $Content[$index + 3] -eq '[') {
                        $state = 'block-comment'
                        $index += 3
                        continue
                    }

                    $state = 'line-comment'
                    $index += 1
                    continue
                }

                [void]$builder.Append($char)
                if ($char -eq '"') {
                    $state = 'double-quote'
                } elseif ($char -eq "'") {
                    $state = 'single-quote'
                }
            }
            'single-quote' {
                [void]$builder.Append($char)
                if ($char -eq '\' -and $index + 1 -lt $Content.Length) {
                    $index += 1
                    [void]$builder.Append($Content[$index])
                    continue
                }
                if ($char -eq "'") {
                    $state = 'normal'
                }
            }
            'double-quote' {
                [void]$builder.Append($char)
                if ($char -eq '\' -and $index + 1 -lt $Content.Length) {
                    $index += 1
                    [void]$builder.Append($Content[$index])
                    continue
                }
                if ($char -eq '"') {
                    $state = 'normal'
                }
            }
            'line-comment' {
                if ($char -eq "`r" -or $char -eq "`n") {
                    [void]$builder.Append($char)
                    $state = 'normal'
                }
            }
            'block-comment' {
                if ($char -eq ']' -and $index + 1 -lt $Content.Length -and $Content[$index + 1] -eq ']') {
                    $state = 'normal'
                    $index += 1
                    continue
                }

                if ($char -eq "`r" -or $char -eq "`n") {
                    [void]$builder.Append($char)
                }
            }
        }
    }

    return $builder.ToString()
}

function Get-LuaStaticallyReachableContent {
    param([AllowEmptyString()][string]$Content)

    if ($null -eq $Content) {
        return ''
    }

    $activeLines = [System.Collections.Generic.List[string]]::new()
    $skipToLabel = $null
    $enabledMods = Get-EsirEnabledLocalMods
    $seenExecutableLine = $false
    foreach ($line in ($Content -split "`r?`n")) {
        $trimmed = $line.Trim()

        if ($skipToLabel) {
            if ($line -match '^::(?<label>[A-Za-z_][A-Za-z0-9_]*)::\s*$' -and $matches['label'] -eq $skipToLabel) {
                $skipToLabel = $null
            }
            continue
        }

        if (-not $seenExecutableLine -and $trimmed) {
            if ($trimmed -match '^\s*if\s+not\s+mods\[(?<quote>["''])(?<mod>[^"''\]]+)\k<quote>\]\s+then\s+return\s+end\s*$') {
                if (-not $enabledMods.Contains($matches['mod'])) {
                    break
                }
                continue
            }

            if ($trimmed -match '^\s*if\s+not\s+\((?<expr>.+)\)\s+then\s+return\s+end\s*$') {
                $expression = $matches['expr'].Trim()
                $modRefPattern = 'mods\[(?:["''])[^"''\]]+(?:["''])\]'
                $modNamePattern = 'mods\[(?<quote>["''])(?<mod>[^"''\]]+)\k<quote>\]'
                if ($expression -match ('^\s*' + $modRefPattern + '(?:\s+or\s+' + $modRefPattern + ')*\s*$')) {
                    $isEnabled = $false
                    foreach ($match in [regex]::Matches($expression, $modNamePattern)) {
                        if ($enabledMods.Contains($match.Groups['mod'].Value)) {
                            $isEnabled = $true
                            break
                        }
                    }
                    if (-not $isEnabled) {
                        break
                    }
                    continue
                }
            }
        }

        if ($line -match '^goto\s+(?<label>[A-Za-z_][A-Za-z0-9_]*)\s*$') {
            $skipToLabel = $matches['label']
            continue
        }

        if ($line -match '^return(?:\s|$)') {
            break
        }

        if ($trimmed) {
            $seenExecutableLine = $true
        }
        $activeLines.Add($line) | Out-Null
    }

    return ($activeLines -join "`n")
}

function Get-LuaReachableStaticContentForFile {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if ($script:EsirLuaStaticReachableContentCache.ContainsKey($FilePath)) {
        return [string]$script:EsirLuaStaticReachableContentCache[$FilePath]
    }

    $content = Get-EsirTextContent -Path $FilePath
    $staticContent = Get-LuaStaticallyReachableContent -Content (Get-LuaStaticScanContent -Content $content)
    $script:EsirLuaStaticReachableContentCache[$FilePath] = $staticContent
    return $staticContent
}

function Get-LuaRequirePathVariants {
    param([Parameter(Mandatory = $true)][string]$RequireName)

    $normalized = $RequireName.Replace('\', '/').Trim()
    if (-not $normalized) {
        return @()
    }

    $variants = [System.Collections.Generic.List[string]]::new()
    $variants.Add($normalized) | Out-Null

    if ($normalized.EndsWith('.lua', [System.StringComparison]::OrdinalIgnoreCase)) {
        $variants.Add($normalized.Substring(0, $normalized.Length - 4)) | Out-Null
    }

    if ($normalized -notmatch '[\\/]') {
        $dotted = $normalized -replace '\.', '/'
        if ($dotted -and $dotted -ne $normalized) {
            $variants.Add($dotted) | Out-Null
            if ($dotted.EndsWith('.lua', [System.StringComparison]::OrdinalIgnoreCase)) {
                $variants.Add($dotted.Substring(0, $dotted.Length - 4)) | Out-Null
            }
        }
    }

    return @($variants | Where-Object { $_ } | Select-Object -Unique)
}

function Resolve-RepoLuaRequire {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$RequireName,
        [Parameter(Mandatory = $true)]$SourceMods
    )

    $cacheKey = '{0}|{1}' -f $FilePath, $RequireName
    if ($script:EsirResolvedRequireCache.ContainsKey($cacheKey)) {
        return $script:EsirResolvedRequireCache[$cacheKey]
    }

    if ($RequireName -like '__*' -or $RequireName -in @('util', 'serpent', 'mod-gui')) {
        $result = [pscustomobject]@{ require = $RequireName; exists = $true; is_external = $true; path = $null }
        $script:EsirResolvedRequireCache[$cacheKey] = $result
        return $result
    }

    $ownerMod = $null
    foreach ($sourceMod in $SourceMods) {
        if ($FilePath.StartsWith($sourceMod.directory, [System.StringComparison]::OrdinalIgnoreCase)) {
            $ownerMod = $sourceMod
            break
        }
    }

    $candidateRoots = @((Split-Path -Parent $FilePath))
    if ($ownerMod) {
        $candidateRoots += $ownerMod.directory
    }

    foreach ($basePath in ($candidateRoots | Select-Object -Unique)) {
        foreach ($variant in (Get-LuaRequirePathVariants -RequireName $RequireName)) {
            $candidateRelativePaths = [System.Collections.Generic.List[string]]::new()
            $candidateRelativePaths.Add(($variant -replace '/', '\')) | Out-Null

            if (-not $variant.EndsWith('.lua', [System.StringComparison]::OrdinalIgnoreCase)) {
                $candidateRelativePaths.Add((($variant + '.lua') -replace '/', '\')) | Out-Null
                $candidateRelativePaths.Add((($variant + '/init.lua') -replace '/', '\')) | Out-Null
            }

            foreach ($relativePath in ($candidateRelativePaths | Select-Object -Unique)) {
                $candidate = Join-Path $basePath $relativePath
                if ([System.IO.File]::Exists($candidate)) {
                    $result = [pscustomobject]@{ require = $RequireName; exists = $true; is_external = $false; path = [System.IO.Path]::GetFullPath($candidate) }
                    $script:EsirResolvedRequireCache[$cacheKey] = $result
                    return $result
                }
            }
        }
    }

    $result = [pscustomobject]@{ require = $RequireName; exists = $false; is_external = $false; path = $null }
    $script:EsirResolvedRequireCache[$cacheKey] = $result
    return $result
}

function Get-EsirLuaEntrypointFiles {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)]$Context
    )

    $entryNames = @(
        'settings.lua',
        'settings-updates.lua',
        'settings-final-fixes.lua',
        'data.lua',
        'data-updates.lua',
        'data-final-fixes.lua',
        'control.lua'
    )

    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($mod in $Context.source_mods) {
        foreach ($entryName in $entryNames) {
            $entryPath = Join-Path $mod.directory $entryName
            if (Test-Path -LiteralPath $entryPath) {
                $files.Add((Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $entryPath)) | Out-Null
            }
        }

        $migrationRoot = Join-Path $mod.directory 'migrations'
        if (Test-Path -LiteralPath $migrationRoot) {
            foreach ($file in Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.lua') {
                $files.Add((Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file.FullName)) | Out-Null
            }
        }
    }

    return @($files | Sort-Object -Unique)
}

function Get-EsirReachableLuaFiles {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)]$Context
    )

    if ($script:EsirReachableLuaCache.ContainsKey($Paths.repo_root)) {
        return @($script:EsirReachableLuaCache[$Paths.repo_root])
    }

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($entry in (Get-EsirLuaEntrypointFiles -Paths $Paths -Context $Context)) {
        $queue.Enqueue($entry)
    }

    while ($queue.Count -gt 0) {
        $relativePath = $queue.Dequeue()
        if (-not $visited.Add($relativePath)) {
            continue
        }

        $filePath = Join-Path $Paths.repo_root $relativePath
        if (-not (Test-Path -LiteralPath $filePath)) {
            continue
        }

        $records = @()
        $records += @(Get-DirectBareRequires -FilePath $filePath)
        $records += @(Get-DirectAssignedRequires -FilePath $filePath)
        foreach ($record in $records) {
            $resolved = Resolve-RepoLuaRequire -RepoRoot $Paths.repo_root -FilePath $filePath -RequireName $record.require -SourceMods $Context.source_mods
            if (-not $resolved.exists -or $resolved.is_external) {
                continue
            }

            $childRelativePath = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $resolved.path
            if (-not $visited.Contains($childRelativePath)) {
                $queue.Enqueue($childRelativePath)
            }
        }
    }

    $result = @($visited | Sort-Object)
    $script:EsirReachableLuaCache[$Paths.repo_root] = $result
    return $result
}

function Test-EsirReachableLuaFiles {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)]$Context
    )

    $failures = @()
    if (-not $Context.luac_exe) {
        return [pscustomobject]@{
            tool_path    = $null
            failures     = $failures
            skipped      = $true
            scanned_count = 0
        }
    }

    $relativePaths = @()
    foreach ($relativePath in (Get-EsirReachableLuaFiles -Paths $Paths -Context $Context)) {
        $filePath = Join-Path $Paths.repo_root $relativePath
        if (-not (Test-Path -LiteralPath $filePath)) {
            continue
        }

        $relativePaths += $relativePath
    }

    $scannedCount = $relativePaths.Count
    $chunkSize = 50
    Push-Location $Paths.repo_root
    try {
        for ($start = 0; $start -lt $relativePaths.Count; $start += $chunkSize) {
            $end = [Math]::Min($start + $chunkSize - 1, $relativePaths.Count - 1)
            $chunk = @($relativePaths[$start..$end])
            $previousPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & $Context.luac_exe -p @chunk 2>&1 | ForEach-Object { "$_" }
            } finally {
                $ErrorActionPreference = $previousPreference
            }

            if ($LASTEXITCODE -eq 0) {
                continue
            }

            foreach ($relativePath in $chunk) {
                $filePath = Join-Path $Paths.repo_root $relativePath
                $previousPreference = $ErrorActionPreference
                try {
                    $ErrorActionPreference = 'Continue'
                    $output = & $Context.luac_exe -p $relativePath 2>&1 | ForEach-Object { "$_" }
                } finally {
                    $ErrorActionPreference = $previousPreference
                }

                if ($LASTEXITCODE -ne 0) {
                    $failures += [pscustomobject]@{
                        file  = $filePath
                        error = ($output -join ' ')
                    }
                }
            }
        }
    } finally {
        Pop-Location
    }

    return [pscustomobject]@{
        tool_path    = $Context.luac_exe
        failures     = $failures
        skipped      = $false
        scanned_count = $scannedCount
    }
}

function Resolve-EsirLuaStringExpression {
    param(
        [Parameter(Mandatory = $true)][string]$Expression,
        [Parameter(Mandatory = $true)][hashtable]$KnownValues
    )

    $trimmed = $Expression.Trim()
    if (-not $trimmed) {
        return $null
    }

    $builder = [System.Text.StringBuilder]::new()
    foreach ($segment in ($trimmed -split '\.\.')) {
        $token = $segment.Trim()
        if (-not $token) {
            return $null
        }

        if ((($token.StartsWith('"')) -and $token.EndsWith('"')) -or (($token.StartsWith("'")) -and $token.EndsWith("'"))) {
            [void]$builder.Append($token.Substring(1, $token.Length - 2))
            continue
        }

        if ($KnownValues.ContainsKey($token)) {
            [void]$builder.Append([string]$KnownValues[$token])
            continue
        }

        return $null
    }

    return $builder.ToString()
}

function Get-EsirAssetPathVariableMap {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)]$Context
    )

    $values = @{}
    $pathFiles = @(
        Join-Path $Paths.repo_root 'exotic-space-industries-remembrance\lib\paths.lua'
    ) | Where-Object { Test-Path -LiteralPath $_ }

    foreach ($pathFile in $pathFiles) {
        $pending = [System.Collections.Generic.List[object]]::new()
        foreach ($line in (Get-EsirTextLines -Path $pathFile)) {
            $trimmedLine = $line.Trim()
            if (-not $trimmedLine -or $trimmedLine.StartsWith('--')) {
                continue
            }

            if ($trimmedLine -match '^(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<expr>.+?)(?:\s*--.*)?$') {
                $pending.Add([pscustomobject]@{
                    name = $matches['name']
                    expr = $matches['expr'].Trim()
                }) | Out-Null
            }
        }

        $remaining = @($pending)
        $madeProgress = $true
        while ($madeProgress -and $remaining.Count -gt 0) {
            $madeProgress = $false
            $next = [System.Collections.Generic.List[object]]::new()
            foreach ($entry in $remaining) {
                $resolved = Resolve-EsirLuaStringExpression -Expression $entry.expr -KnownValues $values
                if ($null -ne $resolved) {
                    $values[$entry.name] = $resolved
                    $madeProgress = $true
                } else {
                    $next.Add($entry) | Out-Null
                }
            }

            $remaining = @($next)
        }
    }

    return $values
}

function Get-EsirLuaFieldPrefixMap {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][hashtable]$PathVariableMap
    )

    $fieldCandidates = @{}
    $pattern = '(?<prefix>(?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)\s*\.\.\s*(?:[A-Za-z_][A-Za-z0-9_]*\.)?(?<field>[A-Za-z_][A-Za-z0-9_]*)\b'
    foreach ($match in [regex]::Matches($Content, $pattern)) {
        $prefix = $match.Groups['prefix'].Value
        $field = $match.Groups['field'].Value
        if (-not $prefix -or -not $field) {
            continue
        }

        if (-not $PathVariableMap.ContainsKey($prefix)) {
            continue
        }

        if (-not $fieldCandidates.ContainsKey($field)) {
            $fieldCandidates[$field] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }

        [void]$fieldCandidates[$field].Add($prefix)
    }

    $resolvedMap = @{}
    foreach ($field in $fieldCandidates.Keys) {
        $prefixes = @($fieldCandidates[$field])
        if ($prefixes.Count -eq 1) {
            $resolvedMap[$field] = $prefixes[0]
        }
    }

    return $resolvedMap
}

function Resolve-EsirFactorioAssetReference {
    param(
        [Parameter(Mandatory = $true)][string]$AssetRef,
        [Parameter(Mandatory = $true)][hashtable]$ModMap
    )

    $normalizedRef = $AssetRef.Replace('/', '\')
    if ($normalizedRef -notlike '__*__\*') {
        return $null
    }

    $parts = $normalizedRef -split '\\', 2
    if ($parts.Count -lt 2) {
        return [pscustomobject]@{ exists = $false; is_external = $false; path = $null }
    }

    $modName = $parts[0].Trim('_')
    if ($modName -in @('base', 'core')) {
        return [pscustomobject]@{ exists = $true; is_external = $true; path = $null }
    }

    if (-not $ModMap.ContainsKey($modName)) {
        return [pscustomobject]@{ exists = $true; is_external = $true; path = $null }
    }

    $resolvedPath = Join-Path $ModMap[$modName] $parts[1]
    return [pscustomobject]@{
        exists      = (Test-Path -LiteralPath $resolvedPath)
        is_external = $false
        path        = $resolvedPath
    }
}

function Resolve-EsirAssetReferencePath {
    param(
        [Parameter(Mandatory = $true)][string]$AssetRef,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ModDirectory,
        [Parameter(Mandatory = $true)][hashtable]$ModMap,
        [Parameter(Mandatory = $true)][hashtable]$PathVariableMap,
        [string]$PrefixVariable
    )

    if ($PrefixVariable -and $PathVariableMap.ContainsKey($PrefixVariable)) {
        $prefixPath = [string]$PathVariableMap[$PrefixVariable]
        $combinedRef = (($prefixPath -replace '[\\/]+$','') + '/' + ($AssetRef -replace '^[\\/]+',''))
        $resolvedPrefixed = Resolve-EsirFactorioAssetReference -AssetRef $combinedRef -ModMap $ModMap
        if ($null -ne $resolvedPrefixed) {
            return $resolvedPrefixed
        }
    }

    $resolvedFactorioPath = Resolve-EsirFactorioAssetReference -AssetRef $AssetRef -ModMap $ModMap
    if ($null -ne $resolvedFactorioPath) {
        return $resolvedFactorioPath
    }

    $normalizedRef = $AssetRef.Replace('/', '\')
    $candidatePaths = @(
        Join-Path $ModDirectory $normalizedRef
        Join-Path (Split-Path -Parent $FilePath) $normalizedRef
    ) | Select-Object -Unique

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return [pscustomobject]@{ exists = $true; is_external = $false; path = $candidatePath }
        }
    }

    return [pscustomobject]@{ exists = $false; is_external = $false; path = $null }
}

function Get-LuaExportNames {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $content = Get-EsirTextContent -Path $FilePath
    if ($null -eq $content) { $content = '' }
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in @(
        '(?m)^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(',
        '(?m)^\s*[A-Za-z_][A-Za-z0-9_]*\.(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\('
    )) {
        foreach ($match in [regex]::Matches($content, $pattern)) {
            $name = $match.Groups['name'].Value
            if (-not $names.Contains($name)) {
                $names.Add($name) | Out-Null
            }
        }
    }

    return @($names | Sort-Object)
}

function Get-LuaStorageRoots {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $content = Get-EsirTextContent -Path $FilePath
    if ($null -eq $content) { $content = '' }
    $roots = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($content, 'storage\.([A-Za-z_][A-Za-z0-9_]*)')) {
        $value = 'storage.' + $match.Groups[1].Value
        if (-not $roots.Contains($value)) {
            $roots.Add($value) | Out-Null
        }
    }
    return @($roots | Sort-Object)
}

function Get-LuaRemoteInterfaces {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $content = Get-EsirTextContent -Path $FilePath
    if ($null -eq $content) { $content = '' }
    $interfaces = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($content, 'remote\.add_interface\s*\(\s*["''](?<name>[^"'']+)["'']')) {
        $name = $match.Groups['name'].Value
        if (-not $interfaces.Contains($name)) {
            $interfaces.Add($name) | Out-Null
        }
    }
    return @($interfaces | Sort-Object)
}

function Get-LuaGuiIds {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $content = Get-EsirTextContent -Path $FilePath
    if ($null -eq $content) { $content = '' }
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($content, '["''](?<id>[A-Za-z0-9_.-]*(?:gui|window|frame|dialog|button|console|panel|slot|selector|informatron)[A-Za-z0-9_.-]*)["'']')) {
        $value = $match.Groups['id'].Value
        if ($value.Length -lt 4) {
            continue
        }
        if (-not $ids.Contains($value)) {
            $ids.Add($value) | Out-Null
        }
    }
    return @($ids | Sort-Object)
}

function Get-LuaCadenceHint {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string[]]$Exports = @(),
        [Parameter(Mandatory = $true)][string]$LoadedBy
    )

    if ($LoadedBy -like '*data.lua') {
        return 'data-stage load'
    }

    $lowerExports = @($Exports | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToLowerInvariant() })
    if ($RelativePath -like '*\gui.lua') {
        return 'GUI dispatch and refresh'
    }
    if ($lowerExports | Where-Object { $_ -match 'updater|update|on_tick|train_updater|charger_updater|reforge_on_tick' }) {
        if ($lowerExports | Where-Object { $_ -like 'on_*' }) {
            return 'scheduled updates plus event-driven hooks'
        }
        return 'scheduled updates'
    }
    if ($lowerExports | Where-Object { $_ -like 'on_*' }) {
        return 'event-driven'
    }
    if ($lowerExports | Where-Object { $_ -match 'init|check_global|check_init|mark_dirty|rebuild' }) {
        return 'bootstrap and on-demand helper calls'
    }

    return 'on-demand helper calls'
}

function Get-LuaRebuildHints {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$LoadedBy
    )

    if ($LoadedBy -like '*data.lua') {
        return @('data stage reload', 'prototype cache rebuild')
    }

    $content = Get-EsirTextContent -Path $FilePath
    if ($null -eq $content) { $content = '' }
    $hints = [System.Collections.Generic.List[string]]::new()
    if ($content -match 'on_init|check_init|check_global') { $hints.Add('init') | Out-Null }
    if ($content -match 'on_configuration_changed|configuration') { $hints.Add('configuration change') | Out-Null }
    if ($content -match 'rebuild_runtime_state|rebuild') { $hints.Add('runtime rebuild') | Out-Null }
    if ($content -match 'remote\.add_interface|informatron') { $hints.Add('page/content changes') | Out-Null }
    if ($hints.Count -eq 0) { $hints.Add('owner-specific behavior changes') | Out-Null }
    return @($hints | Select-Object -Unique)
}

function New-EsirRuntimeEntry {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)]$SourceMods,
        [Parameter(Mandatory = $true)][string]$LoadedBy,
        [Parameter(Mandatory = $true)]$RequireRecord
    )

    $loadedByPath = Join-Path $Paths.repo_root $LoadedBy
    $resolved = Resolve-RepoLuaRequire -RepoRoot $Paths.repo_root -FilePath $loadedByPath -RequireName $RequireRecord.require -SourceMods $SourceMods
    if (-not $resolved.exists -or $resolved.is_external) {
        return $null
    }

    $relativePath = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $resolved.path
    $exports = Get-LuaExportNames -FilePath $resolved.path
    $storageRoots = Get-LuaStorageRoots -FilePath $resolved.path
    $guiIds = Get-LuaGuiIds -FilePath $resolved.path
    $remoteInterfaces = Get-LuaRemoteInterfaces -FilePath $resolved.path
    $rebuildOn = Get-LuaRebuildHints -FilePath $resolved.path -LoadedBy $LoadedBy
    $cadence = Get-LuaCadenceHint -RelativePath $relativePath -Exports $exports -LoadedBy $LoadedBy
    $owns = if ($LoadedBy -like '*control.lua') { 'runtime module: ' + ([System.IO.Path]::GetFileNameWithoutExtension($relativePath)) } else { 'data-stage prototype aggregation for ' + ([System.IO.Path]::GetFileNameWithoutExtension($relativePath)) }

    $override = (Get-EsirRuntimeOverrideMap)[$relativePath]
    if ($override) {
        if ($override.ContainsKey('owns')) { $owns = $override.owns }
        if ($override.ContainsKey('cadence')) { $cadence = $override.cadence }
        if ($override.ContainsKey('events')) { $exports = @($override.events) }
        if ($override.ContainsKey('storage_roots')) { $storageRoots = @($override.storage_roots) }
        if ($override.ContainsKey('gui_ids')) { $guiIds = @($override.gui_ids) }
        if ($override.ContainsKey('remote_interfaces')) { $remoteInterfaces = @($override.remote_interfaces) }
        if ($override.ContainsKey('rebuild_on')) { $rebuildOn = @($override.rebuild_on) }
    }

    return [ordered]@{
        id                = if ($RequireRecord.PSObject.Properties.Name -contains 'id') { $RequireRecord.id } else { [System.IO.Path]::GetFileNameWithoutExtension($relativePath) }
        path              = $relativePath
        loaded_by         = $LoadedBy
        owns              = $owns
        cadence           = $cadence
        events            = @($exports)
        storage_roots     = @($storageRoots)
        gui_ids           = @($guiIds)
        remote_interfaces = @($remoteInterfaces)
        rebuild_on        = @($rebuildOn)
    }
}

function Get-EsirRuntimeManifestData {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $controlRelativePath = 'exotic-space-industries-remembrance\control.lua'
    $controlPath = Join-Path $Paths.repo_root $controlRelativePath
    $entries = foreach ($record in (Get-DirectAssignedRequires -FilePath $controlPath)) {
        New-EsirRuntimeEntry -Paths $Paths -SourceMods $context.source_mods -LoadedBy $controlRelativePath -RequireRecord $record
    }

    return [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date).ToString('o')
        repo_root      = $Paths.repo_root
        entries        = @($entries | Where-Object { $_ } | Sort-Object path)
    }
}

function Get-EsirPrototypeIndexData {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $dataRelativePath = 'exotic-space-industries-remembrance\data.lua'
    $dataPath = Join-Path $Paths.repo_root $dataRelativePath
    $directEntries = @()

    foreach ($record in (Get-DirectBareRequires -FilePath $dataPath)) {
        $resolved = Resolve-RepoLuaRequire -RepoRoot $Paths.repo_root -FilePath $dataPath -RequireName $record.require -SourceMods $context.source_mods
        if (-not $resolved.exists -or $resolved.is_external) {
            continue
        }

        $relativePath = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $resolved.path
        $nested = @()
        foreach ($nestedRecord in (Get-DirectBareRequires -FilePath $resolved.path)) {
            $nestedResolved = Resolve-RepoLuaRequire -RepoRoot $Paths.repo_root -FilePath $resolved.path -RequireName $nestedRecord.require -SourceMods $context.source_mods
            if ($nestedResolved.exists -and (-not $nestedResolved.is_external)) {
                $nested += (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $nestedResolved.path)
            }
        }

        $directEntries += [ordered]@{
            id        = [System.IO.Path]::GetFileNameWithoutExtension($relativePath)
            path      = $relativePath
            loaded_by = $dataRelativePath
            children  = @($nested | Sort-Object -Unique)
        }
    }

    $prototypeFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $Paths.repo_root 'exotic-space-industries-remembrance\prototypes') -Recurse -File -Filter '*.lua' |
            ForEach-Object { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.FullName } |
            Sort-Object
    )

    return [ordered]@{
        schema_version  = 1
        generated_at    = (Get-Date).ToString('o')
        repo_root       = $Paths.repo_root
        direct_requires = @($directEntries | Sort-Object path)
        prototype_files = @($prototypeFiles)
    }
}

function Get-EsirPackManifestData {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $deployScripts = @{
        'exotic-space-industries-remembrance'              = 'process.ps1'
        'exotic-space-industries-remembrance-graphics-1'   = 'graphics1_process.ps1'
        'exotic-space-industries-remembrance-graphics-2'   = 'graphics2_process.ps1'
        'exotic-space-industries-remembrance-graphics-3'   = 'graphics3_process.ps1'
        'exotic-space-industries-remembrance-graphics-4'   = 'graphics4_process.ps1'
        'exotic-space-industries-remembrance-graphics-5'   = 'graphics5_process.ps1'
        'exotic-space-industries-remembrance-soundtrack-1' = 'soundtrack1_process.ps1'
        'exotic-space-industries-remembrance-soundtrack-2' = 'soundtrack2_process.ps1'
    }

    $entries = foreach ($mod in $context.source_mods | Sort-Object folder_name) {
        $type = if ($mod.folder_name -match 'graphics') { 'graphics-pack' } elseif ($mod.folder_name -match 'soundtrack') { 'soundtrack-pack' } else { 'gameplay-pack' }
        $role = switch ($type) {
            'graphics-pack' { 'graphics companion assets' }
            'soundtrack-pack' { 'music and ambient audio companion assets' }
            default { 'primary gameplay and runtime pack' }
        }
        if ($mod.folder_name -in @('exotic-space-industries-remembrance-graphics-4', 'exotic-space-industries-remembrance-graphics-5')) {
            $role = 'graphics and sound-effect companion assets'
        }

        [ordered]@{
            id            = $mod.name
            folder        = $mod.folder_name
            type          = $type
            info_json     = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $mod.info_path
            deploy_script = $deployScripts[$mod.folder_name]
            role          = $role
        }
    }

    return [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date).ToString('o')
        entries        = @($entries)
    }
}

function Get-EsirSaveCatalogData {
    param([Parameter(Mandatory = $true)]$Paths)

    $existing = Read-EsirJson -Path $Paths.save_catalog_path
    $entries = [System.Collections.Generic.List[object]]::new()
    $defaultSavePath = Join-Path $Paths.repo_root '.factorio-qc\fueler-smoke.zip'
    $entries.Add([ordered]@{
        id            = 'fueler-smoke'
        path          = '.factorio-qc\fueler-smoke.zip'
        kind          = 'smoke-save'
        purpose       = 'Fueler runtime and preview smoke coverage'
        tags          = @('runtime', 'preview', 'smoke', 'fueler')
        preferred_for = @('qc-runtime', 'qc-preview')
        helper_mods   = @()
        mods_source   = 'live-repo-via-qc-sync'
        notes         = if (Test-Path -LiteralPath $defaultSavePath) { 'Primary smoke save shipped in ignored QC artifact space.' } else { 'Expected smoke save location; add the save artifact when available.' }
    }) | Out-Null

    foreach ($entry in (ConvertTo-EsirArray $(if ($existing) { $existing.entries } else { $null }))) {
        if ($entry.id -eq 'fueler-smoke') { continue }
        $entries.Add([ordered]@{
            id            = $entry.id
            path          = $entry.path
            kind          = $entry.kind
            purpose       = $entry.purpose
            tags          = @($entry.tags)
            preferred_for = @($entry.preferred_for)
            helper_mods   = @($entry.helper_mods)
            mods_source   = $entry.mods_source
            notes         = $entry.notes
        }) | Out-Null
    }

    return [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date).ToString('o')
        entries        = @($entries | Sort-Object id)
    }
}

function Get-EsirToolManifestData {
    param([Parameter(Mandatory = $true)]$Paths)

    return [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date).ToString('o')
        wrapper        = [ordered]@{
            path    = 'scripts\invoke-esir-dev.ps1'
            library = 'scripts\esir-dev-lib.ps1'
            tasks   = @('doctor', 'manifest-refresh', 'dependency-refresh', 'dependency-query', 'dependency-diff', 'preflight', 'qc-fast', 'qc-runtime', 'runtime-benchmark', 'qc-preview', 'qc-gaia-resources', 'qc-assets', 'qc-package', 'qc-full', 'portal-scout', 'diff', 'art-start', 'art-collect', 'art-review', 'art-validate', 'pack-dryrun', 'pack-deploy', 'full')
        }
        dependency_wrapper = [ordered]@{
            path    = 'scripts\invoke-esir-dependency-intel.ps1'
            library = 'scripts\esir-dependency-lib.ps1'
            tasks   = @('refresh', 'query', 'diff')
        }
        factorio_lua_docs_wrapper = [ordered]@{
            path    = 'scripts\invoke-factorio-lua-docs.ps1'
            library = 'scripts\factorio-lua-docs-lib.ps1'
            tasks   = @('refresh', 'query')
        }
        engines        = @(
            [ordered]@{
                name      = 'factorio-mod-qc'
                root_kind = 'global-skill'
                root      = 'factorio-mod-qc'
                wrapper   = 'scripts\invoke-factorio-qc.ps1'
                available = (Test-Path -LiteralPath $Paths.factorio_invoke_script)
            },
            [ordered]@{
                name      = 'chatgpt-firefox-companion'
                root_kind = 'global-skill'
                root      = 'chatgpt-firefox-companion'
                wrapper   = 'scripts\invoke-chatgpt-firefox-companion.ps1'
                available = (Test-Path -LiteralPath $Paths.firefox_invoke_script)
            }
        )
        repo_skills    = @(
            Get-ChildItem -LiteralPath (Join-Path $Paths.repo_root '.codex\skills') -Directory |
                Sort-Object Name |
                ForEach-Object {
                    $wrapper = switch ($_.Name) {
                        'esir-dev' { 'scripts\invoke-esir-dev.ps1' }
                        'esir-dependency-intel' { 'scripts\invoke-esir-dependency-intel.ps1' }
                        'factorio-lua-docs' { 'scripts\invoke-factorio-lua-docs.ps1' }
                        default { $null }
                    }
                    [ordered]@{
                        name    = $_.Name
                        root    = ".codex\skills\$($_.Name)"
                        wrapper = $wrapper
                    }
                }
        )
        manifests      = @(
            '.codex\esir\runtime-modules.json',
            '.codex\esir\prototype-index.json',
            '.codex\esir\pack-manifest.json',
            '.codex\esir\save-catalog.json',
            '.codex\esir\tool-manifest.json',
            '.codex\esir\portal-shortlist.json',
            '.codex\esir\asset-import-plan.json',
            '.codex\esir\dependency-catalog.json'
        )
        legacy_scripts = @('process.ps1', 'graphics1_process.ps1', 'graphics2_process.ps1', 'graphics3_process.ps1', 'graphics4_process.ps1', 'graphics5_process.ps1', 'soundtrack1_process.ps1', 'soundtrack2_process.ps1')
        artifacts      = @('.factorio-qc', 'output')
        global_shim    = [ordered]@{
            root_kind = 'global-skill'
            root      = 'esir-dev'
            available = (Test-Path -LiteralPath $Paths.global_shim_root)
        }
    }
}

function Initialize-EsirStableFiles {
    param([Parameter(Mandatory = $true)]$Paths)

    if (-not (Test-Path -LiteralPath $Paths.portal_shortlist_path)) {
        Write-EsirJson -Path $Paths.portal_shortlist_path -Data ([ordered]@{ schema_version = 1; generated_at = $null; entries = @() })
    }
    if (-not (Test-Path -LiteralPath $Paths.asset_import_plan_path)) {
        Write-EsirJson -Path $Paths.asset_import_plan_path -Data ([ordered]@{ schema_version = 1; generated_at = (Get-Date).ToString('o'); entries = @() })
    }
}

function Invoke-EsirManifestRefresh {
    param([Parameter(Mandatory = $true)]$Paths)

    Write-EsirJson -Path $Paths.runtime_manifest_path -Data (Get-EsirRuntimeManifestData -Paths $Paths)
    Write-EsirJson -Path $Paths.prototype_index_path -Data (Get-EsirPrototypeIndexData -Paths $Paths)
    Write-EsirJson -Path $Paths.pack_manifest_path -Data (Get-EsirPackManifestData -Paths $Paths)
    Write-EsirJson -Path $Paths.save_catalog_path -Data (Get-EsirSaveCatalogData -Paths $Paths)
    if (Get-Command -Name Get-EsirDependencyCatalogData -ErrorAction SilentlyContinue) {
        Write-EsirJson -Path $Paths.dependency_catalog_path -Data (Get-EsirDependencyCatalogData -Paths $Paths)
    }
    Write-EsirJson -Path $Paths.tool_manifest_path -Data (Get-EsirToolManifestData -Paths $Paths)
    Initialize-EsirStableFiles -Paths $Paths

    return [ordered]@{
        task           = 'manifest-refresh'
        overall_status = 'ok'
        manifests      = @(
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.runtime_manifest_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.prototype_index_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.pack_manifest_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.save_catalog_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.dependency_catalog_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.tool_manifest_path)
            (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.portal_shortlist_path)
            Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.asset_import_plan_path
        )
    }
}

function Resolve-EsirSaveSelection {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$TaskName,
        [string]$SaveId,
        [string]$SavePath
    )

    $catalog = Read-EsirJson -Path $Paths.save_catalog_path
    $entries = @($catalog.entries)

    if ($SaveId) {
        $selected = $entries | Where-Object { $_.id -eq $SaveId } | Select-Object -First 1
        if (-not $selected) {
            throw "Save id not found in catalog: $SaveId"
        }
        return [ordered]@{ id = $selected.id; path = Join-Path $Paths.repo_root $selected.path; reason = 'catalog-id'; entry = $selected }
    }

    if ($SavePath) {
        return [ordered]@{ id = $null; path = (Resolve-EsirUserPath -Paths $Paths -Path $SavePath); reason = 'explicit-save-path'; entry = $null }
    }

    $preferred = $entries | Where-Object { @($_.preferred_for) -contains $TaskName } | Select-Object -First 1
    if ($preferred) {
        return [ordered]@{ id = $preferred.id; path = Join-Path $Paths.repo_root $preferred.path; reason = 'catalog-default'; entry = $preferred }
    }

    return $null
}

function Get-EsirSaveHelperRequirements {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        $SaveSelection,
        [string]$TaskName,
        [switch]$AllowAutoStage
    )

    $entry = if ($SaveSelection) { $SaveSelection.entry } else { $null }
    $requirements = [System.Collections.Generic.List[object]]::new()

    foreach ($helper in (ConvertTo-EsirArray $(if ($entry) { $entry.helper_mods } else { $null }))) {
        $assetPath = if ($helper.asset_path) { [string]$helper.asset_path } else { $null }
        $assetFullPath = if ($assetPath) { Join-Path $Paths.repo_root $assetPath } else { $null }
        $autoStageFor = @($helper.auto_stage_for)
        $willAutoStage = $AllowAutoStage.IsPresent -and $TaskName -and ($autoStageFor -contains $TaskName)

        $requirements.Add([ordered]@{
            name            = if ($helper.name) { [string]$helper.name } else { $null }
            asset_path      = $assetPath
            asset_exists    = $assetFullPath -and (Test-Path -LiteralPath $assetFullPath)
            auto_stage_for  = $autoStageFor
            will_auto_stage = $willAutoStage
            stage_mode      = if ($willAutoStage) { 'auto' } else { 'manual-or-prestaged' }
            notes           = if ($helper.notes) { [string]$helper.notes } else { $null }
        }) | Out-Null
    }

    return @($requirements)
}

function Get-EsirSaveHelperSummary {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        $SaveSelection,
        [string]$TaskName,
        [switch]$AllowAutoStage
    )

    if (-not $SaveSelection) {
        return $null
    }

    $requirements = @(Get-EsirSaveHelperRequirements -Paths $Paths -SaveSelection $SaveSelection -TaskName $TaskName -AllowAutoStage:$AllowAutoStage)
    if ($requirements.Count -eq 0) {
        return $null
    }

    $warnings = [System.Collections.Generic.List[string]]::new()
    foreach ($helper in $requirements) {
        if (-not $helper.asset_exists) {
            $warnings.Add("Save '$($SaveSelection.id)' declares helper mod '$($helper.name)', but the asset path is missing: $($helper.asset_path)") | Out-Null
        } elseif (-not $helper.will_auto_stage) {
            $warnings.Add("Save '$($SaveSelection.id)' depends on helper mod '$($helper.name)'; task '$TaskName' still requires manual or pre-staged helper sync.") | Out-Null
        }
    }

    return [ordered]@{
        save_id                 = $SaveSelection.id
        task                    = $TaskName
        automatic_staging       = $AllowAutoStage.IsPresent
        manual_staging_required = @($requirements | Where-Object { $_.stage_mode -ne 'auto' }).Count -gt 0
        items                   = $requirements
        warnings                = @($warnings)
    }
}

function Set-EsirModListEntryEnabled {
    param(
        [Parameter(Mandatory = $true)][string]$ModListPath,
        [Parameter(Mandatory = $true)][string]$ModName
    )

    $modList = if (Test-Path -LiteralPath $ModListPath) {
        Get-Content -LiteralPath $ModListPath -Raw | ConvertFrom-Json
    } else {
        [pscustomobject]@{ mods = @() }
    }

    $mods = [System.Collections.Generic.List[object]]::new()
    $found = $false
    foreach ($mod in (ConvertTo-EsirArray $modList.mods)) {
        if ([string]$mod.name -eq $ModName) {
            $mods.Add([ordered]@{ name = $ModName; enabled = $true }) | Out-Null
            $found = $true
        } else {
            $mods.Add([ordered]@{
                name    = [string]$mod.name
                enabled = $mod.enabled -eq $true
            }) | Out-Null
        }
    }

    if (-not $found) {
        $mods.Add([ordered]@{ name = $ModName; enabled = $true }) | Out-Null
    }

    $sortedMods = @($mods | Sort-Object name)
    Write-EsirJson -Path $ModListPath -Data ([ordered]@{ mods = $sortedMods })
}

function Sync-EsirSaveHelperMods {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$RunMods,
        $HelperSummary,
        $Result
    )

    if (-not $HelperSummary -or @($HelperSummary.items).Count -eq 0) {
        return $HelperSummary
    }

    $warnings = [System.Collections.Generic.List[string]]::new()
    foreach ($warning in (ConvertTo-EsirArray $HelperSummary.warnings)) {
        $warnings.Add([string]$warning) | Out-Null
    }

    $modListPath = Join-Path $RunMods 'mod-list.json'
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($helper in @($HelperSummary.items)) {
        $entry = [ordered]@{
            name            = $helper.name
            asset_path      = $helper.asset_path
            asset_exists    = $helper.asset_exists
            auto_stage_for  = @($helper.auto_stage_for)
            will_auto_stage = $helper.will_auto_stage
            stage_mode      = $helper.stage_mode
            notes           = $helper.notes
            stage_status    = 'not-requested'
        }

        if ($helper.will_auto_stage -ne $true) {
            $items.Add($entry) | Out-Null
            continue
        }

        if (-not $helper.asset_exists) {
            $entry.stage_status = 'missing-asset'
            $warnings.Add("Helper auto-staging skipped for '$($helper.name)' because the asset path was not found: $($helper.asset_path)") | Out-Null
            if ($Result -and (Get-Command -Name Add-FactorioQCWarning -ErrorAction SilentlyContinue)) {
                Add-FactorioQCWarning -Result $Result -Message "Helper auto-staging skipped for '$($helper.name)' because the asset path was not found: $($helper.asset_path)"
            }
            $items.Add($entry) | Out-Null
            continue
        }

        $source = Join-Path $Paths.repo_root $helper.asset_path
        $destination = Join-Path $RunMods ([System.IO.Path]::GetFileName($source))
        Copy-DirectoryTreeRobust -Source $source -Destination $destination
        if ($helper.name) {
            Set-EsirModListEntryEnabled -ModListPath $modListPath -ModName ([string]$helper.name)
        }

        $entry.stage_status = 'staged'
        $entry.destination = $destination
        if ($Result -and (Get-Command -Name Add-FactorioQCNote -ErrorAction SilentlyContinue)) {
            Add-FactorioQCNote -Result $Result -Message "Auto-staged helper mod for save '$($HelperSummary.save_id)': $($helper.name)"
        }
        $items.Add($entry) | Out-Null
    }

    $HelperSummary.items = @($items)
    $HelperSummary.warnings = @($warnings)
    $HelperSummary.manual_staging_required = @($items | Where-Object { $_.stage_mode -ne 'auto' }).Count -gt 0
    return $HelperSummary
}

function Invoke-EsirQcMode {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$Mode,
        [string]$SaveId,
        [string]$SavePath,
        [Nullable[int]]$Seed,
        [string]$Planet,
        [string]$FactorioPath,
        [switch]$Strict,
        [switch]$FixEncoding
    )

    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath -EnsureArtifactRoot
    $encodingPass = Invoke-EsirEncodingPass -Paths $Paths -Fix:$FixEncoding
    $saveSelection = $null
    if ($Mode -in @('runtime', 'preview', 'full')) {
        $preferredTask = if ($Mode -eq 'preview') { 'qc-preview' } else { 'qc-runtime' }
        $saveSelection = Resolve-EsirSaveSelection -Paths $Paths -TaskName $preferredTask -SaveId $SaveId -SavePath $SavePath
    }
    $helperRequirements = Get-EsirSaveHelperSummary -Paths $Paths -SaveSelection $saveSelection -TaskName ('qc-' + $Mode) -AllowAutoStage:$false

    $arguments = @('-ExecutionPolicy', 'Bypass', '-File', $Paths.factorio_invoke_script, '-Mode', $Mode, '-RepoRoot', $Paths.repo_root)
    if ($saveSelection -and $saveSelection.path) { $arguments += @('-Save', $saveSelection.path) }
    if ($null -ne $Seed) { $arguments += @('-Seed', [string]$Seed) }
    if ($Planet) { $arguments += @('-Planet', $Planet) }
    if ($FactorioPath) { $arguments += @('-FactorioPath', $FactorioPath) }
    if ($Strict) { $arguments += '-Strict' }

    & powershell @arguments | Out-Null
    $exitCode = $LASTEXITCODE
    $summaryPath = Join-Path $context.artifact_root 'latest-summary.json'
    $summary = Read-EsirJson -Path $summaryPath
    $delegateStatus = if ($summary) { $summary.overall_status } elseif ($exitCode -eq 0) { 'ok' } else { 'failed' }
    $overallStatus = Get-EsirOverallStatus -Checks @(
        [ordered]@{ status = $encodingPass.overall_status }
        [ordered]@{ status = $delegateStatus }
    ) -Strict:$Strict

    return [ordered]@{
        task           = 'qc-' + $Mode
        overall_status = $overallStatus
        exit_code      = $exitCode
        summary_path   = if (Test-Path -LiteralPath $summaryPath) { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $summaryPath } else { $null }
        save_selection = $saveSelection
        helper_requirements = $helperRequirements
        encoding       = $encodingPass
        summary        = $summary
    }
}

function Invoke-EsirGaiaResourceQc {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [uint32[]]$Seeds,
        [Nullable[int]]$PreviewSize,
        [string]$FactorioPath
    )

    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath -EnsureArtifactRoot
    if (-not $context.factorio_exe) {
        throw 'Factorio executable not found for Gaia resource QC.'
    }

    $presetPath = Join-Path $Paths.repo_root '.codex\skills\esir-dev\assets\gaia-resource-qc.json'
    $preset = Read-EsirJson -Path $presetPath
    if (-not $preset) {
        throw "Gaia resource QC preset not found or invalid: $presetPath"
    }

    $effectiveSeeds = @(
        if ($Seeds -and $Seeds.Count -gt 0) {
            $Seeds | ForEach-Object { [uint32]$_ }
        } else {
            $preset.seeds | ForEach-Object { [uint32]$_ }
        }
    )
    $effectivePreviewSize = if ($null -ne $PreviewSize) { [int]$PreviewSize } else { [int]$preset.preview_size }
    if ($effectivePreviewSize -lt 256 -or $effectivePreviewSize -gt 8192) {
        throw "Gaia resource QC preview size must be between 256 and 8192; got $effectivePreviewSize."
    }

    $planet = [string]$preset.planet
    $targets = @($preset.resources | ForEach-Object { [string]$_ })
    if (-not $planet -or $targets.Count -eq 0 -or $effectiveSeeds.Count -eq 0) {
        throw "Gaia resource QC preset is missing its planet, resources, or seed matrix: $presetPath"
    }

    $minimumEntityCount = [int]$preset.minimum_entity_count
    $syncResult = New-FactorioQCResult -Name 'gaia-resources'
    $runMods = Sync-FactorioRunMods -Context $context -Result $syncResult
    $targetAlternation = @($targets | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $runs = @()
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($seedValue in $effectiveSeeds) {
        $seedText = [string]$seedValue
        $config = New-FactorioWriteDataConfig -Context $context -Label "gaia-resource-$seedText"
        $previewPath = Join-Path $context.artifact_root ("gaia-resource-{0}-{1}.png" -f $seedText, $effectivePreviewSize)
        $stdoutPath = Join-Path $config.write_data_dir 'factorio-gaia-resource-stdout.txt'
        $failureCountBeforeRun = $failures.Count

        $process = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @(
            '--mod-directory', $runMods,
            '--config', $config.config_path,
            '--disable-audio',
            '--generate-map-preview', $previewPath,
            '--map-preview-size', [string]$effectivePreviewSize,
            '--map-preview-planet', $planet,
            '--map-gen-seed', $seedText,
            '--report-quantities', ($targets -join ',')
        ) -OutputPath $stdoutPath

        if ($process.exit_code -ne 0) {
            $failures.Add("seed ${seedText}: Factorio exited with code $($process.exit_code)") | Out-Null
        }

        $quantityByName = @{}
        foreach ($line in $process.output) {
            if ([string]$line -match "(?<name>$targetAlternation): totalEntityCount=(?<count>\d+), totalRichness=(?<richness>\d+)") {
                $quantityByName[$Matches.name] = [ordered]@{
                    entity_count = [uint64]$Matches.count
                    richness = [uint64]$Matches.richness
                }
            }
        }

        $resourceRows = @()
        foreach ($target in $targets) {
            $measurement = $quantityByName[$target]
            $entityCount = if ($measurement) { [uint64]$measurement.entity_count } else { $null }
            $richness = if ($measurement) { [uint64]$measurement.richness } else { $null }
            $present = $measurement -and $entityCount -ge $minimumEntityCount
            if (-not $present) {
                $observed = if ($null -eq $entityCount) { 'missing report' } else { "$entityCount entities" }
                $failures.Add("seed ${seedText}: $target reported $observed") | Out-Null
            }

            $resourceRows += [ordered]@{
                name = $target
                entity_count = $entityCount
                richness = $richness
                present = [bool]$present
            }
        }

        $runs += [ordered]@{
            seed = $seedValue
            status = if ($failures.Count -eq $failureCountBeforeRun) { 'ok' } else { 'failed' }
            resources = $resourceRows
            preview = if (Test-Path -LiteralPath $previewPath) { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $previewPath } else { $null }
            stdout = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $stdoutPath
            config = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $config.config_path
        }
    }

    $controlProbeRuns = @()
    if ($preset.control_probe) {
        $probeSeed = [uint32]$preset.control_probe.seed
        $probeSeedText = [string]$probeSeed
        $probePreviewSize = [int]$preset.control_probe.preview_size
        $disabledResources = @($preset.control_probe.disabled_resources | ForEach-Object { [string]$_ })

        foreach ($disabledResource in $disabledResources) {
            if ($disabledResource -notin $targets) {
                throw "Gaia resource QC control probe names an unknown resource: $disabledResource"
            }

            $controls = [ordered]@{}
            $controls[$disabledResource] = [ordered]@{frequency = 0; size = 0; richness = 0}
            $mapGenSettings = [ordered]@{autoplace_controls = $controls}
            $mapGenSettingsPath = Join-Path $context.artifact_root ("gaia-resource-control-{0}.json" -f $disabledResource)
            Write-FactorioQCTextFile -Path $mapGenSettingsPath -Value ($mapGenSettings | ConvertTo-Json -Depth 5)

            $config = New-FactorioWriteDataConfig -Context $context -Label ("gaia-control-{0}" -f $disabledResource)
            $previewPath = Join-Path $context.artifact_root ("gaia-control-{0}-{1}-{2}.png" -f $disabledResource, $probeSeedText, $probePreviewSize)
            $stdoutPath = Join-Path $config.write_data_dir 'factorio-gaia-control-stdout.txt'
            $failureCountBeforeRun = $failures.Count
            $process = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @(
                '--mod-directory', $runMods,
                '--config', $config.config_path,
                '--disable-audio',
                '--generate-map-preview', $previewPath,
                '--map-preview-size', [string]$probePreviewSize,
                '--map-preview-planet', $planet,
                '--map-gen-seed', $probeSeedText,
                '--map-gen-settings', $mapGenSettingsPath,
                '--report-quantities', ($targets -join ',')
            ) -OutputPath $stdoutPath

            if ($process.exit_code -ne 0) {
                $failures.Add("control probe ${disabledResource}: Factorio exited with code $($process.exit_code)") | Out-Null
            }

            $quantityByName = @{}
            foreach ($line in $process.output) {
                if ([string]$line -match "(?<name>$targetAlternation): totalEntityCount=(?<count>\d+), totalRichness=(?<richness>\d+)") {
                    $quantityByName[$Matches.name] = [ordered]@{
                        entity_count = [uint64]$Matches.count
                        richness = [uint64]$Matches.richness
                    }
                }
            }

            $resourceRows = @()
            foreach ($target in $targets) {
                $measurement = $quantityByName[$target]
                $entityCount = if ($measurement) { [uint64]$measurement.entity_count } else { $null }
                $richness = if ($measurement) { [uint64]$measurement.richness } else { $null }
                $isDisabledTarget = $target -eq $disabledResource
                $passed = if ($isDisabledTarget) {
                    $measurement -and $entityCount -eq 0
                } else {
                    $measurement -and $entityCount -ge $minimumEntityCount
                }

                if (-not $passed) {
                    $expected = if ($isDisabledTarget) { '0 entities' } else { "at least $minimumEntityCount entity" }
                    $observed = if ($null -eq $entityCount) { 'missing report' } else { "$entityCount entities" }
                    $failures.Add("control probe ${disabledResource}: $target expected $expected, observed $observed") | Out-Null
                }

                $resourceRows += [ordered]@{
                    name = $target
                    entity_count = $entityCount
                    richness = $richness
                    expected = if ($isDisabledTarget) { 'disabled' } else { 'present' }
                    passed = [bool]$passed
                }
            }

            $controlProbeRuns += [ordered]@{
                disabled_resource = $disabledResource
                seed = $probeSeed
                preview_size = $probePreviewSize
                status = if ($failures.Count -eq $failureCountBeforeRun) { 'ok' } else { 'failed' }
                resources = $resourceRows
                map_gen_settings = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $mapGenSettingsPath
                preview = if (Test-Path -LiteralPath $previewPath) { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $previewPath } else { $null }
                stdout = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $stdoutPath
            }
        }
    }

    return [ordered]@{
        task = 'qc-gaia-resources'
        overall_status = if ($failures.Count -eq 0) { 'ok' } else { 'failed' }
        preset = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $presetPath
        planet = $planet
        preview_size = $effectivePreviewSize
        minimum_entity_count = $minimumEntityCount
        seeds = $effectiveSeeds
        resources = $targets
        run_mod_directory = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $runMods
        runs = $runs
        control_probes = $controlProbeRuns
        failures = @($failures)
    }
}

function Get-EsirNumericStats {
    param([double[]]$Values)

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    $sorted = @($Values | Sort-Object)
    $count = $sorted.Count
    $sum = 0.0
    foreach ($value in $sorted) {
        $sum += [double]$value
    }

    $mean = $sum / $count
    if (($count % 2) -eq 1) {
        $median = $sorted[[int]($count / 2)]
    } else {
        $median = ($sorted[($count / 2) - 1] + $sorted[$count / 2]) / 2.0
    }

    $p95Index = [int]([Math]::Ceiling($count * 0.95) - 1)
    if ($p95Index -lt 0) { $p95Index = 0 }
    if ($p95Index -ge $count) { $p95Index = $count - 1 }

    $variance = 0.0
    foreach ($value in $sorted) {
        $delta = [double]$value - $mean
        $variance += $delta * $delta
    }
    $variance = $variance / $count

    return [ordered]@{
        count  = $count
        min    = [Math]::Round($sorted[0], 6)
        median = [Math]::Round($median, 6)
        mean   = [Math]::Round($mean, 6)
        p95    = [Math]::Round($sorted[$p95Index], 6)
        max    = [Math]::Round($sorted[$count - 1], 6)
        stddev = [Math]::Round([Math]::Sqrt($variance), 6)
    }
}

function Parse-EsirFactorioBenchmarkRuns {
    param([Parameter(Mandatory = $true)][string]$StdoutPath)

    if (-not (Test-Path -LiteralPath $StdoutPath)) {
        return @()
    }

    $runs = [System.Collections.Generic.List[object]]::new()
    $current = $null

    foreach ($line in Get-Content -LiteralPath $StdoutPath) {
        if ($line -match 'Performed (?<ticks>\d+) updates in (?<total_ms>[0-9.]+) ms') {
            $current = [ordered]@{
                run_index = $runs.Count + 1
            }
            $current.ticks = [int]$matches.ticks
            $current.total_ms = [double]$matches.total_ms
            continue
        }

        if (-not $current) {
            continue
        }

        if ($line -match 'avg:\s+(?<avg_ms>[0-9.]+) ms,\s+min:\s+(?<min_ms>[0-9.]+) ms,\s+max:\s+(?<max_ms>[0-9.]+) ms') {
            $current.avg_ms = [double]$matches.avg_ms
            $current.min_ms = [double]$matches.min_ms
            $current.max_ms = [double]$matches.max_ms
            $runs.Add([pscustomobject]$current) | Out-Null
            $current = $null
            continue
        }
    }

    return @($runs)
}

function Get-EsirWarningClassSummary {
    param([string[]]$Warnings)

    $warnings = @($Warnings | Where-Object { $_ })
    if ($warnings.Count -eq 0) {
        return @()
    }

    return @(
        $warnings |
            Group-Object |
            Sort-Object Count -Descending |
            ForEach-Object {
                [ordered]@{
                    message = $_.Name
                    count   = $_.Count
                }
            }
    )
}

function Get-EsirRuntimeTelemetrySummary {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$WriteDataDir
    )

    $telemetryPath = Join-Path $WriteDataDir 'script-output\ei-runtime-scheduler.jsonl'
    if (-not (Test-Path -LiteralPath $telemetryPath)) {
        $telemetryPath = Join-Path $WriteDataDir 'ei-runtime-scheduler.jsonl'
    }

    if (-not (Test-Path -LiteralPath $telemetryPath)) {
        return [ordered]@{
            found = $false
        }
    }

    $lines = Get-Content -LiteralPath $telemetryPath
    return [ordered]@{
        found       = $true
        path        = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $telemetryPath
        line_count  = @($lines).Count
        last_record = if (@($lines).Count -gt 0) { $lines[-1] } else { $null }
    }
}

function Invoke-EsirRuntimeBenchmark {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SaveId,
        [string]$SavePath,
        [Nullable[int]]$WarmupRuns,
        [Nullable[int]]$BenchmarkRuns,
        [Nullable[int]]$BenchmarkTicks,
        [string]$FactorioPath,
        [switch]$Strict,
        [switch]$FixEncoding
    )

    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath -EnsureArtifactRoot
    $encodingPass = Invoke-EsirEncodingPass -Paths $Paths -Fix:$FixEncoding
    $saveSelection = Resolve-EsirSaveSelection -Paths $Paths -TaskName 'qc-runtime' -SaveId $SaveId -SavePath $SavePath

    Import-EsirFactorioQc -Paths $Paths

    $result = New-FactorioQCResult -Name 'runtime-benchmark'
    $runMods = Sync-FactorioRunMods -Context $context -Result $result
    $smokeSave = if ($saveSelection -and $saveSelection.path) { $saveSelection.path } else { Find-SmokeSave -Context $context -Save $SavePath }
    $helperRequirements = Get-EsirSaveHelperSummary -Paths $Paths -SaveSelection $saveSelection -TaskName 'runtime-benchmark' -AllowAutoStage
    $helperRequirements = Sync-EsirSaveHelperMods -Paths $Paths -RunMods $runMods -HelperSummary $helperRequirements -Result $result
    if (-not $smokeSave) {
        return [ordered]@{
            task           = 'runtime-benchmark'
            overall_status = 'skipped'
            reason         = 'No smoke save was found for runtime benchmark mode.'
            encoding       = $encodingPass
            save_selection = $saveSelection
            helper_requirements = $helperRequirements
        }
    }

    $effectiveWarmupRuns = if ($null -ne $WarmupRuns) { [Math]::Max(0, [int]$WarmupRuns) } else { 1 }
    $effectiveBenchmarkRuns = if ($null -ne $BenchmarkRuns) { [Math]::Max(1, [int]$BenchmarkRuns) } else { 5 }
    $effectiveBenchmarkTicks = if ($null -ne $BenchmarkTicks) { [Math]::Max(1, [int]$BenchmarkTicks) } else { 3600 }
    $totalRuns = $effectiveWarmupRuns + $effectiveBenchmarkRuns

    $controlReview = Get-ControlReview -Context $context
    $config = New-FactorioWriteDataConfig -Context $context -Label 'runtime-benchmark'
    $stdoutPath = Join-Path $config.write_data_dir 'factorio-benchmark-stdout.txt'
    $process = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments @(
        '--mod-directory', $runMods,
        '--config', $config.config_path,
        '--disable-audio',
        '--benchmark', $smokeSave,
        '--benchmark-ticks', [string]$effectiveBenchmarkTicks,
        '--benchmark-runs', [string]$totalRuns
    ) -OutputPath $stdoutPath

    $logPath = Join-Path $config.write_data_dir 'factorio-current.log'
    $classification = Get-ClassifiedFactorioLog -LogPath $logPath -OutputLines $process.output

    $allRuns = @(Parse-EsirFactorioBenchmarkRuns -StdoutPath $stdoutPath)
    $measuredRuns = if ($allRuns.Count -gt $effectiveWarmupRuns) { @($allRuns | Select-Object -Skip $effectiveWarmupRuns) } else { @() }
    $measuredRunCount = @($measuredRuns).Count

    $avgMsStats = Get-EsirNumericStats -Values @($measuredRuns | ForEach-Object { [double]$_.avg_ms })
    $totalMsStats = Get-EsirNumericStats -Values @($measuredRuns | ForEach-Object { [double]$_.total_ms })
    $runMaxStats = Get-EsirNumericStats -Values @($measuredRuns | ForEach-Object { [double]$_.max_ms })
    $warningClasses = Get-EsirWarningClassSummary -Warnings $classification.needs_review
    $telemetry = Get-EsirRuntimeTelemetrySummary -Paths $Paths -WriteDataDir $config.write_data_dir

    $scenarioName = if ($saveSelection -and $saveSelection.id) { $saveSelection.id } else { [System.IO.Path]::GetFileNameWithoutExtension($smokeSave) }
    $benchmarkRoot = Join-Path $Paths.artifact_root 'runtime-benchmarks'
    New-Item -ItemType Directory -Force -Path $benchmarkRoot | Out-Null
    $latestPath = Join-Path $benchmarkRoot ("latest-{0}.json" -f $scenarioName)
    $previous = Read-EsirJson -Path $latestPath

    $deltaVsPrevious = $null
    if ($previous -and $previous.benchmark -and $previous.benchmark.avg_ms -and $previous.benchmark.avg_ms.median -and $avgMsStats -and $avgMsStats.median -ne 0) {
        $previousMedian = [double]$previous.benchmark.avg_ms.median
        $deltaVsPrevious = [ordered]@{
            previous_median_avg_ms = $previousMedian
            median_avg_ms_delta    = [Math]::Round($avgMsStats.median - $previousMedian, 6)
            median_avg_ms_delta_pct = if ($previousMedian -ne 0) {
                [Math]::Round((($avgMsStats.median - $previousMedian) / $previousMedian) * 100.0, 4)
            } else {
                $null
            }
        }
    }

    $benchmarkSummary = [ordered]@{
        scenario        = $scenarioName
        benchmark_ticks = $effectiveBenchmarkTicks
        warmup_runs     = $effectiveWarmupRuns
        measured_runs   = $effectiveBenchmarkRuns
        total_runs      = $totalRuns
        runs            = $allRuns
        measured        = $measuredRuns
        avg_ms          = $avgMsStats
        total_ms        = $totalMsStats
        per_run_max_ms  = $runMaxStats
        delta_vs_previous = $deltaVsPrevious
    }

    $overallStatus = Get-EsirOverallStatus -Checks @(
        [ordered]@{ status = $encodingPass.overall_status }
        [ordered]@{ status = if ($process.exit_code -eq 0 -and $measuredRunCount -gt 0) { 'ok' } else { 'failed' } }
        [ordered]@{ status = if (@($classification.fatal).Count -gt 0) { 'failed' } elseif (@($classification.needs_review).Count -gt 0) { 'warning' } else { 'ok' } }
    ) -Strict:$Strict

    $artifact = [ordered]@{
        task            = 'runtime-benchmark'
        overall_status  = $overallStatus
        exit_code       = $process.exit_code
        save_selection  = $saveSelection
        helper_requirements = $helperRequirements
        control_review  = $controlReview
        encoding        = $encodingPass
        warning_classes = $warningClasses
        warnings        = @($classification.needs_review)
        fatals          = @($classification.fatal)
        telemetry       = $telemetry
        benchmark       = $benchmarkSummary
        artifacts       = [ordered]@{
            config     = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $config.config_path
            write_data = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $config.write_data_dir
            stdout     = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $stdoutPath
            log        = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $logPath
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $artifactPath = Join-Path $benchmarkRoot ("runtime-benchmark-{0}-{1}.json" -f $scenarioName, $timestamp)
    Write-EsirJson -Path $artifactPath -Data $artifact
    Write-EsirJson -Path $latestPath -Data $artifact

    $artifact.artifact_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $artifactPath
    $artifact.latest_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $latestPath
    return $artifact
}

function Get-EsirHeaderTargets {
    param([Parameter(Mandatory = $true)]$Paths)

    $runtimeManifest = Read-EsirJson -Path $Paths.runtime_manifest_path
    $prototypeIndex = Read-EsirJson -Path $Paths.prototype_index_path
    $targets = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in (ConvertTo-EsirArray $runtimeManifest.entries)) { $targets.Add((Join-Path $Paths.repo_root $entry.path)) | Out-Null }
    foreach ($entry in (ConvertTo-EsirArray $prototypeIndex.direct_requires)) {
        if ($entry.path -like 'exotic-space-industries-remembrance\prototypes\*' -or $entry.path -eq 'exotic-space-industries-remembrance\teslas_legacy\data.lua') {
            $targets.Add((Join-Path $Paths.repo_root $entry.path)) | Out-Null
        }
    }
    foreach ($legacy in @('process.ps1', 'graphics1_process.ps1', 'graphics2_process.ps1', 'graphics3_process.ps1', 'graphics4_process.ps1', 'graphics5_process.ps1', 'soundtrack1_process.ps1', 'soundtrack2_process.ps1')) {
        $targets.Add((Join-Path $Paths.repo_root $legacy)) | Out-Null
    }

    return @($targets | Select-Object -Unique)
}

function Test-EsirHeaderPresence {
    param([Parameter(Mandatory = $true)]$Paths)

    $requiredFields = @('owns:', 'loaded_by:', 'cadence:', 'forwarded_events:', 'storage_roots:', 'gui_ids:', 'remote_interfaces:', 'rebuild_on:')
    $findings = @()
    foreach ($file in (Get-EsirHeaderTargets -Paths $Paths)) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $head = (((Get-EsirTextLines -Path $file) | Select-Object -First 18) -join "`n")
        $missing = @($requiredFields | Where-Object { $head -notmatch [regex]::Escape($_) })
        if ($missing.Count -gt 0) {
            $findings += [ordered]@{ file = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file; missing = @($missing) }
        }
    }
    return $findings
}

function Get-LocaleMissingFindings {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $findings = @()
    foreach ($mod in $context.source_mods) {
        $localeRoot = Join-Path $mod.directory 'locale'
        if (-not (Test-Path -LiteralPath $localeRoot)) { continue }
        $languageMaps = @{}
        foreach ($file in Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter '*.cfg') {
            $language = Split-Path -Parent $file.DirectoryName | Split-Path -Leaf
            if (-not $languageMaps.ContainsKey($language)) {
                $languageMaps[$language] = New-Object 'System.Collections.Generic.HashSet[string]'
            }

            $section = ''
            foreach ($line in (Get-EsirTextLines -Path $file.FullName)) {
                if ($line -match '^\s*\[(.+)\]\s*$') { $section = $matches[1]; continue }
                if ($line -match '^\s*([^=]+?)\s*=') { [void]$languageMaps[$language].Add("$section|$($matches[1].Trim())") }
            }
        }

        $allKeys = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($language in $languageMaps.Keys) {
            foreach ($key in $languageMaps[$language]) { [void]$allKeys.Add($key) }
        }

        foreach ($language in ($languageMaps.Keys | Sort-Object)) {
            foreach ($key in ($allKeys | Sort-Object)) {
                if (-not $languageMaps[$language].Contains($key)) {
                    $section, $name = $key -split '\|', 2
                    $findings += [ordered]@{ mod = $mod.folder_name; language = $language; section = $section; key = $name }
                }
            }
        }
    }

    return $findings
}

function Get-EsirRequireFindings {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $findings = @()
    foreach ($relativePath in (Get-EsirReachableLuaFiles -Paths $Paths -Context $context)) {
        $filePath = Join-Path $Paths.repo_root $relativePath
        if (-not (Test-Path -LiteralPath $filePath)) {
            continue
        }

        $records = @()
        $records += @(Get-DirectBareRequires -FilePath $filePath)
        $records += @(Get-DirectAssignedRequires -FilePath $filePath)
        foreach ($record in $records) {
            $resolved = Resolve-RepoLuaRequire -RepoRoot $Paths.repo_root -FilePath $filePath -RequireName $record.require -SourceMods $context.source_mods
            if (-not $resolved.exists -and (-not $resolved.is_external)) {
                $findings += [ordered]@{ file = $relativePath; missing_require = $record.require }
            }
        }
    }

    return @($findings | Sort-Object file, missing_require -Unique)
}

function Get-EsirAssetReferenceFindings {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $modMap = @{}
    foreach ($mod in $context.source_mods) { $modMap[$mod.name] = $mod.directory }
    $pathVariableMap = Get-EsirAssetPathVariableMap -Paths $Paths -Context $context
    $reachableLuaFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relativePath in (Get-EsirReachableLuaFiles -Paths $Paths -Context $context)) {
        [void]$reachableLuaFiles.Add($relativePath)
    }

    $findings = @()
    $pattern = '["''](?<value>(?:__[^/\\]+__[/\\][^"'']+\.(?:png|jpg|jpeg|webp|ogg|wav))|(?:[^"'']+\.(?:png|jpg|jpeg|webp|ogg|wav)))["'']'
    foreach ($mod in $context.source_mods) {
        foreach ($file in Get-ChildItem -LiteralPath $mod.directory -Recurse -File | Where-Object { $_.Extension -in '.lua', '.json', '.cfg' }) {
            $relativePath = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file.FullName
            if ($file.Extension -eq '.lua' -and (-not $reachableLuaFiles.Contains($relativePath))) {
                continue
            }

            $content = Get-EsirTextContent -Path $file.FullName
            if (($null -eq $content) -or ($content -notmatch '\.(?:png|jpg|jpeg|webp|ogg|wav)')) {
                continue
            }

            $contentToScan = if ($file.Extension -eq '.lua') { Get-LuaReachableStaticContentForFile -FilePath $file.FullName } else { $content }
            if ($contentToScan -notmatch '\.(?:png|jpg|jpeg|webp|ogg|wav)') {
                continue
            }

            $fieldPrefixMap = if ($file.Extension -eq '.lua') { Get-EsirLuaFieldPrefixMap -Content $contentToScan -PathVariableMap $pathVariableMap } else { @{} }
            foreach ($line in ($contentToScan -split "`r?`n")) {

                foreach ($match in [regex]::Matches($line, $pattern)) {
                    $assetRef = $match.Groups['value'].Value.Replace('/', '\')
                    $prefixVariable = $null
                    $prefixText = $line.Substring(0, $match.Index)
                    $suffixText = $line.Substring($match.Index + $match.Length)
                    if ($prefixText -match '(?<var>(?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)\s*\.\.\s*$') {
                        $prefixVariable = $matches['var']
                    }

                    if ((-not $prefixVariable) -and $file.Extension -eq '.lua' -and $assetRef -notlike '__*__*' -and $assetRef -notmatch '[\\/]') {
                        $assignmentMatch = [regex]::Match($line, '^\s*(?<field>[A-Za-z_][A-Za-z0-9_]*)\s*=')
                        if ($assignmentMatch.Success) {
                            $fieldName = $assignmentMatch.Groups['field'].Value
                            if ($fieldPrefixMap.ContainsKey($fieldName)) {
                                $prefixVariable = [string]$fieldPrefixMap[$fieldName]
                            }
                        }
                    }

                    $isBareLuaFilenameListItem = (
                        $file.Extension -eq '.lua' -and
                        (-not $prefixVariable) -and
                        $assetRef -notmatch '[\\/]' -and
                        $assetRef -notlike '__*__*' -and
                        $line -notmatch '='
                    )
                    if ($isBareLuaFilenameListItem) {
                        continue
                    }

                    $isBareLuaFilenameComparison = (
                        $file.Extension -eq '.lua' -and
                        (-not $prefixVariable) -and
                        $assetRef -notmatch '[\\/]' -and
                        $assetRef -notlike '__*__*' -and
                        (
                            $prefixText.TrimEnd() -match '(?:==|~=|<=|>=|<|>)$' -or
                            $suffixText.TrimStart() -match '^(?:==|~=|<=|>=|<|>)'
                        )
                    )
                    if ($isBareLuaFilenameComparison) {
                        continue
                    }

                    $isDynamicLuaPathFragment = (
                        $file.Extension -eq '.lua' -and
                        $prefixVariable -and
                        (-not $PathVariableMap.ContainsKey($prefixVariable))
                    )
                    if ($isDynamicLuaPathFragment) {
                        continue
                    }

                    $resolved = Resolve-EsirAssetReferencePath -AssetRef $assetRef -FilePath $file.FullName -ModDirectory $mod.directory -ModMap $modMap -PathVariableMap $pathVariableMap -PrefixVariable $prefixVariable
                    if (-not $resolved.exists -and (-not $resolved.is_external)) {
                        $referenceLabel = if ($prefixVariable) { "$prefixVariable..$assetRef" } else { $assetRef }
                        $findings += [ordered]@{ file = $relativePath; reference = $referenceLabel }
                    }
                }
            }
        }
    }

    return @($findings | Sort-Object file, reference -Unique)
}

function Get-EsirPackVersionFindings {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $findings = @()
    $factorioVersions = @{}

    foreach ($mod in $context.source_mods) {
        $info = (Get-EsirTextContent -Path $mod.info_path) | ConvertFrom-Json
        $factorioVersions[$mod.folder_name] = $info.factorio_version
        if ($info.name -ne $mod.folder_name) {
            $findings += [ordered]@{ mod = $mod.folder_name; issue = 'info-name-does-not-match-folder' }
        }
    }

    if ((@($factorioVersions.Values | Sort-Object -Unique)).Count -gt 1) {
        $findings += [ordered]@{ mod = '<all>'; issue = 'mixed-factorio-version-targets' }
    }

    return $findings
}

function New-EsirCheckResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Status = 'ok',
        [string[]]$Errors = @(),
        [string[]]$Warnings = @(),
        $Details = $null
    )

    return [ordered]@{ name = $Name; status = $Status; errors = @($Errors); warnings = @($Warnings); details = $Details }
}

function Get-EsirOverallStatus {
    param(
        [Parameter(Mandatory = $true)][object[]]$Checks,
        [switch]$Strict
    )

    if ($Checks | Where-Object { $_.status -eq 'failed' }) { return 'failed' }
    if ($Strict -and ($Checks | Where-Object { $_.status -eq 'warning' })) { return 'failed' }
    if ($Checks | Where-Object { $_.status -eq 'warning' }) { return 'warning' }
    if ($Checks | Where-Object { $_.status -eq 'skipped' }) { return 'skipped' }
    return 'ok'
}

function Invoke-EsirPreflight {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$FactorioPath,
        [switch]$Strict,
        [switch]$FixEncoding
    )

    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath
    $checks = @()

    $lua = Test-EsirReachableLuaFiles -Paths $Paths -Context $context
    $checks += New-EsirCheckResult -Name 'lua-syntax' -Status $(if ($lua.skipped) { 'skipped' } elseif (@($lua.failures).Count -gt 0) { 'failed' } else { 'ok' }) -Errors @($lua.failures | ForEach-Object { '{0}: {1}' -f (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.file), $_.error }) -Details $lua

    $python = Test-PythonFiles -Context $context
    $checks += New-EsirCheckResult -Name 'python-syntax' -Status $(if ($python.skipped) { 'skipped' } elseif (@($python.failures).Count -gt 0) { 'failed' } else { 'ok' }) -Errors @($python.failures | ForEach-Object { '{0}: {1}' -f (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.file), $_.error }) -Details $python

    $powershellFindings = Test-PowerShellFiles -Context $context
    $checks += New-EsirCheckResult -Name 'powershell-syntax' -Status $(if (@($powershellFindings).Count -gt 0) { 'failed' } else { 'ok' }) -Errors @($powershellFindings | ForEach-Object { '{0}: {1}' -f (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.file), $_.error }) -Details $powershellFindings

    $encodingPass = Invoke-EsirEncodingPass -Paths $Paths -Fix:$FixEncoding
    $checks += New-EsirCheckResult -Name 'encoding-health' -Status $encodingPass.overall_status -Errors @($encodingPass.findings | Where-Object { $_.status -eq 'failed' } | ForEach-Object { '{0}: {1} [{2}]' -f $_.file, ($_.issues -join ', '), $_.encoding }) -Warnings @($encodingPass.findings | Where-Object { $_.fixed } | ForEach-Object { '{0}: fixed [{1}]' -f $_.file, $(if (@($_.repair_steps).Count -gt 0) { $_.repair_steps -join ', ' } else { 'rewritten-as-utf8' }) }) -Details $encodingPass

    $requireFindings = Get-EsirRequireFindings -Paths $Paths
    $checks += New-EsirCheckResult -Name 'missing-requires' -Status $(if (@($requireFindings).Count -gt 0) { 'failed' } else { 'ok' }) -Errors @($requireFindings | ForEach-Object { '{0}: {1}' -f $_.file, $_.missing_require }) -Details $requireFindings

    $duplicateLocale = Get-LocaleDuplicateFindings -Context $context
    $checks += New-EsirCheckResult -Name 'locale-duplicates' -Status $(if (@($duplicateLocale).Count -gt 0) { 'warning' } else { 'ok' }) -Warnings @($duplicateLocale | ForEach-Object { '{0}: [{1}] {2} lines {3}/{4}' -f (Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.file), $_.section, $_.key, $_.first_line, $_.second_line }) -Details $duplicateLocale

    $missingLocale = Get-LocaleMissingFindings -Paths $Paths
    $checks += New-EsirCheckResult -Name 'locale-missing' -Status $(if (@($missingLocale).Count -gt 0) { 'warning' } else { 'ok' }) -Warnings @($missingLocale | Select-Object -First 50 | ForEach-Object { '{0}/{1}: [{2}] {3}' -f $_.mod, $_.language, $_.section, $_.key }) -Details $missingLocale

    $assetFindings = Get-EsirAssetReferenceFindings -Paths $Paths
    $checks += New-EsirCheckResult -Name 'asset-references' -Status $(if (@($assetFindings).Count -gt 0) { 'failed' } else { 'ok' }) -Errors @($assetFindings | Select-Object -First 100 | ForEach-Object { '{0}: {1}' -f $_.file, $_.reference }) -Details $assetFindings

    $packFindings = Get-EsirPackVersionFindings -Paths $Paths
    $checks += New-EsirCheckResult -Name 'pack-version-consistency' -Status $(if (@($packFindings).Count -gt 0) { 'warning' } else { 'ok' }) -Warnings @($packFindings | ForEach-Object { '{0}: {1}' -f $_.mod, $_.issue }) -Details $packFindings

    $headerFindings = Test-EsirHeaderPresence -Paths $Paths
    $checks += New-EsirCheckResult -Name 'module-headers' -Status $(if (@($headerFindings).Count -gt 0) { 'warning' } else { 'ok' }) -Warnings @($headerFindings | ForEach-Object { '{0}: missing {1}' -f $_.file, ($_.missing -join ', ') }) -Details $headerFindings

    return [ordered]@{
        task           = 'preflight'
        overall_status = Get-EsirOverallStatus -Checks $checks -Strict:$Strict
        checks         = $checks
    }
}

function Get-EsirPortalQueries {
    return @('recipe icons', 'tesla', 'fusion reactor', 'orbital combinator', 'gaia')
}

function Get-EsirPortalFitScore {
    param([Parameter(Mandatory = $true)]$Item)

    $score = 0
    if ($Item.repo_relation -eq 'new-to-repo') { $score += 20 }
    if ($Item.requires_space_age) { $score += 15 }
    if ($Item.source_url) { $score += 10 }
    if ($Item.license) { $score += 10 }

    $haystack = @($Item.name, $Item.title, $Item.summary, $Item.tags) -join ' '
    foreach ($term in @('esir', 'exotic', 'tesla', 'fusion', 'orbital', 'recipe', 'icon', 'gaia')) {
        if ($haystack -match [regex]::Escape($term)) { $score += 5 }
    }

    return $score
}

function Test-EsirPortalCandidate {
    param([Parameter(Mandatory = $true)]$Item)

    $haystack = (@(
        $(if ($Item.PSObject.Properties.Name -contains 'name') { $Item.name } else { $null })
        $(if ($Item.PSObject.Properties.Name -contains 'mod_name') { $Item.mod_name } else { $null })
        $(if ($Item.PSObject.Properties.Name -contains 'title') { $Item.title } else { $null })
        $(if ($Item.PSObject.Properties.Name -contains 'summary') { $Item.summary } else { $null })
        $(if ($Item.PSObject.Properties.Name -contains 'notes') { $Item.notes } else { $null })
        $(if ($Item.PSObject.Properties.Name -contains 'tags') { $Item.tags } else { $null })
    ) -join ' ').ToLowerInvariant()
    if ($haystack -match 'translation|into japanese|russian-language|language pack|locali[sz]ation') {
        return $false
    }

    return (
        ($haystack -match 'recipe') -or
        ($haystack -match 'icon') -or
        ($haystack -match 'tesla') -or
        ($haystack -match 'fusion') -or
        ($haystack -match 'orbital') -or
        ($haystack -match 'gaia') -or
        ($haystack -match 'exotic space industries')
    )
}

function Invoke-EsirPortalScout {
    param([Parameter(Mandatory = $true)]$Paths)

    $entriesByName = @{}
    foreach ($query in (Get-EsirPortalQueries)) {
        $json = & powershell -ExecutionPolicy Bypass -File $Paths.portal_search_script -RepoRoot $Paths.repo_root -Query $query -FactorioVersion '2.0' -Limit 6 -FetchFullTop 6 -OnlyNewToRepo -AsJson
        if ($LASTEXITCODE -ne 0) { throw "Portal scout query failed: $query" }
        $summary = $json | ConvertFrom-Json
        foreach ($item in (ConvertTo-EsirArray $summary.results)) {
            if (-not $entriesByName.ContainsKey($item.name)) { $entriesByName[$item.name] = $item }
        }
    }

    if (-not $entriesByName.ContainsKey('exotic-space-industries')) {
        $lineageJson = & powershell -ExecutionPolicy Bypass -File $Paths.portal_search_script -RepoRoot $Paths.repo_root -NameList 'exotic-space-industries' -FactorioVersion '2.0' -Limit 1 -FetchFullTop 1 -AsJson
        if ($LASTEXITCODE -eq 0) {
            $lineageSummary = $lineageJson | ConvertFrom-Json
            foreach ($item in (ConvertTo-EsirArray $lineageSummary.results)) { $entriesByName[$item.name] = $item }
        }
    }

    $shortlist = foreach ($item in $entriesByName.Values) {
        $notes = [System.Collections.Generic.List[string]]::new()
        if (-not $item.license) { $notes.Add('license review required') | Out-Null }
        if (-not $item.source_url) { $notes.Add('source URL missing from portal metadata') | Out-Null }
        if ($item.name -eq 'exotic-space-industries') { $notes.Add('lineage/reference candidate, not a drop-in integration target') | Out-Null }
        [pscustomobject][ordered]@{
            mod_name      = $item.name
            portal_url    = $item.portal_url
            license       = $item.license
            source_url    = $item.source_url
            repo_relation = $item.repo_relation
            fit_score     = Get-EsirPortalFitScore -Item $item
            notes         = if ($notes.Count -gt 0) { $notes -join '; ' } else { $item.summary }
        }
    }

    $preferredNames = @(
        'recipe-icons-improvement-for-esir',
        'icon-badges',
        'sei-tesla-turret',
        'sei-fusion-reactor',
        'orbital-request-combinator',
        'exotic-space-industries'
    )
    $curated = @($shortlist | Where-Object { $_.mod_name -in $preferredNames })
    if (@($curated).Count -eq 0) {
        $curated = @($shortlist | Where-Object { Test-EsirPortalCandidate -Item $_ } | Sort-Object @{ Expression = { [int]$_.fit_score }; Descending = $true }, mod_name | Select-Object -First 12)
    }

    $payload = [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date).ToString('o')
        queries        = @(Get-EsirPortalQueries)
        entries        = @($curated | Sort-Object @{ Expression = { [int]$_.fit_score }; Descending = $true }, mod_name)
    }
    Write-EsirJson -Path $Paths.portal_shortlist_path -Data $payload

    return [ordered]@{
        task           = 'portal-scout'
        overall_status = 'ok'
        shortlist_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.portal_shortlist_path
        entries        = $payload.entries
    }
}

function Invoke-EsirDiff {
    param([Parameter(Mandatory = $true)]$Paths)

    $context = Get-EsirQcContext -Paths $Paths
    $cacheDrift = Get-CacheDriftFindings -Context $context
    $previewCache = @(@('.factorio-qc\mods-preview', '.factorio-qc\preview-summary.json', '.factorio-qc\preview-summary-v2.json') | Where-Object { Test-Path -LiteralPath (Join-Path $Paths.repo_root $_) })
    $packageRoot = Join-Path $context.artifact_root 'packages'
    $packageFiles = @()
    if (Test-Path -LiteralPath $packageRoot) {
        $packageFiles = @(Get-ChildItem -LiteralPath $packageRoot -File -Filter '*.zip' | ForEach-Object { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_.FullName } | Sort-Object)
    }

    $modsDirectory = Join-Path $env:APPDATA 'Factorio\mods'
    $deployDuplicates = @()
    if (Test-Path -LiteralPath $modsDirectory) {
        foreach ($pack in (ConvertTo-EsirArray (Read-EsirJson -Path $Paths.pack_manifest_path).entries)) {
            $folderExists = Test-Path -LiteralPath (Join-Path $modsDirectory $pack.folder)
            $zipExists = @(Get-ChildItem -LiteralPath $modsDirectory -File -Filter ($pack.folder + '_*.zip') -ErrorAction SilentlyContinue).Count -gt 0
            if ($folderExists -and $zipExists) { $deployDuplicates += [ordered]@{ pack = $pack.folder; issue = 'both-folder-and-zip-present-in-factorio-mods' } }
        }
    }

    $portalShortlist = Read-EsirJson -Path $Paths.portal_shortlist_path
    $portalCachePath = Join-Path $context.artifact_root 'portal\mods-index-2.0.json'
    $portalState = [ordered]@{
        shortlist_exists       = $null -ne $portalShortlist
        shortlist_generated_at = if ($portalShortlist) { $portalShortlist.generated_at } else { $null }
        raw_cache_exists       = Test-Path -LiteralPath $portalCachePath
        raw_cache_age_hours    = if (Test-Path -LiteralPath $portalCachePath) { [math]::Round(((Get-Date) - (Get-Item -LiteralPath $portalCachePath).LastWriteTime).TotalHours, 2) } else { $null }
    }

    return [ordered]@{
        task              = 'diff'
        overall_status    = if ($cacheDrift.Count -gt 0 -or $deployDuplicates.Count -gt 0) { 'warning' } else { 'ok' }
        cache_drift       = $cacheDrift
        preview_cache     = $previewCache
        package_outputs   = $packageFiles
        deploy_duplicates = $deployDuplicates
        portal_shortlist  = $portalState
        cache_seed_roots  = @($context.cache_seed_directories | ForEach-Object { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_ })
        live_run_mod_root = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $context.run_mod_directory
    }
}

function Resolve-EsirArtSessionPath {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SessionName
    )

    if ($SessionName) {
        $candidate = if ([System.IO.Path]::IsPathRooted($SessionName)) {
            $SessionName
        } else {
            Join-Path $Paths.repo_root $SessionName
        }
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $latestFile = Join-Path $Paths.artifact_root 'chatgpt-firefox\latest-session.txt'
    if (Test-Path -LiteralPath $latestFile) {
        return (Get-EsirTextContent -Path $latestFile).Trim()
    }

    throw 'No ChatGPT Firefox session found.'
}

function Invoke-EsirArtStart {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$PromptText,
        [string]$PromptFile,
        [string]$SessionName,
        [string]$DownloadsPath,
        [switch]$SkipBrowser,
        [switch]$SkipClipboard
    )

    $arguments = @('-ExecutionPolicy', 'Bypass', '-File', $Paths.firefox_invoke_script, '-Mode', 'start', '-RepoRoot', $Paths.repo_root)
    if ($PromptText) { $arguments += @('-PromptText', $PromptText) }
    if ($PromptFile) { $arguments += @('-PromptFile', (Resolve-EsirUserPath -Paths $Paths -Path $PromptFile)) }
    if ($SessionName) { $arguments += @('-SessionName', $SessionName) }
    if ($DownloadsPath) { $arguments += @('-DownloadsPath', $DownloadsPath) }
    if ($SkipBrowser) { $arguments += '-SkipBrowser' }
    if ($SkipClipboard) { $arguments += '-SkipClipboard' }
    & powershell @arguments | Out-Null
    $exitCode = $LASTEXITCODE
    $latestSession = if ($exitCode -eq 0) { Resolve-EsirArtSessionPath -Paths $Paths } else { $null }
    return [ordered]@{
        task           = 'art-start'
        overall_status = if ($exitCode -eq 0) { 'ok' } else { 'failed' }
        exit_code      = $exitCode
        session_path   = if ($latestSession) { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $latestSession } else { $null }
    }
}

function Invoke-EsirArtCollect {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SessionName
    )

    $arguments = @('-ExecutionPolicy', 'Bypass', '-File', $Paths.firefox_invoke_script, '-Mode', 'collect', '-RepoRoot', $Paths.repo_root)
    if ($SessionName) { $arguments += @('-SessionPath', (Resolve-EsirArtSessionPath -Paths $Paths -SessionName $SessionName)) }
    & powershell @arguments | Out-Null
    $sessionPath = Resolve-EsirArtSessionPath -Paths $Paths -SessionName $SessionName
    $session = (Get-EsirTextContent -Path (Join-Path $sessionPath 'session.json')) | ConvertFrom-Json
    return [ordered]@{ task = 'art-collect'; overall_status = if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' }; session_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $sessionPath; collected_files = @($session.collected_files) }
}

function Invoke-EsirArtReview {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SessionName,
        [string]$Pack,
        [string]$PromptText
    )

    $sessionPath = Resolve-EsirArtSessionPath -Paths $Paths -SessionName $SessionName
    $session = (Get-EsirTextContent -Path (Join-Path $sessionPath 'session.json')) | ConvertFrom-Json
    $reviewPath = Join-Path $sessionPath 'review.json'
    $reviewEntries = @()

    foreach ($file in (ConvertTo-EsirArray $session.collected_files)) {
        $reviewEntries += [ordered]@{
            asset_id       = [System.IO.Path]::GetFileName($file.copied_path)
            source_session = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $sessionPath
            source_file    = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file.copied_path
            target_pack    = if ($Pack) { $Pack } else { 'unassigned' }
            target_path    = $null
            role           = if ($PromptText) { $PromptText } else { 'unassigned' }
            status         = 'candidate'
            notes          = 'Review and choose import target before copying into a pack.'
        }
    }

    Write-EsirJson -Path $reviewPath -Data ([ordered]@{ schema_version = 1; generated_at = (Get-Date).ToString('o'); session_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $sessionPath; entries = @($reviewEntries) })
    $existingPlan = Read-EsirJson -Path $Paths.asset_import_plan_path
    $combined = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in (ConvertTo-EsirArray $(if ($existingPlan) { $existingPlan.entries } else { $null }))) { $combined.Add($entry) | Out-Null }
    foreach ($entry in $reviewEntries) { $combined.Add($entry) | Out-Null }
    Write-EsirJson -Path $Paths.asset_import_plan_path -Data ([ordered]@{ schema_version = 1; generated_at = (Get-Date).ToString('o'); entries = @($combined) })

    return [ordered]@{ task = 'art-review'; overall_status = 'ok'; review_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $reviewPath; entries = @($reviewEntries) }
}

function Invoke-EsirArtValidate {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SessionName
    )

    Add-Type -AssemblyName System.Drawing
    $sessionPath = Resolve-EsirArtSessionPath -Paths $Paths -SessionName $SessionName
    $session = (Get-EsirTextContent -Path (Join-Path $sessionPath 'session.json')) | ConvertFrom-Json
    $findings = @()

    foreach ($file in (ConvertTo-EsirArray $session.collected_files)) {
        $copiedPath = $file.copied_path
        $status = 'ok'
        $notes = [System.Collections.Generic.List[string]]::new()
        if (-not (Test-Path -LiteralPath $copiedPath)) {
            $status = 'failed'
            $notes.Add('collected file missing') | Out-Null
        } else {
            $item = Get-Item -LiteralPath $copiedPath
            if ($item.Length -le 0) { $status = 'failed'; $notes.Add('zero-byte image') | Out-Null }
            try {
                $image = [System.Drawing.Image]::FromFile($copiedPath)
                try {
                    $notes.Add("dimensions=$($image.Width)x$($image.Height)") | Out-Null
                    if ($image.PixelFormat.ToString() -match 'Alpha') { $notes.Add('alpha-channel=present') | Out-Null } else { $notes.Add('alpha-channel=not-detected') | Out-Null }
                } finally {
                    $image.Dispose()
                }
            } catch {
                if ($status -ne 'failed') { $status = 'warning' }
                $notes.Add('image-dimensions-unreadable') | Out-Null
            }
        }
        $findings += [ordered]@{ file = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $copiedPath; status = $status; notes = @($notes) }
    }

    $overallStatus = Get-EsirOverallStatus -Checks @($findings | ForEach-Object { [ordered]@{ status = $_.status } })
    return [ordered]@{ task = 'art-validate'; overall_status = $overallStatus; session_path = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $sessionPath; files = @($findings) }
}

function Invoke-EsirPackDeploy {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$Pack
    )

    $packManifest = Read-EsirJson -Path $Paths.pack_manifest_path
    $entries = @(ConvertTo-EsirArray $packManifest.entries)
    if ($Pack -and $Pack -ne 'all') {
        $entries = @($entries | Where-Object { $_.id -eq $Pack -or $_.folder -eq $Pack })
        if ($entries.Count -eq 0) { throw "Pack not found for deploy: $Pack" }
    }

    $results = @()
    foreach ($entry in $entries) {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $Paths.repo_root $entry.deploy_script) | Out-Null
        $results += [ordered]@{ pack = $entry.folder; deploy_script = $entry.deploy_script; exit_code = $LASTEXITCODE; status = if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' } }
    }

    return [ordered]@{ task = 'pack-deploy'; overall_status = if ($results | Where-Object { $_.status -eq 'failed' }) { 'failed' } else { 'ok' }; results = $results }
}

function Invoke-EsirDoctor {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [string]$FactorioPath
    )

    $context = Get-EsirQcContext -Paths $Paths -FactorioPath $FactorioPath
    $firefox = Get-Command firefox -ErrorAction SilentlyContinue
    $firefoxPath = if ($firefox) {
        $firefox.Source
    } else {
        @('C:\Program Files\Mozilla Firefox\firefox.exe', 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe') |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    }
    $packManifest = Get-EsirPackManifestData -Paths $Paths

    return [ordered]@{
        task                   = 'doctor'
        overall_status         = 'ok'
        repo_root              = $Paths.repo_root
        is_esir                = $context.is_esir
        factorio_exe           = $context.factorio_exe
        firefox_exe            = if ($firefoxPath) { $firefoxPath } else { 'not-found' }
        factorio_skill_root    = $Paths.factorio_skill_root
        firefox_skill_root     = $Paths.firefox_skill_root
        repo_skill_root        = $Paths.repo_skill_root
        dependency_skill_root  = $Paths.dependency_skill_root
        dependency_wrapper     = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.dependency_invoke_script
        manifest_root          = $Paths.manifest_root
        artifact_root          = $Paths.artifact_root
        run_mod_directory      = $context.run_mod_directory
        cache_seed_directories = @($context.cache_seed_directories | ForEach-Object { Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $_ })
        packs                  = @($packManifest.entries)
    }
}

function Invoke-EsirTask {
    param(
        [Parameter(Mandatory = $true)][string]$Task,
        [Parameter(Mandatory = $true)]$Paths,
        [string]$SaveId,
        [string]$SavePath,
        [Nullable[int]]$WarmupRuns,
        [Nullable[int]]$BenchmarkRuns,
        [Nullable[int]]$BenchmarkTicks,
        [Nullable[int]]$Seed,
        [uint32[]]$Seeds,
        [Nullable[int]]$PreviewSize,
        [string]$Planet,
        [string]$Pack,
        [string]$DependencyScope,
        [string]$DependencyCategory,
        [string]$ModName,
        [string]$TargetPath,
        [string]$PromptText,
        [string]$PromptFile,
        [string]$SessionName,
        [string]$DownloadsPath,
        [string]$FactorioPath,
        [switch]$Strict,
        [switch]$ResolveInstalled,
        [switch]$FixEncoding,
        [switch]$SkipBrowser,
        [switch]$SkipClipboard
    )

    switch ($Task) {
        'doctor' { return Invoke-EsirDoctor -Paths $Paths -FactorioPath $FactorioPath }
        'manifest-refresh' { return Invoke-EsirManifestRefresh -Paths $Paths }
        'dependency-refresh' { return Invoke-EsirDependencyRefresh -Paths $Paths }
        'dependency-query' { return Invoke-EsirDependencyQuery -Paths $Paths -Scope $DependencyScope -Category $DependencyCategory -ModName $ModName -Pack $Pack -PathFilter $TargetPath -ResolveInstalled:$ResolveInstalled }
        'dependency-diff' { return Invoke-EsirDependencyDiff -Paths $Paths -Strict:$Strict }
        'preflight' { return Invoke-EsirPreflight -Paths $Paths -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-fast' { return Invoke-EsirQcMode -Paths $Paths -Mode 'fast' -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-runtime' { return Invoke-EsirQcMode -Paths $Paths -Mode 'runtime' -SaveId $SaveId -SavePath $SavePath -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'runtime-benchmark' { return Invoke-EsirRuntimeBenchmark -Paths $Paths -SaveId $SaveId -SavePath $SavePath -WarmupRuns $WarmupRuns -BenchmarkRuns $BenchmarkRuns -BenchmarkTicks $BenchmarkTicks -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-preview' { return Invoke-EsirQcMode -Paths $Paths -Mode 'preview' -SaveId $SaveId -SavePath $SavePath -Seed $Seed -Planet $Planet -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-gaia-resources' { return Invoke-EsirGaiaResourceQc -Paths $Paths -Seeds $Seeds -PreviewSize $PreviewSize -FactorioPath $FactorioPath }
        'qc-assets' { return Invoke-EsirQcMode -Paths $Paths -Mode 'assets' -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-package' { return Invoke-EsirQcMode -Paths $Paths -Mode 'package' -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'qc-full' { return Invoke-EsirQcMode -Paths $Paths -Mode 'full' -SaveId $SaveId -SavePath $SavePath -Seed $Seed -Planet $Planet -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'portal-scout' { return Invoke-EsirPortalScout -Paths $Paths }
        'diff' { return Invoke-EsirDiff -Paths $Paths }
        'art-start' { return Invoke-EsirArtStart -Paths $Paths -PromptText $PromptText -PromptFile $PromptFile -SessionName $SessionName -DownloadsPath $DownloadsPath -SkipBrowser:$SkipBrowser -SkipClipboard:$SkipClipboard }
        'art-collect' { return Invoke-EsirArtCollect -Paths $Paths -SessionName $SessionName }
        'art-review' { return Invoke-EsirArtReview -Paths $Paths -SessionName $SessionName -Pack $Pack -PromptText $PromptText }
        'art-validate' { return Invoke-EsirArtValidate -Paths $Paths -SessionName $SessionName }
        'pack-dryrun' { return Invoke-EsirQcMode -Paths $Paths -Mode 'package' -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding }
        'pack-deploy' { return Invoke-EsirPackDeploy -Paths $Paths -Pack $(if ($Pack) { $Pack } else { 'all' }) }
        'full' {
            $steps = @(
                (Invoke-EsirDoctor -Paths $Paths -FactorioPath $FactorioPath)
                (Invoke-EsirManifestRefresh -Paths $Paths)
                (Invoke-EsirPreflight -Paths $Paths -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding)
                (Invoke-EsirQcMode -Paths $Paths -Mode 'full' -SaveId $SaveId -SavePath $SavePath -Seed $Seed -Planet $Planet -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding)
                (Invoke-EsirPortalScout -Paths $Paths)
                (Invoke-EsirDiff -Paths $Paths)
                Invoke-EsirQcMode -Paths $Paths -Mode 'package' -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding
            )

            return [ordered]@{ task = 'full'; overall_status = Get-EsirOverallStatus -Checks @($steps | ForEach-Object { [ordered]@{ status = $_.overall_status } }) -Strict:$Strict; steps = $steps }
        }
        default { throw "Unsupported ESIR task: $Task" }
    }
}
