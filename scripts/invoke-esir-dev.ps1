[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('doctor', 'manifest-refresh', 'preflight', 'qc-fast', 'qc-runtime', 'qc-preview', 'qc-assets', 'qc-package', 'qc-full', 'runtime-benchmark', 'portal-scout', 'diff', 'art-start', 'art-collect', 'art-review', 'art-validate', 'pack-dryrun', 'pack-deploy', 'full')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
    [string]$SaveId,
    [string]$SavePath,
    [Nullable[int]]$WarmupRuns,
    [Nullable[int]]$BenchmarkRuns,
    [Nullable[int]]$BenchmarkTicks,
    [Nullable[int]]$Seed,
    [string]$Planet,
    [string]$Pack,
    [string]$PromptText,
    [string]$PromptFile,
    [string]$SessionName,
    [string]$DownloadsPath,
    [string]$FactorioPath,
    [switch]$Strict,
    [switch]$FixEncoding,
    [switch]$AsJson,
    [switch]$SkipBrowser,
    [switch]$SkipClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')

$paths = Get-EsirPaths -RepoRoot $RepoRoot
$result = Invoke-EsirTask -Task $Task -Paths $paths -SaveId $SaveId -SavePath $SavePath -WarmupRuns $WarmupRuns -BenchmarkRuns $BenchmarkRuns -BenchmarkTicks $BenchmarkTicks -Seed $Seed -Planet $Planet -Pack $Pack -PromptText $PromptText -PromptFile $PromptFile -SessionName $SessionName -DownloadsPath $DownloadsPath -FactorioPath $FactorioPath -Strict:$Strict -FixEncoding:$FixEncoding -SkipBrowser:$SkipBrowser -SkipClipboard:$SkipClipboard

if ($AsJson) {
    $result | ConvertTo-Json -Depth 16
} else {
    Write-Host "ESIR Dev"
    Write-Host "Repo: $($paths.repo_root)"
    Write-Host "Task: $Task"
    Write-Host "Overall: $($result.overall_status)"
    $result | ConvertTo-Json -Depth 16
}

if ($result.overall_status -eq 'failed') {
    exit 1
}

exit 0
