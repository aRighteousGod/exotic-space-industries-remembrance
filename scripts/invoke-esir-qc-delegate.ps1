# Same installed QC engine, with an invocation-owned output root and completion token.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('fast', 'runtime', 'preview', 'assets', 'package', 'full')][string]$Mode,
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ArtifactRoot,
    [Parameter(Mandatory)][string]$RunId,
    [string]$Save, [Nullable[int]]$Seed, [string]$Planet, [string]$FactorioPath, [switch]$Strict
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
$paths = Get-EsirPaths -RepoRoot $RepoRoot
$context = Get-EsirQcContext -Paths $paths -FactorioPath $FactorioPath -EnsureArtifactRoot
$run = Read-EsirArtifactRun $RepoRoot $RunId
$ownedRoot = Assert-EsirArtifactTarget $RepoRoot $run.payload_path
if ($run.status -ne 'running' -or $run.workflow -ne ('qc-' + $Mode) -or $ownedRoot -ne [IO.Path]::GetFullPath($ArtifactRoot)) { throw 'QC invocation does not match its artifact owner.' }
[void](Initialize-EsirManagedQcContext -RepoRoot $RepoRoot -Context $context -RunId $RunId -SourceMode read-only)
$context | Add-Member -NotePropertyName preview_companion -NotePropertyValue (Get-Command Invoke-EsirGaiaPreviewCompanion).ScriptBlock
if ($Mode -in @('runtime','preview','full')) {
    $selection = Resolve-EsirSaveSelection -Paths $paths -TaskName ('qc-'+$Mode) -SavePath $Save
    $helpers = Get-EsirSaveHelperSummary -Paths $paths -SaveSelection $selection -TaskName ('qc-'+$Mode) -AllowAutoStage
    Set-EsirRequiredSaveHelpers -Paths $paths -Context $context -HelperSummary $helpers
}
# The store owns a short physical mod view. No extra junction into evidence is
# needed, and large engine output can independently overflow to D:.
$results = @()
$modes = if ($Mode -eq 'full') { @('fast', 'runtime', 'preview', 'assets', 'package') } else { @($Mode) }
try {
    foreach ($part in $modes) {
        $results += switch ($part) {
            'fast' {
                $fast = Invoke-FactorioFastQC -Context $context -Strict:$Strict
                if ($fast.status -ne 'failed') { Invoke-EsirFinalDataContracts -Context $context -Result $fast }
                Finalize-FactorioQCResult -Result $fast -Strict:$Strict
            }
            'runtime' { Invoke-FactorioRuntimeQC -Context $context -Save $Save -Strict:$Strict }
            'preview' { Invoke-FactorioPreviewQC -Context $context -Save $Save -Seed $Seed -Planet $Planet -Strict:$Strict }
            'assets' { Invoke-FactorioAssetsQC -Context $context -Strict:$Strict }
            'package' { Invoke-FactorioPackageQC -Context $context -Strict:$Strict }
        }
    }
} catch {
    $results += [pscustomobject]@{name='execution';status='failed';errors=@($_.Exception.Message);warnings=@();artifacts=@{}}
} finally {
    try { [void](Invoke-EsirQcStorage -RepoRoot $RepoRoot -Action release -Data @{run_id=$RunId}) }
    catch {
        $results += [pscustomobject]@{name='storage';status='failed';errors=@($_.Exception.Message);warnings=@();artifacts=@{}}
    }
}
$status = if (@($results | Where-Object status -eq 'failed').Count) { 'failed' }
    elseif (@($results | Where-Object status -eq 'warning').Count) { 'warning' }
    elseif (@($results | Where-Object status -eq 'skipped').Count) { 'skipped' } else { 'ok' }
$summary = [ordered]@{
    mode = $Mode; overall_status = $status; repo_root = $context.repo_root
    factorio_exe = $context.factorio_exe; run_mod_directory = $context.run_mod_directory
    is_esir = $context.is_esir; timestamp = [DateTime]::UtcNow.ToString('o'); results = $results
    run_id = $run.id; workflow = $run.workflow; engine_version = $run.engine_version; payload_path = $run.payload_path
}
Write-EsirJson -Path (Join-Path $ownedRoot 'latest-summary.json') -Data $summary
if ($status -eq 'failed') { exit 1 }
exit 0
