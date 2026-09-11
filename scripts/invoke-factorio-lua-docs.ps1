[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('refresh', 'query', 'status')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
    [ValidateSet('installed', 'hosted')]
    [string]$Source = 'installed',
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '2.0.77',
    [string]$DocsRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html',
    [string]$Query,
    [ValidateSet('runtime', 'prototype', 'auxiliary', 'wiki', 'all')]
    [string]$Stage = 'all',
    [ValidateSet('class', 'method', 'attribute', 'operator', 'event', 'concept', 'concept-property', 'define', 'define-value', 'global-object', 'global-function', 'prototype', 'prototype-property', 'type', 'type-property', 'topic', 'all')]
    [string]$Kind = 'all',
    [string]$ExactName,
    [ValidateRange(1, 100)]
    [int]$Limit = 12,
    [switch]$RefreshIfMissing,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'factorio-lua-docs-lib.ps1')

if ($Source -eq 'hosted' -and $PSBoundParameters.ContainsKey('DocsRoot')) {
    throw '-DocsRoot is only compatible with -Source installed.'
}

$paths = Get-FactorioLuaDocsPaths -RepoRoot $RepoRoot -Source $Source -Version $Version -DocsRoot $DocsRoot
$result = switch ($Task) {
    'refresh' { Invoke-FactorioLuaDocsRefresh -Paths $paths }
    'query' { Invoke-FactorioLuaDocsQuery -Paths $paths -Query $Query -Stage $Stage -Kind $Kind -ExactName $ExactName -Limit $Limit -RefreshIfMissing:$RefreshIfMissing }
    'status' { Get-FactorioLuaDocsStatus -Paths $paths }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 32
} else {
    Write-Host 'Factorio Lua Docs'
    Write-Host "Repo: $($paths.repo_root)"
    Write-Host "Source: $Source"
    Write-Host "Version: $Version"
    Write-Host "Task: $Task"
    Write-Host "Overall: $($result.overall_status)"
    $result | ConvertTo-Json -Depth 32
}

if ($result.overall_status -eq 'failed') {
    exit 1
}

exit 0
