Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EsirDependencyCategoryNames {
    return ,@('runtime-integration', 'prototype-integration', 'planet-content', 'remote-interface', 'media-pack')
}

function Get-EsirDependencyCategoryFilter {
    param([string]$Category = 'all')

    switch ($Category) {
        'runtime' { return ,@('runtime-integration') }
        'prototype' { return ,@('prototype-integration') }
        'planet' { return ,@('planet-content') }
        'remote' { return ,@('remote-interface') }
        'media' { return ,@('media-pack') }
        default { return ,(Get-EsirDependencyCategoryNames) }
    }
}

function New-EsirStringSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase))
}

function Add-EsirStringSetItems {
    param(
        [Parameter(Mandatory = $true)]$Set,
        $Items
    )

    foreach ($item in (ConvertTo-EsirArray $Items)) {
        if ($null -eq $item) { continue }
        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        [void]$Set.Add($text.Trim())
    }
}

function ConvertTo-EsirSortedArray {
    param($Items)

    return ,@((ConvertTo-EsirArray $Items) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
}

function Get-EsirDependencyPackManifest {
    param([Parameter(Mandatory = $true)]$Paths)

    $manifest = Read-EsirJson -Path $Paths.pack_manifest_path
    if (-not $manifest -or -not $manifest.entries) {
        $manifest = Get-EsirPackManifestData -Paths $Paths
    }

    return $manifest
}

function Get-EsirDependencyRuntimeManifest {
    param([Parameter(Mandatory = $true)]$Paths)

    $manifest = Read-EsirJson -Path $Paths.runtime_manifest_path
    if (-not $manifest -or -not $manifest.entries) {
        $manifest = Get-EsirRuntimeManifestData -Paths $Paths
    }

    return $manifest
}

function Get-EsirDependencyPrototypeManifest {
    param([Parameter(Mandatory = $true)]$Paths)

    $manifest = Read-EsirJson -Path $Paths.prototype_index_path
    if (-not $manifest -or (-not $manifest.direct_requires -and -not $manifest.prototype_files)) {
        $manifest = Get-EsirPrototypeIndexData -Paths $Paths
    }

    return $manifest
}

function Get-EsirPackRoleMap {
    param([Parameter(Mandatory = $true)]$Paths)

    $roleMap = @{}
    $typeMap = @{}
    foreach ($entry in (ConvertTo-EsirArray (Get-EsirDependencyPackManifest -Paths $Paths).entries)) {
        $roleMap[[string]$entry.id] = [string]$entry.role
        $roleMap[[string]$entry.folder] = [string]$entry.role
        $typeMap[[string]$entry.id] = [string]$entry.type
        $typeMap[[string]$entry.folder] = [string]$entry.type
    }

    return [pscustomobject]@{
        roles = $roleMap
        types = $typeMap
    }
}

function Parse-EsirDependencyString {
    param(
        [Parameter(Mandatory = $true)][string]$Dependency,
        [Parameter(Mandatory = $true)][string]$DeclaredByPack,
        [Parameter(Mandatory = $true)][string]$DeclaredIn,
        [Parameter(Mandatory = $true)][string]$PackRole
    )

    $working = $Dependency.Trim()
    $kind = 'required'

    if ($working.StartsWith('(?)')) {
        $kind = 'hidden-optional'
        $working = $working.Substring(3).TrimStart()
    } elseif ($working.StartsWith('?')) {
        $kind = 'optional'
        $working = $working.Substring(1).TrimStart()
    } elseif ($working.StartsWith('!')) {
        $kind = 'incompatible'
        $working = $working.Substring(1).TrimStart()
    } elseif ($working.StartsWith('~')) {
        $kind = 'load-order-only'
        $working = $working.Substring(1).TrimStart()
    }

    $modName = $working
    $constraint = $null
    $match = [regex]::Match($working, '^(?<name>.+?)(?:\s+(?<constraint>(?:>=|<=|=|>|<)\s*.+))?$')
    if ($match.Success) {
        $modName = $match.Groups['name'].Value.Trim()
        if ($match.Groups['constraint'].Success) {
            $constraint = $match.Groups['constraint'].Value.Trim()
        }
    }

    return [ordered]@{
        mod_name         = $modName
        dependency_kind  = $kind
        constraint       = $constraint
        declared_by_pack = $DeclaredByPack
        declared_in      = $DeclaredIn
        pack_role        = $PackRole
    }
}

function Get-EsirDeclaredDependencyEntries {
    param([Parameter(Mandatory = $true)]$Paths)

    $packManifest = Get-EsirDependencyPackManifest -Paths $Paths
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($pack in (ConvertTo-EsirArray $packManifest.entries | Sort-Object folder, id)) {
        $infoPath = Join-Path $Paths.repo_root ([string]$pack.info_json)
        if (-not (Test-Path -LiteralPath $infoPath)) {
            continue
        }

        $info = Get-EsirTextContent -Path $infoPath | ConvertFrom-Json
        foreach ($dependency in (ConvertTo-EsirArray $info.dependencies)) {
            $entries.Add((Parse-EsirDependencyString -Dependency ([string]$dependency) -DeclaredByPack ([string]$pack.id) -DeclaredIn ([string]$pack.info_json) -PackRole ([string]$pack.role))) | Out-Null
        }
    }

    return ,@($entries | Sort-Object declared_by_pack, mod_name, dependency_kind, constraint, declared_in)
}

function Get-EsirDependencyPlanetModSet {
    param([Parameter(Mandatory = $true)]$DeclaredDependencies)

    $set = New-EsirStringSet
    foreach ($dependency in (ConvertTo-EsirArray $DeclaredDependencies)) {
        if ($dependency.dependency_kind -ne 'hidden-optional') {
            continue
        }

        if ([string]$dependency.mod_name -ieq 'Krastorio2-spaced-out') {
            continue
        }

        [void]$set.Add([string]$dependency.mod_name)
    }

    return $set
}

function Get-EsirDependencyMediaPackSet {
    param([Parameter(Mandatory = $true)]$Paths)

    $set = New-EsirStringSet
    foreach ($entry in (ConvertTo-EsirArray (Get-EsirDependencyPackManifest -Paths $Paths).entries)) {
        if ($entry.type -in @('graphics-pack', 'soundtrack-pack')) {
            [void]$set.Add([string]$entry.id)
        }
    }

    return $set
}

function Get-EsirDependencyIgnoredExternalPathMods {
    $set = New-EsirStringSet
    Add-EsirStringSetItems -Set $set -Items @('base', 'core', 'quality')
    return $set
}

function Get-EsirBuiltinRemoteInterfaceSet {
    $set = New-EsirStringSet
    Add-EsirStringSetItems -Set $set -Items @('freeplay', 'space_finish_script')
    return $set
}

function Get-EsirDependencyRuntimeRefLookup {
    param([Parameter(Mandatory = $true)]$Paths)

    $lookup = @{}
    foreach ($entry in (ConvertTo-EsirArray (Get-EsirDependencyRuntimeManifest -Paths $Paths).entries)) {
        $path = [string]$entry.path
        if (-not $lookup.ContainsKey($path)) {
            $lookup[$path] = [System.Collections.Generic.List[string]]::new()
        }
        $lookup[$path].Add([string]$entry.id) | Out-Null
    }

    return $lookup
}

function Get-EsirDependencyPrototypeRefLookup {
    param([Parameter(Mandatory = $true)]$Paths)

    $lookup = @{}
    $manifest = Get-EsirDependencyPrototypeManifest -Paths $Paths
    foreach ($entry in (ConvertTo-EsirArray $manifest.direct_requires)) {
        $pathsToMap = @([string]$entry.path) + @(ConvertTo-EsirArray $entry.children | ForEach-Object { [string]$_ })
        foreach ($path in $pathsToMap) {
            if (-not $lookup.ContainsKey($path)) {
                $lookup[$path] = [System.Collections.Generic.List[string]]::new()
            }
            $lookup[$path].Add([string]$entry.id) | Out-Null
        }
    }

    return $lookup
}

function Get-EsirDependencyTouchpointFiles {
    param([Parameter(Mandatory = $true)]$Paths)

    $relativePaths = [System.Collections.Generic.List[string]]::new()
    $controlPath = Join-Path $Paths.repo_root 'exotic-space-industries-remembrance\control.lua'
    if (Test-Path -LiteralPath $controlPath) {
        $relativePaths.Add('exotic-space-industries-remembrance\control.lua') | Out-Null
    }

    foreach ($relativeRoot in @('exotic-space-industries-remembrance\scripts\control', 'exotic-space-industries-remembrance\scripts\data-updates', 'exotic-space-industries-remembrance\scripts\data-final-updates')) {
        $fullRoot = Join-Path $Paths.repo_root $relativeRoot
        if (-not (Test-Path -LiteralPath $fullRoot)) {
            continue
        }

        foreach ($file in (Get-ChildItem -LiteralPath $fullRoot -Recurse -File -Filter '*.lua' | Sort-Object FullName)) {
            $relativePaths.Add((Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $file.FullName)) | Out-Null
        }
    }

    return ,@($relativePaths | Sort-Object -Unique)
}

function Get-EsirTouchpointPhase {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if ($RelativePath -eq 'exotic-space-industries-remembrance\control.lua' -or $RelativePath -like 'exotic-space-industries-remembrance\scripts\control\*') {
        return 'runtime'
    }
    if ($RelativePath -like 'exotic-space-industries-remembrance\scripts\data-final-updates\*') {
        return 'data-final-updates'
    }
    return 'data-updates'
}

function Get-EsirTouchpointSourcePack {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    return (($RelativePath -split '\\')[0])
}

function Get-EsirDependencyMatches {
    param(
        [AllowEmptyString()][string]$Needle,
        $Haystacks
    )

    if ([string]::IsNullOrWhiteSpace($Needle)) {
        return $true
    }

    foreach ($haystack in (ConvertTo-EsirArray $Haystacks)) {
        if ($null -eq $haystack) { continue }
        $text = [string]$haystack
        if ($text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    return $false
}

function Get-EsirGuardModsFromContent {
    param([AllowEmptyString()][string]$Content)

    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    $patterns = @(
        'script\.active_mods\[\s*["''](?<name>[^"'']+)["'']\s*\]',
        'mods\[\s*["''](?<name>[^"'']+)["'']\s*\]'
    )

    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Content, $pattern)) {
            [void]$set.Add($match.Groups['name'].Value)
        }
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirExternalPathModsFromContent {
    param([AllowEmptyString()][string]$Content)

    $ignored = Get-EsirDependencyIgnoredExternalPathMods
    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    foreach ($match in [regex]::Matches($Content, '__([^\\\/]+?)__(?=[\\/])')) {
        $name = $match.Groups[1].Value
        if ($ignored.Contains($name)) {
            continue
        }
        [void]$set.Add($name)
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirRemoteInterfacesFromContent {
    param([AllowEmptyString()][string]$Content)

    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    $patterns = @(
        'remote\.call\(\s*["''](?<name>[^"'']+)["'']',
        'remote\.interfaces\[\s*["''](?<name>[^"'']+)["'']\s*\]',
        'remote\.add_interface\(\s*["''](?<name>[^"'']+)["'']'
    )

    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Content, $pattern)) {
            [void]$set.Add($match.Groups['name'].Value)
        }
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirExternalRemoteInterfaces {
    param($RemoteInterfaces)

    $builtin = Get-EsirBuiltinRemoteInterfaceSet
    $set = New-EsirStringSet
    foreach ($name in (ConvertTo-EsirArray $RemoteInterfaces)) {
        $text = [string]$name
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($builtin.Contains($text)) { continue }
        if ($text -like 'exotic-industries*') { continue }
        [void]$set.Add($text)
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirEventHooksFromContent {
    param([AllowEmptyString()][string]$Content)

    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    foreach ($match in [regex]::Matches($Content, 'defines\.events\.([A-Za-z0-9_]+)')) {
        [void]$set.Add($match.Groups[1].Value)
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirTargetPrototypesFromContent {
    param([AllowEmptyString()][string]$Content)

    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    foreach ($match in [regex]::Matches($Content, 'data\.raw\[\s*["'']([^"'']+)["'']\s*\]\[\s*["'']([^"'']+)["'']\s*\]')) {
        [void]$set.Add(('{0}:{1}' -f $match.Groups[1].Value, $match.Groups[2].Value))
    }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirTouchpointKinds {
    param([AllowEmptyString()][string]$Content)

    $set = New-EsirStringSet
    if ($null -eq $Content) { $Content = '' }

    if ($Content -match 'script\.active_mods') { [void]$set.Add('script.active_mods') }
    if ($Content -match 'mods\[') { [void]$set.Add('mods') }
    if ($Content -match 'remote\.call') { [void]$set.Add('remote.call') }
    if ($Content -match 'remote\.interfaces') { [void]$set.Add('remote.interfaces') }
    if ($Content -match 'remote\.add_interface') { [void]$set.Add('remote.add_interface') }
    if ($Content -match '__[^_\\/]+__') { [void]$set.Add('external-path') }
    if ($Content -match 'data\.raw') { [void]$set.Add('data.raw') }

    return ConvertTo-EsirSortedArray -Items $set
}

function Get-EsirDependencyPurpose {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($RelativePath)
    switch ($Category) {
        'runtime-integration' { return "Runtime compatibility touchpoints in $name" }
        'prototype-integration' { return "Data-stage compatibility touchpoints in $name" }
        'planet-content' { return "Planet or content integration touchpoints in $name" }
        'remote-interface' { return "Remote interface bridge touchpoints in $name" }
        'media-pack' { return "Shallow media-pack metadata for $name" }
        default { return "Dependency touchpoints in $name" }
    }
}

function New-EsirDependencyTouchpointEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Direction,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$SourcePack,
        [string]$PackRole,
        $ModNames,
        $GuardMods,
        $Touchpoints,
        $RemoteInterfaces,
        $EventHooks,
        $TargetPrototypes,
        $RuntimeRefs,
        $PrototypeRefs,
        $PlanetOrSystem
    )

    $entry = [ordered]@{
        id           = ('{0}:{1}' -f ($RelativePath.ToLowerInvariant() -replace '[\\\/\.: ]+', '-'), $Category)
        category     = $Category
        phase        = $Phase
        direction    = $Direction
        mod_names    = ConvertTo-EsirSortedArray -Items $ModNames
        guard_mods   = ConvertTo-EsirSortedArray -Items $GuardMods
        source_files = @($RelativePath)
        touchpoints  = ConvertTo-EsirSortedArray -Items $Touchpoints
        purpose      = Get-EsirDependencyPurpose -Category $Category -RelativePath $RelativePath
    }

    if (-not [string]::IsNullOrWhiteSpace($PackRole)) {
        $entry.pack_role = $PackRole
    }
    if (-not [string]::IsNullOrWhiteSpace($SourcePack)) {
        $entry.source_pack = $SourcePack
    }

    $remoteInterfacesArray = ConvertTo-EsirSortedArray -Items $RemoteInterfaces
    if ($remoteInterfacesArray.Count -gt 0) {
        $entry.remote_interfaces = $remoteInterfacesArray
    }

    $eventHooksArray = ConvertTo-EsirSortedArray -Items $EventHooks
    if ($eventHooksArray.Count -gt 0) {
        $entry.event_hooks = $eventHooksArray
    }

    $targetPrototypesArray = ConvertTo-EsirSortedArray -Items $TargetPrototypes
    if ($targetPrototypesArray.Count -gt 0) {
        $entry.target_prototypes = $targetPrototypesArray
    }

    $runtimeRefsArray = ConvertTo-EsirSortedArray -Items $RuntimeRefs
    if ($runtimeRefsArray.Count -gt 0) {
        $entry.runtime_refs = $runtimeRefsArray
    }

    $prototypeRefsArray = ConvertTo-EsirSortedArray -Items $PrototypeRefs
    if ($prototypeRefsArray.Count -gt 0) {
        $entry.prototype_refs = $prototypeRefsArray
    }

    $planetOrSystemArray = ConvertTo-EsirSortedArray -Items $PlanetOrSystem
    if ($planetOrSystemArray.Count -gt 0) {
        $entry.planet_or_system = $planetOrSystemArray
    }

    return $entry
}

function Get-EsirDependencyTouchpointEntries {
    param([Parameter(Mandatory = $true)]$Paths)

    $packMaps = Get-EsirPackRoleMap -Paths $Paths
    $declaredDependencies = Get-EsirDeclaredDependencyEntries -Paths $Paths
    $planetMods = Get-EsirDependencyPlanetModSet -DeclaredDependencies $declaredDependencies
    $mediaPackMods = Get-EsirDependencyMediaPackSet -Paths $Paths
    $runtimeRefs = Get-EsirDependencyRuntimeRefLookup -Paths $Paths
    $prototypeRefs = Get-EsirDependencyPrototypeRefLookup -Paths $Paths

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($relativePath in (Get-EsirDependencyTouchpointFiles -Paths $Paths)) {
        $fullPath = Join-Path $Paths.repo_root $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }

        $phase = Get-EsirTouchpointPhase -RelativePath $relativePath
        $sourcePack = Get-EsirTouchpointSourcePack -RelativePath $relativePath
        $packRole = $packMaps.roles[$sourcePack]
        $content = Get-EsirTextContent -Path $fullPath
        $guardMods = Get-EsirGuardModsFromContent -Content $content
        $pathMods = Get-EsirExternalPathModsFromContent -Content $content
        $allRemoteInterfaces = Get-EsirRemoteInterfacesFromContent -Content $content
        $externalRemoteInterfaces = Get-EsirExternalRemoteInterfaces -RemoteInterfaces $allRemoteInterfaces
        $eventHooks = Get-EsirEventHooksFromContent -Content $content
        $targetPrototypes = Get-EsirTargetPrototypesFromContent -Content $content
        $touchpoints = Get-EsirTouchpointKinds -Content $content

        $allModNamesSet = New-EsirStringSet
        Add-EsirStringSetItems -Set $allModNamesSet -Items $guardMods
        Add-EsirStringSetItems -Set $allModNamesSet -Items $pathMods
        Add-EsirStringSetItems -Set $allModNamesSet -Items $externalRemoteInterfaces
        $allModNames = ConvertTo-EsirSortedArray -Items $allModNamesSet

        $planetNames = @()
        $nonPlanetNames = [System.Collections.Generic.List[string]]::new()
        foreach ($modName in $allModNames) {
            if ($planetMods.Contains($modName)) {
                $planetNames += $modName
                continue
            }
            if ($mediaPackMods.Contains($modName)) {
                continue
            }
            $nonPlanetNames.Add($modName) | Out-Null
        }

        $runtimeRefIds = if ($runtimeRefs.ContainsKey($relativePath)) { @($runtimeRefs[$relativePath]) } else { @() }
        $prototypeRefIds = if ($prototypeRefs.ContainsKey($relativePath)) { @($prototypeRefs[$relativePath]) } else { @() }

        if ($phase -eq 'runtime' -and $nonPlanetNames.Count -gt 0) {
            $entries.Add((New-EsirDependencyTouchpointEntry -Category 'runtime-integration' -Phase $phase -Direction 'bridge' -RelativePath $relativePath -SourcePack $sourcePack -PackRole $packRole -ModNames @($nonPlanetNames) -GuardMods $guardMods -Touchpoints $touchpoints -RemoteInterfaces $externalRemoteInterfaces -EventHooks $eventHooks -TargetPrototypes $targetPrototypes -RuntimeRefs $runtimeRefIds -PrototypeRefs $prototypeRefIds -PlanetOrSystem @())) | Out-Null
        }

        if ($phase -ne 'runtime' -and $nonPlanetNames.Count -gt 0) {
            $entries.Add((New-EsirDependencyTouchpointEntry -Category 'prototype-integration' -Phase $phase -Direction 'bridge' -RelativePath $relativePath -SourcePack $sourcePack -PackRole $packRole -ModNames @($nonPlanetNames) -GuardMods $guardMods -Touchpoints $touchpoints -RemoteInterfaces $externalRemoteInterfaces -EventHooks $eventHooks -TargetPrototypes $targetPrototypes -RuntimeRefs $runtimeRefIds -PrototypeRefs $prototypeRefIds -PlanetOrSystem @())) | Out-Null
        }

        if (@($planetNames).Count -gt 0) {
            $entries.Add((New-EsirDependencyTouchpointEntry -Category 'planet-content' -Phase $phase -Direction 'bridge' -RelativePath $relativePath -SourcePack $sourcePack -PackRole $packRole -ModNames $planetNames -GuardMods $guardMods -Touchpoints $touchpoints -RemoteInterfaces $externalRemoteInterfaces -EventHooks $eventHooks -TargetPrototypes $targetPrototypes -RuntimeRefs $runtimeRefIds -PrototypeRefs $prototypeRefIds -PlanetOrSystem $planetNames)) | Out-Null
        }

        $remoteModNamesSet = New-EsirStringSet
        Add-EsirStringSetItems -Set $remoteModNamesSet -Items $guardMods
        Add-EsirStringSetItems -Set $remoteModNamesSet -Items $externalRemoteInterfaces
        $remoteModNames = ConvertTo-EsirSortedArray -Items $remoteModNamesSet
        if ($externalRemoteInterfaces.Count -gt 0 -and $remoteModNames.Count -gt 0) {
            $entries.Add((New-EsirDependencyTouchpointEntry -Category 'remote-interface' -Phase $phase -Direction 'outbound' -RelativePath $relativePath -SourcePack $sourcePack -PackRole $packRole -ModNames $remoteModNames -GuardMods $guardMods -Touchpoints $touchpoints -RemoteInterfaces $externalRemoteInterfaces -EventHooks $eventHooks -TargetPrototypes $targetPrototypes -RuntimeRefs $runtimeRefIds -PrototypeRefs $prototypeRefIds -PlanetOrSystem @())) | Out-Null
        }
    }

    foreach ($pack in (ConvertTo-EsirArray (Get-EsirDependencyPackManifest -Paths $Paths).entries | Sort-Object folder, id)) {
        if ($pack.type -notin @('graphics-pack', 'soundtrack-pack')) {
            continue
        }

        $entries.Add([ordered]@{
            id           = ('{0}:media-pack' -f ([string]$pack.id).ToLowerInvariant())
            category     = 'media-pack'
            phase        = 'pack'
            direction    = 'pack'
            mod_names    = @([string]$pack.id)
            guard_mods   = @()
            source_files = @([string]$pack.info_json)
            touchpoints  = @('info.json', 'pack-manifest')
            purpose      = [string]$pack.role
            pack_role    = [string]$pack.role
            source_pack  = [string]$pack.id
        }) | Out-Null
    }

    return ,@($entries | Sort-Object id)
}

function Get-EsirDependencyCatalogData {
    param([Parameter(Mandatory = $true)]$Paths)

    return [ordered]@{
        schema_version        = 1
        generated_at          = $null
        repo_root             = $Paths.repo_root
        source_manifests      = [ordered]@{
            runtime_modules = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.runtime_manifest_path
            prototype_index = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.prototype_index_path
            pack_manifest   = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.pack_manifest_path
        }
        declared_dependencies = ConvertTo-EsirArray (Get-EsirDeclaredDependencyEntries -Paths $Paths)
        touchpoints           = ConvertTo-EsirArray (Get-EsirDependencyTouchpointEntries -Paths $Paths)
    }
}

function Get-EsirDependencyCatalogCounts {
    param([Parameter(Mandatory = $true)]$Catalog)

    return [ordered]@{
        declared_dependencies = @(ConvertTo-EsirArray $Catalog.declared_dependencies).Count
        touchpoints           = @(ConvertTo-EsirArray $Catalog.touchpoints).Count
    }
}

function Invoke-EsirDependencyRefresh {
    param([Parameter(Mandatory = $true)]$Paths)

    $catalog = Get-EsirDependencyCatalogData -Paths $Paths
    Write-EsirJson -Path $Paths.dependency_catalog_path -Data $catalog

    return [ordered]@{
        task           = 'dependency-refresh'
        overall_status = 'ok'
        catalog_path   = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.dependency_catalog_path
        counts         = Get-EsirDependencyCatalogCounts -Catalog $catalog
    }
}

function Get-EsirDependencyQueryCatalog {
    param([Parameter(Mandatory = $true)]$Paths)

    $catalog = Read-EsirJson -Path $Paths.dependency_catalog_path
    if (-not $catalog) {
        $catalog = Get-EsirDependencyCatalogData -Paths $Paths
    }

    return $catalog
}

function Test-EsirDependencyDeclaredMatch {
    param(
        $Entry,
        [string]$ModName,
        [string]$Pack,
        [string]$PathFilter
    )

    if (-not (Get-EsirDependencyMatches -Needle $ModName -Haystacks @($Entry.mod_name))) {
        return $false
    }
    if (-not (Get-EsirDependencyMatches -Needle $Pack -Haystacks @($Entry.declared_by_pack, $Entry.pack_role))) {
        return $false
    }
    if (-not (Get-EsirDependencyMatches -Needle $PathFilter -Haystacks @($Entry.declared_in))) {
        return $false
    }

    return $true
}

function Test-EsirDependencyTouchpointMatch {
    param(
        $Entry,
        [string]$ModName,
        [string]$Pack,
        [string]$PathFilter,
        [string[]]$Categories
    )

    $remoteInterfaces = @()
    if ($Entry.PSObject.Properties.Name -contains 'remote_interfaces') {
        $remoteInterfaces = @($Entry.remote_interfaces)
    }

    if ($Categories -notcontains [string]$Entry.category) {
        return $false
    }
    if (-not (Get-EsirDependencyMatches -Needle $ModName -Haystacks (@($Entry.mod_names) + @($Entry.guard_mods) + $remoteInterfaces))) {
        return $false
    }
    if (-not (Get-EsirDependencyMatches -Needle $Pack -Haystacks @($Entry.source_pack, $Entry.pack_role))) {
        return $false
    }
    if (-not (Get-EsirDependencyMatches -Needle $PathFilter -Haystacks @($Entry.source_files))) {
        return $false
    }

    return $true
}

function Get-EsirInstalledModRoots {
    param([Parameter(Mandatory = $true)]$Paths)

    $roots = [System.Collections.Generic.List[string]]::new()
    foreach ($root in @(
        (Join-Path $env:APPDATA 'Factorio\mods'),
        (Join-Path $Paths.repo_root 'output\tesla-run-mods'),
        (Join-Path $Paths.repo_root '.factorio-qc\mods-preview'),
        (Join-Path $Paths.repo_root '.factorio-qc\fmqc\mods-live'),
        (Join-Path $Paths.repo_root '.factorio-qc\mods-live')
    )) {
        if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-Path -LiteralPath $root)) {
            $roots.Add($root) | Out-Null
        }
    }

    return ,@($roots | Sort-Object -Unique)
}

function Get-EsirInstalledModFallbackName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $match = [regex]::Match($Name, '^(?<name>.+?)(?:_(?<version>\d+\.\d+\.\d+(?:\.[^\\\/]+)?))?$')
    if ($match.Success) {
        return [pscustomobject]@{
            mod_name = $match.Groups['name'].Value
            version  = if ($match.Groups['version'].Success) { $match.Groups['version'].Value } else { $null }
        }
    }

    return [pscustomobject]@{
        mod_name = $Name
        version  = $null
    }
}

function New-EsirInstalledDirectoryRecord {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $infoPath = Join-Path $Item.FullName 'info.json'
    $fallback = Get-EsirInstalledModFallbackName -Name $Item.Name
    $modName = [string]$fallback.mod_name
    $version = $fallback.version

    if (Test-Path -LiteralPath $infoPath) {
        try {
            $info = Get-EsirTextContent -Path $infoPath | ConvertFrom-Json
            if ($info.name) { $modName = [string]$info.name }
            if ($info.version) { $version = [string]$info.version }
        } catch {
        }
    }

    $keyFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($pair in @(
        @{ key = 'control.lua'; value = (Join-Path $Item.FullName 'control.lua') },
        @{ key = 'data.lua'; value = (Join-Path $Item.FullName 'data.lua') },
        @{ key = 'data-updates.lua'; value = (Join-Path $Item.FullName 'data-updates.lua') },
        @{ key = 'data-final-fixes.lua'; value = (Join-Path $Item.FullName 'data-final-fixes.lua') }
    )) {
        if (Test-Path -LiteralPath $pair.value) {
            $keyFiles.Add($pair.key) | Out-Null
        }
    }

    if (Test-Path -LiteralPath (Join-Path $Item.FullName 'scripts\control')) { $keyFiles.Add('scripts/control') | Out-Null }
    if (Test-Path -LiteralPath (Join-Path $Item.FullName 'prototypes')) { $keyFiles.Add('prototypes') | Out-Null }

    return [ordered]@{
        mod_name             = $modName
        root                 = $Root
        path                 = $Item.FullName
        version              = $version
        has_control          = (Test-Path -LiteralPath (Join-Path $Item.FullName 'control.lua'))
        has_data             = (Test-Path -LiteralPath (Join-Path $Item.FullName 'data.lua'))
        has_prototypes       = (Test-Path -LiteralPath (Join-Path $Item.FullName 'prototypes'))
        has_data_updates     = (Test-Path -LiteralPath (Join-Path $Item.FullName 'data-updates.lua'))
        has_data_final_fixes = (Test-Path -LiteralPath (Join-Path $Item.FullName 'data-final-fixes.lua'))
        key_files            = @($keyFiles | Sort-Object -Unique)
    }
}

function New-EsirInstalledZipRecord {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$Root
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Item.FullName)
    try {
        $fallback = Get-EsirInstalledModFallbackName -Name $Item.BaseName
        $modName = [string]$fallback.mod_name
        $version = $fallback.version

        $infoEntry = $archive.Entries | Where-Object { $_.FullName -match '(^|/)[^/]+/info\.json$|^info\.json$' } | Select-Object -First 1
        if ($infoEntry) {
            try {
                $reader = [System.IO.StreamReader]::new($infoEntry.Open(), [System.Text.UTF8Encoding]::new($false), $true)
                try {
                    $info = ($reader.ReadToEnd() | ConvertFrom-Json)
                    if ($info.name) { $modName = [string]$info.name }
                    if ($info.version) { $version = [string]$info.version }
                } finally {
                    $reader.Dispose()
                }
            } catch {
            }
        }

        $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('/', '\') })
        $keyFiles = [System.Collections.Generic.List[string]]::new()
        foreach ($candidate in @('control.lua', 'data.lua', 'data-updates.lua', 'data-final-fixes.lua')) {
            if ($names | Where-Object { $_ -match ("(^|\\)" + [regex]::Escape($candidate) + '$') } | Select-Object -First 1) {
                $keyFiles.Add($candidate) | Out-Null
            }
        }
        if ($names | Where-Object { $_ -match '(^|\\)scripts\\control\\' } | Select-Object -First 1) { $keyFiles.Add('scripts/control') | Out-Null }
        if ($names | Where-Object { $_ -match '(^|\\)prototypes\\' } | Select-Object -First 1) { $keyFiles.Add('prototypes') | Out-Null }

        return [ordered]@{
            mod_name             = $modName
            root                 = $Root
            path                 = $Item.FullName
            version              = $version
            has_control          = [bool]($names | Where-Object { $_ -match '(^|\\)control\.lua$' } | Select-Object -First 1)
            has_data             = [bool]($names | Where-Object { $_ -match '(^|\\)data\.lua$' } | Select-Object -First 1)
            has_prototypes       = [bool]($names | Where-Object { $_ -match '(^|\\)prototypes\\' } | Select-Object -First 1)
            has_data_updates     = [bool]($names | Where-Object { $_ -match '(^|\\)data-updates\.lua$' } | Select-Object -First 1)
            has_data_final_fixes = [bool]($names | Where-Object { $_ -match '(^|\\)data-final-fixes\.lua$' } | Select-Object -First 1)
            key_files            = @($keyFiles | Sort-Object -Unique)
        }
    } finally {
        $archive.Dispose()
    }
}

function Get-EsirInstalledModPresence {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        $ModNames
    )

    $wanted = New-EsirStringSet
    Add-EsirStringSetItems -Set $wanted -Items $ModNames
    if ($wanted.Count -eq 0) {
        return ,@()
    }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($root in (Get-EsirInstalledModRoots -Paths $Paths)) {
        foreach ($item in (Get-ChildItem -LiteralPath $root -Force | Sort-Object Name)) {
            $nameProbe = if ($item.PSIsContainer) { $item.Name } elseif ($item.Extension -ieq '.zip') { $item.BaseName } else { $item.Name }
            $fallback = Get-EsirInstalledModFallbackName -Name $nameProbe
            if (-not $wanted.Contains([string]$fallback.mod_name)) {
                continue
            }

            $record = $null
            if ($item.PSIsContainer) {
                $record = New-EsirInstalledDirectoryRecord -Item $item -Root $root
            } elseif ($item.Extension -ieq '.zip') {
                $record = New-EsirInstalledZipRecord -Item $item -Root $root
            }

            if ($null -eq $record) { continue }
            if (-not $wanted.Contains([string]$record.mod_name)) { continue }
            $records.Add($record) | Out-Null
        }
    }

    return ,@($records | Sort-Object mod_name, root, path)
}

function Invoke-EsirDependencyQuery {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [ValidateSet('declared', 'touchpoints', 'all')][string]$Scope = 'all',
        [ValidateSet('runtime', 'prototype', 'planet', 'remote', 'media', 'all')][string]$Category = 'all',
        [string]$ModName,
        [string]$Pack,
        [string]$PathFilter,
        [switch]$ResolveInstalled
    )

    $catalog = Get-EsirDependencyQueryCatalog -Paths $Paths
    $categories = Get-EsirDependencyCategoryFilter -Category $Category
    $declared = @()
    $touchpoints = @()

    if ($Scope -in @('declared', 'all')) {
        $declared = @(ConvertTo-EsirArray $catalog.declared_dependencies | Where-Object {
            Test-EsirDependencyDeclaredMatch -Entry $_ -ModName $ModName -Pack $Pack -PathFilter $PathFilter
        } | Sort-Object declared_by_pack, mod_name, dependency_kind, constraint, declared_in)
    }

    if ($Scope -in @('touchpoints', 'all')) {
        $touchpoints = @(ConvertTo-EsirArray $catalog.touchpoints | Where-Object {
            Test-EsirDependencyTouchpointMatch -Entry $_ -ModName $ModName -Pack $Pack -PathFilter $PathFilter -Categories $categories
        } | Sort-Object id)
    }

    $installed = @()
    if ($ResolveInstalled) {
        $wanted = New-EsirStringSet
        Add-EsirStringSetItems -Set $wanted -Items $ModName
        Add-EsirStringSetItems -Set $wanted -Items ($declared | ForEach-Object { $_.mod_name })
        Add-EsirStringSetItems -Set $wanted -Items ($touchpoints | ForEach-Object { @($_.mod_names) + @($_.guard_mods) })
        $installed = ConvertTo-EsirArray (Get-EsirInstalledModPresence -Paths $Paths -ModNames $wanted)
    }

    $overallStatus = if ($declared.Count -eq 0 -and $touchpoints.Count -eq 0 -and $installed.Count -eq 0) { 'warning' } else { 'ok' }
    return [ordered]@{
        task                  = 'dependency-query'
        overall_status        = $overallStatus
        scope                 = $Scope
        category              = $Category
        mod_name              = $ModName
        pack                  = $Pack
        path                  = $PathFilter
        resolve_installed     = [bool]$ResolveInstalled
        catalog_path          = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.dependency_catalog_path
        declared_dependencies = $declared
        touchpoints           = $touchpoints
        installed_mods        = $installed
        counts                = [ordered]@{
            declared_dependencies = $declared.Count
            touchpoints           = $touchpoints.Count
            installed_mods        = $installed.Count
        }
    }
}

