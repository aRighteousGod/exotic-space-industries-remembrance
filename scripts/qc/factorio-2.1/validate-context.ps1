[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$record=Read-EsirJson (Join-Path $RunRoot 'context.json')
$run=Read-EsirArtifactRun $repo $record.run_id
$profile=Read-EsirJson (Join-Path $repo '.codex/esir/factorio-development.json')
if ($run.workflow -ne 'core-2.1' -or -not $run.task_open -or $run.status -ne 'running' -or
    [IO.Path]::GetFullPath((Join-Path $repo $run.payload_path)) -ne [IO.Path]::GetFullPath($RunRoot) -or
    $record.source_mode -ne 'private-mutable' -or $record.engine_version -ne $profile.engine_version) {
    throw 'Worker is not an open private managed fixture for this exact profile.'
}
$null=Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$record.run_id}
@{valid=$true;run_id=$record.run_id}|ConvertTo-Json -Compress
