[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('refresh', 'query', 'diff')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
    [ValidateSet('declared', 'touchpoints', 'all')]
    [string]$Scope = 'all',
    [ValidateSet('runtime', 'prototype', 'planet', 'remote', 'media', 'all')]
    [string]$Category = 'all',
    [string]$ModName,
    [string]$Pack,
    [string]$Path,
    [switch]$ResolveInstalled,
    [switch]$Strict,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')

$paths = Get-EsirPaths -RepoRoot $RepoRoot
$result = Invoke-EsirDependencyTask -Task $Task -Paths $paths -Scope $Scope -Category $Category -ModName $ModName -Pack $Pack -PathFilter $Path -ResolveInstalled:$ResolveInstalled -Strict:$Strict

if ($AsJson) {
    $result | ConvertTo-Json -Depth 32
} else {
    Write-Host 'ESIR Dependency Intel'
    Write-Host "Repo: $($paths.repo_root)"
    Write-Host "Task: $Task"
    Write-Host "Overall: $($result.overall_status)"
    $result | ConvertTo-Json -Depth 32
}

if ($result.overall_status -eq 'failed') {
    exit 1
}

exit 0
