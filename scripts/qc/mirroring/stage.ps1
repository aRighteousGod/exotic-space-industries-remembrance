[CmdletBinding()]
param([Parameter(Mandatory)][string]$Record)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$context = Get-EsirQcContext -Paths (Get-EsirPaths $repo)
$state = Start-EsirManagedQc -RepoRoot $repo -Context $context -Workflow mirroring-repair -SourceMode private-mutable -Reproduction 'scripts/qc/mirroring/stage.ps1; prepare.py; run.ps1'
if (-not $state.run) { throw $state.error }
$result = New-FactorioQCResult -Name mirroring-repair
$mods = Sync-FactorioRunMods -Context $context -Result $result
$config = New-FactorioWriteDataConfig -Context $context -Label mirroring
$recordData = @{run_id=$state.run.id; mods=$mods; config=$config.config_path; write_data=$config.write_data_dir; engine=$context.factorio_exe; repo=$repo}
Write-EsirJson -Path $Record -Data $recordData
$recordData | ConvertTo-Json
