[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('refresh', 'query')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
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

$paths = Get-FactorioLuaDocsPaths -RepoRoot $RepoRoot -EnsureCacheRoot:($Task -eq 'refresh')
$result = switch ($Task) {
    'refresh' { Invoke-FactorioLuaDocsRefresh -Paths $paths }
    'query' { Invoke-FactorioLuaDocsQuery -Paths $paths -Query $Query -Stage $Stage -Kind $Kind -ExactName $ExactName -Limit $Limit -RefreshIfMissing:$RefreshIfMissing }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 32
} else {
    Write-Host 'Factorio Lua Docs'
    Write-Host "Repo: $($paths.repo_root)"
    Write-Host "Task: $Task"
    Write-Host "Overall: $($result.overall_status)"
    $result | ConvertTo-Json -Depth 32
}

if ($result.overall_status -eq 'failed') {
    exit 1
}

exit 0