function Invoke-EsirDependencyDiff {
    param(
        [Parameter(Mandatory = $true)]$Paths,
        [switch]$Strict
    )

    $fresh = Get-EsirDependencyCatalogData -Paths $Paths
    $stored = Read-EsirJson -Path $Paths.dependency_catalog_path
    $freshJson = $fresh | ConvertTo-Json -Depth 32 -Compress
    $storedJson = if ($stored) { $stored | ConvertTo-Json -Depth 32 -Compress } else { '' }
    $changed = ($freshJson -ne $storedJson)

    $overallStatus = 'ok'
    if ($changed) {
        if ($Strict) {
            $overallStatus = 'failed'
        } else {
            $overallStatus = 'warning'
        }
    }

    return [ordered]@{
        task           = 'dependency-diff'
        overall_status = $overallStatus
        changed        = $changed
        reason         = if (-not $stored) { 'dependency catalog missing' } elseif ($changed) { 'checked-in dependency catalog drift detected' } else { 'checked-in dependency catalog matches fresh generation' }
        catalog_path   = Get-RelativeRepoPath -RepoRoot $Paths.repo_root -Path $Paths.dependency_catalog_path
        stored_counts  = if ($stored) { Get-EsirDependencyCatalogCounts -Catalog $stored } else { $null }
        fresh_counts   = Get-EsirDependencyCatalogCounts -Catalog $fresh
    }
}

function Invoke-EsirDependencyTask {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('refresh', 'query', 'diff')][string]$Task,
        [Parameter(Mandatory = $true)]$Paths,
        [ValidateSet('declared', 'touchpoints', 'all')][string]$Scope = 'all',
        [ValidateSet('runtime', 'prototype', 'planet', 'remote', 'media', 'all')][string]$Category = 'all',
        [string]$ModName,
        [string]$Pack,
        [string]$PathFilter,
        [switch]$ResolveInstalled,
        [switch]$Strict
    )

    switch ($Task) {
        'refresh' { return Invoke-EsirDependencyRefresh -Paths $Paths }
        'query' { return Invoke-EsirDependencyQuery -Paths $Paths -Scope $Scope -Category $Category -ModName $ModName -Pack $Pack -PathFilter $PathFilter -ResolveInstalled:$ResolveInstalled }
        'diff' { return Invoke-EsirDependencyDiff -Paths $Paths -Strict:$Strict }
    }
}
