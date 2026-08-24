[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('doctor', 'manifest-refresh', 'dependency-refresh', 'dependency-query', 'dependency-diff', 'preflight', 'qc-fast', 'qc-runtime', 'qc-preview', 'qc-gaia-resources', 'qc-assets', 'qc-package', 'qc-full', 'runtime-benchmark', 'portal-scout', 'diff', 'art-start', 'art-collect', 'art-review', 'art-validate', 'pack-dryrun', 'pack-deploy', 'full')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
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
    [ValidateSet('declared', 'touchpoints', 'all')]
    [string]$Scope = 'all',
    [ValidateSet('runtime', 'prototype', 'planet', 'remote', 'media', 'all')]
    [string]$Category = 'all',
    [string]$ModName,
    [string]$Path,
    [string]$PromptText,
    [string]$PromptFile,
    [string]$SessionName,
    [string]$DownloadsPath,
    [string]$FactorioPath,
    [switch]$Strict,
    [switch]$ResolveInstalled,
    [switch]$FixEncoding,
    [switch]$AsJson,
    [switch]$SkipBrowser,
    [switch]$SkipClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')

$writeTasks = @(
    'manifest-refresh',
    'preflight',
    'qc-fast',
    'qc-runtime',
    'qc-preview',
    'qc-gaia-resources',
    'qc-assets',
    'qc-package',
    'qc-full',
    'runtime-benchmark',
    'portal-scout',
    'art-start',
    'art-collect',
    'art-review',
    'art-validate',
    'pack-dryrun',
    'pack-deploy',
    'full'
)
$paths = Get-EsirPaths -RepoRoot $RepoRoot -EnsureWritableDirs:($Task -in $writeTasks)
$result = Invoke-EsirTask -Task $Task -Paths $paths -SaveId $SaveId -SavePath $SavePath -WarmupRuns $WarmupRuns -BenchmarkRuns $BenchmarkRuns -BenchmarkTicks $BenchmarkTicks -Seed $Seed -Seeds $Seeds -PreviewSize $PreviewSize -Planet $Planet -Pack $Pack -DependencyScope $Scope -DependencyCategory $Category -ModName $ModName -TargetPath $Path -PromptText $PromptText -PromptFile $PromptFile -SessionName $SessionName -DownloadsPath $DownloadsPath -FactorioPath $FactorioPath -Strict:$Strict -ResolveInstalled:$ResolveInstalled -FixEncoding:$FixEncoding -SkipBrowser:$SkipBrowser -SkipClipboard:$SkipClipboard

if ($AsJson) {
    $result | ConvertTo-Json -Depth 16
} else {
    Write-Host "ESIR Dev"
    Write-Host "Repo: $($paths.repo_root)"
    Write-Host "Task: $Task"
    Write-Host "Overall: $($result.overall_status)"
    if ($result.PSObject.Properties.Name -contains 'helper_requirements' -and $result.helper_requirements) {
        $helperWarnings = @($result.helper_requirements.warnings | Where-Object { $_ })
        if ($helperWarnings.Count -gt 0) {
            foreach ($warning in $helperWarnings) {
                Write-Host "Helper: $warning"
            }
        } elseif (@($result.helper_requirements.items).Count -gt 0) {
            Write-Host "Helper: save-backed helper requirements detected; see helper_requirements in the JSON output."
        }
    }
    $result | ConvertTo-Json -Depth 16
}

if ($result.overall_status -eq 'failed') {
    exit 1
}

exit 0
