# Freeze before edits; all acceptance staging points at immutable private input.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$context=Get-EsirQcContext -Paths (Get-EsirPaths $repo)
$state=Start-EsirManagedQc -RepoRoot $repo -Context $context -Workflow build-dispatch -SourceMode private-mutable -Reproduction 'scripts/qc/build-dispatch/freeze.ps1; run.ps1'
if (-not $state.run) { throw $state.error }
$baseline=Join-Path $context.scratch_root 'frozen-source'
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') -Destination $baseline -Recurse
$record=@{run_id=$state.run.id;repo=$repo;baseline=$baseline;scratch=$context.scratch_root;
    evidence=$context.evidence_root;payload=(Join-Path $repo $state.run.payload_path)}
$path=Join-Path $record.payload 'context.json'
Write-EsirJson -Path $path -Data $record
@{record=$path;baseline=$baseline} | ConvertTo-Json
