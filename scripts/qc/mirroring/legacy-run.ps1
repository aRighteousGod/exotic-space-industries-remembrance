[CmdletBinding()]
param([Parameter(Mandatory)][string]$LegacyRecord,
    [Parameter(Mandatory)][string]$CurrentRecord,
    [ValidateSet('donor','baseline','adopt','reload')][string]$Phase='donor')
$ErrorActionPreference='Stop'
$started=Get-Date
$old=Get-Content -LiteralPath $LegacyRecord -Raw | ConvertFrom-Json
$current=Get-Content -LiteralPath $CurrentRecord -Raw | ConvertFrom-Json
. (Join-Path $current.repo 'scripts/esir-dev-lib.ps1')
if ($Phase -eq 'donor') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'legacy-control.lua') -Destination (Join-Path $old.mods 'esir-qc-mirroring-legacy/control.lua')
    $donor=Join-Path $old.write_data 'donor.zip'
    $run=Invoke-NativeProcess -FilePath $old.engine -Arguments @('--create',$donor,'--config',$old.config,'--mod-directory',$old.mods,'--disable-audio') -OutputPath (Join-Path $old.write_data 'donor-create.log')
    if ($run.exit_code -ne 0) { throw 'Historical donor creation failed.' }
    $receiptPath=Join-Path $old.write_data 'script-output/mirroring/legacy-donor.json'
} else {
    $helper=Join-Path $current.mods 'esir-qc-mirroring-legacy'
    New-Item -ItemType Directory -Path $helper -Force | Out-Null
    foreach ($file in @('legacy-cases.lua','recipes.lua')) {
        Copy-Item -LiteralPath (Join-Path $old.mods "esir-qc-mirroring-legacy/$file") -Destination (Join-Path $helper $file)
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'legacy-control.lua') -Destination (Join-Path $helper 'control.lua')
    @{name='esir-qc-mirroring-legacy';version='0.0.2';factorio_version='2.1';title='Historical mirroring fixture';author='ESIR QC';dependencies=@('exotic-space-industries-remembrance')} |
        ConvertTo-Json | Set-Content (Join-Path $helper 'info.json') -Encoding UTF8
    "return {phase='$Phase'}" | Set-Content (Join-Path $helper 'legacy-config.lua') -Encoding UTF8
    $selection=Get-Content (Join-Path $current.mods 'mod-list.json') -Raw | ConvertFrom-Json
    $mods=@($selection.mods | Where-Object {$_.name -ne 'esir-qc-mirroring-legacy'})
    foreach ($mod in $mods) { if ($mod.name -eq 'esir-qc-mirroring') { $mod.enabled=$false } }
    $mods+=@{name='esir-qc-mirroring-legacy';enabled=$true}
    @{mods=$mods} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $current.mods 'mod-list.json') -Encoding UTF8
    $save=if($Phase -ne 'reload') { Join-Path $old.write_data 'donor.zip' } else {
        (Get-ChildItem (Join-Path $current.write_data 'saves') -Filter '*mirroring-migrated*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
    if (-not $save) { throw 'Missing genuine migrated save.' }
    $run=Invoke-NativeProcess -FilePath $current.engine -Arguments @('--benchmark',$save,'--benchmark-ticks','5','--benchmark-runs','1','--config',$current.config,'--mod-directory',$current.mods,'--disable-audio') -OutputPath (Join-Path $current.write_data "legacy-$Phase.log")
    if ($run.exit_code -ne 0) { throw "Historical $Phase failed." }
    $receiptPath=Join-Path $current.write_data "script-output/mirroring/legacy-$Phase.json"
}
if ((Get-Item -LiteralPath $receiptPath).LastWriteTime -lt $started) { throw 'Stale historical receipt.' }
$receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
@{phase=$Phase;engine=$receipt.engine;passed=$receipt.passed;cases=@($receipt.cases).Count} | ConvertTo-Json
if ($Phase -eq 'donor' -and -not $receipt.passed) { throw 'Historical donor assertions failed.' }
# Upgrade phases retain strict failures for the baseline/candidate/reload comparison.
# check-legacy.py rejects any patch-specific or reload difference.
