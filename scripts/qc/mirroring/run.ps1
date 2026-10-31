[CmdletBinding()]
param([Parameter(Mandatory)][string]$Record,
    [ValidateSet('baseline','candidate')][string]$Mode='candidate',
    [ValidateSet('enabled','disabled')][string]$Quality='enabled')
$ErrorActionPreference='Stop'
$recordData=Get-Content -LiteralPath $Record -Raw | ConvertFrom-Json
. (Join-Path $recordData.repo 'scripts/esir-dev-lib.ps1')
& python -B (Join-Path $PSScriptRoot 'prepare.py') $Record $Mode $Quality
if ($LASTEXITCODE -ne 0) { throw 'Private preparation failed.' }
$tag="$Mode-quality-$Quality"
$common=@('--config',$recordData.config,'--mod-directory',$recordData.mods,'--disable-audio')
$save=Join-Path $recordData.write_data "$tag.zip"
$run=Invoke-NativeProcess -FilePath $recordData.engine -Arguments (@('--create',$save)+$common) -OutputPath (Join-Path $recordData.write_data "$tag-create.log")
if ($run.exit_code -ne 0) { throw "Create failed: $tag" }
$run=Invoke-NativeProcess -FilePath $recordData.engine -Arguments (@('--benchmark',$save,'--benchmark-ticks','1802','--benchmark-runs','1')+$common) -OutputPath (Join-Path $recordData.write_data "$tag-reload.log")
if ($run.exit_code -ne 0) { throw "Reload failed: $tag" }
$receipt=Get-Content (Join-Path $recordData.write_data "script-output/mirroring/$tag-reload.json") -Raw | ConvertFrom-Json
if (-not $receipt.passed) { throw "Acceptance failed: $tag" }
if ($Mode -eq 'candidate') {
    $transport=Get-Content (Join-Path $recordData.write_data "script-output/mirroring/$tag-transport.json") -Raw | ConvertFrom-Json
    if (-not $transport.passed) { throw "Transport failed: $tag" }
    $heat=Get-Content (Join-Path $recordData.write_data "script-output/mirroring/$tag-heat.json") -Raw | ConvertFrom-Json
    if (-not $heat.passed) { throw "Heat transfer failed: $tag" }
    $furnaces=Get-Content (Join-Path $recordData.write_data "script-output/mirroring/$tag-furnaces.json") -Raw | ConvertFrom-Json
    if (-not $furnaces.passed) { throw "Loaded furnace checks failed: $tag" }
}
$receipt.counts | ConvertTo-Json
