[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')

function ConvertTo-HeaderList {
    param($Value)

    $items = @($Value | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if ($items.Count -eq 0) {
        return 'none'
    }
    return ($items -join ', ')
}

function Remove-ExistingHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Prefix
    )

    $escaped = [regex]::Escape($Prefix)
    $pattern = "(?s)^${escaped}=+\r?\n${escaped} ESIR FILE MAP\r?\n.*?${escaped}=+\r?\n\r?\n?"
    return ([regex]::Replace($Content, $pattern, ''))
}

function Set-HeaderContent {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][hashtable]$Metadata
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $trimmed = if ([string]::IsNullOrEmpty($content)) { '' } else { Remove-ExistingHeader -Content $content -Prefix $Prefix }
    $header = @(
        ('{0}==============================================================================' -f $Prefix)
        ('{0} ESIR FILE MAP' -f $Prefix)
        ('{0} owns: {1}' -f $Prefix, $Metadata.owns)
        ('{0} loaded_by: {1}' -f $Prefix, $Metadata.loaded_by)
        ('{0} cadence: {1}' -f $Prefix, $Metadata.cadence)
        ('{0} forwarded_events: {1}' -f $Prefix, (ConvertTo-HeaderList $Metadata.forwarded_events))
        ('{0} storage_roots: {1}' -f $Prefix, (ConvertTo-HeaderList $Metadata.storage_roots))
        ('{0} gui_ids: {1}' -f $Prefix, (ConvertTo-HeaderList $Metadata.gui_ids))
        ('{0} remote_interfaces: {1}' -f $Prefix, (ConvertTo-HeaderList $Metadata.remote_interfaces))
        ('{0} rebuild_on: {1}' -f $Prefix, (ConvertTo-HeaderList $Metadata.rebuild_on))
        ('{0}==============================================================================' -f $Prefix)
        ''
    ) -join [Environment]::NewLine

    [System.IO.File]::WriteAllText($FilePath, $header + $trimmed)
}

$paths = Get-EsirPaths -RepoRoot $RepoRoot -EnsureWritableDirs
Invoke-EsirManifestRefresh -Paths $paths | Out-Null

$runtimeManifest = Read-EsirJson -Path $paths.runtime_manifest_path
foreach ($entry in @($runtimeManifest.entries)) {
    $filePath = Join-Path $paths.repo_root $entry.path
    if (-not (Test-Path -LiteralPath $filePath)) { continue }
    Set-HeaderContent -FilePath $filePath -Prefix '--' -Metadata @{
        owns              = $entry.owns
        loaded_by         = $entry.loaded_by
        cadence           = $entry.cadence
        forwarded_events  = $entry.events
        storage_roots     = $entry.storage_roots
        gui_ids           = $entry.gui_ids
        remote_interfaces = $entry.remote_interfaces
        rebuild_on        = $entry.rebuild_on
    }
}

$prototypeIndex = Read-EsirJson -Path $paths.prototype_index_path
foreach ($entry in @($prototypeIndex.direct_requires)) {
    if (-not ($entry.path -like 'exotic-space-industries-remembrance\prototypes\*' -or $entry.path -eq 'exotic-space-industries-remembrance\teslas_legacy\data.lua')) {
        continue
    }
    $filePath = Join-Path $paths.repo_root $entry.path
    if (-not (Test-Path -LiteralPath $filePath)) { continue }
    Set-HeaderContent -FilePath $filePath -Prefix '--' -Metadata @{
        owns              = 'data-stage prototype aggregation for ' + ([System.IO.Path]::GetFileNameWithoutExtension($entry.path))
        loaded_by         = $entry.loaded_by
        cadence           = 'data-stage load'
        forwarded_events  = @()
        storage_roots     = @()
        gui_ids           = @()
        remote_interfaces = @()
        rebuild_on        = @('data stage reload', 'prototype cache rebuild')
    }
}

$packManifest = Read-EsirJson -Path $paths.pack_manifest_path
foreach ($entry in @($packManifest.entries)) {
    if (-not $entry.deploy_script) { continue }
    $filePath = Join-Path $paths.repo_root $entry.deploy_script
    if (-not (Test-Path -LiteralPath $filePath)) { continue }
    Set-HeaderContent -FilePath $filePath -Prefix '#' -Metadata @{
        owns              = 'legacy pack deploy wrapper for ' + $entry.folder
        loaded_by         = 'manual invocation or scripts\invoke-esir-dev.ps1 -Task pack-deploy'
        cadence           = 'manual packaging and deployment'
        forwarded_events  = @()
        storage_roots     = @()
        gui_ids           = @()
        remote_interfaces = @()
        rebuild_on        = @('pack version changes', 'packaging layout changes')
    }
}

Write-Host 'ESIR headers synchronized.'
