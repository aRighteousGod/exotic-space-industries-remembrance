[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('test-list', 'test-plan', 'qc-test', 'qc-quick', 'qc-targeted', 'doctor', 'housekeeping', 'manifest-refresh', 'dependency-refresh', 'dependency-query', 'dependency-diff', 'preflight', 'qc-fast', 'qc-runtime', 'qc-preview', 'qc-gaia-resources', 'qc-assets', 'qc-package', 'qc-full', 'runtime-benchmark', 'portal-scout', 'portal-plan', 'portal-capture', 'portal-render', 'portal-validate', 'portal-page', 'diff', 'art-start', 'art-collect', 'art-review', 'art-validate', 'pack-dryrun', 'pack-deploy', 'full')]
    [string]$Task,
    [string]$RepoRoot = (Get-Location).Path,
    [string]$SaveId,
    [string]$SavePath,
    [string[]]$Suite = @(),
    [string[]]$Case = @(),
    [string[]]$TestProfile = @(),
    [ValidateSet('core','extended')][string]$TestTier = 'core',
    [string]$ChangedSince,
    [string[]]$ChangedPath,
    [switch]$PlanOnly,
    [ValidateSet('requested','gaia-acceptance')][string]$PreviewScope,
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
    [switch]$Apply,
    [switch]$FullInventory,
    [switch]$IncludeCodexHome,
    [string[]]$CloseRunId = @(),
    [switch]$SkipBrowser,
    [switch]$SkipClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Task -in @('test-list','test-plan','qc-test','qc-quick','qc-targeted')) {
    $scoped = $Task -in @('qc-quick','qc-targeted')
    $nativeParameters=@('Task','RepoRoot','Suite','Case','TestProfile','TestTier','ChangedSince','ChangedPath','FactorioPath','AsJson')
    if ($scoped) { $nativeParameters+=@('PlanOnly','Strict') }
    foreach ($parameter in $PSBoundParameters.Keys) {
        if ($parameter -notin $nativeParameters) { throw "Parameter -$parameter is not supported by native test tasks." }
    }
    $entry = if ($scoped) { 'qc/native-tests/workflows.py' } else { 'qc/native-tests/runner.py' }
    $nativeArgs=@('-X','utf8','-B',(Join-Path $PSScriptRoot $entry),$Task,'--repo',$RepoRoot,'--tier',$TestTier)
    foreach ($item in $Suite) { foreach($value in $item.Split(',')){ $nativeArgs+=@('--suite',$value) } }
    foreach ($item in $Case) { foreach($value in $item.Split(',')){ $nativeArgs+=@('--case',$value) } }
    foreach ($item in $TestProfile) { foreach($value in $item.Split(',')){ $nativeArgs+=@('--profile',$value) } }
    if ($ChangedSince) { $nativeArgs+=@('--changed-since',$ChangedSince) }
    if ($PSBoundParameters.ContainsKey('ChangedPath')) {
        if (-not $ChangedPath.Count) { throw '-ChangedPath cannot be empty.' }
        foreach ($item in $ChangedPath) { $nativeArgs+=@('--changed-path',$item) }
    }
    if ($PlanOnly) { $nativeArgs+='--plan-only' }
    if ($Strict) { $nativeArgs+='--strict' }
    if ($FactorioPath) { $nativeArgs+=@('--engine',$FactorioPath) }
    & python @nativeArgs
    exit $LASTEXITCODE
}
if ($Suite.Count -or $Case.Count -or $TestProfile.Count -or $ChangedSince -or $PSBoundParameters.ContainsKey('TestTier') -or $PSBoundParameters.ContainsKey('ChangedPath') -or $PlanOnly) {
    throw 'Test selectors require test-list, test-plan, qc-test, qc-quick or qc-targeted; PlanOnly requires a scoped QC task.'
}
if ($PreviewScope -and $Task -notin @('qc-preview','qc-full','full')) { throw '-PreviewScope requires qc-preview or an explicit full task.' }
if ($Task -in @('qc-full','full') -and $PreviewScope -eq 'requested') { throw 'Full QC always requires Gaia acceptance; use qc-preview for a requested preview alone.' }

if ($Task -in @('portal-plan','portal-capture','portal-render','portal-validate','portal-page')) {
    $batch = if ($Path) { $Path } else { 'portal/batches/001-pilots.json' }
    & python -B (Join-Path $PSScriptRoot 'portal-media/portal_media.py') $Task.Substring(7) --batch $batch
    exit $LASTEXITCODE
}

if ($Task -ne 'housekeeping' -and ($Apply -or $FullInventory -or $IncludeCodexHome -or $CloseRunId.Count)) {
    throw 'Housekeeping switches require -Task housekeeping.'
}

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
$result = Invoke-EsirTask -Task $Task -Paths $paths -SaveId $SaveId -SavePath $SavePath -WarmupRuns $WarmupRuns -BenchmarkRuns $BenchmarkRuns -BenchmarkTicks $BenchmarkTicks -Seed $Seed -Seeds $Seeds -PreviewSize $PreviewSize -Planet $Planet -PreviewScope $PreviewScope -Pack $Pack -DependencyScope $Scope -DependencyCategory $Category -ModName $ModName -TargetPath $Path -PromptText $PromptText -PromptFile $PromptFile -SessionName $SessionName -DownloadsPath $DownloadsPath -FactorioPath $FactorioPath -Strict:$Strict -ResolveInstalled:$ResolveInstalled -FixEncoding:$FixEncoding -SkipBrowser:$SkipBrowser -SkipClipboard:$SkipClipboard -Apply:$Apply -FullInventory:$FullInventory -IncludeCodexHome:$IncludeCodexHome -CloseRunId $CloseRunId

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
