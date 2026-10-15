[CmdletBinding()]
param(
    [switch]$StageOnly,
    [switch]$TraceEcology,
    [ValidateRange(0,35000)][int]$TraceOffsetTicks=0,
    [string]$OutputRoot,
    [string]$SourceRoot,
    [string]$SeedMods,
    [uint32]$MapSeed=42
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$helper=Join-Path $repo '.factorio-qc/terrain-v2-stress-helper'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'scripts/qc/terrain-evolution/info.json') -Destination $helper -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stress-v2.lua') -Destination $helper -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'burst-progress.lua') -Destination $helper -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stress-v2-bridge.lua') -Destination (Join-Path $helper 'instrument.lua') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'control-stress-v2.lua') -Destination (Join-Path $helper 'control.lua') -Force
if($StageOnly){Write-Output "Staged helper only; no engine started: $helper";return}
if(-not $OutputRoot){$OutputRoot=Join-Path $repo '.factorio-qc/terrain-v2-stress'}
if(Test-Path -LiteralPath (Join-Path $OutputRoot 'mods')){throw "Use a fresh output directory: $OutputRoot"}
$argsList=@('-ExecutionPolicy','Bypass','-File',(Join-Path $repo 'scripts/invoke-terrain-evolution-qc.ps1'),
    '-HelperRoot',$helper,'-OutputRoot',$OutputRoot,'-RunName','native-v2-stress','-Ticks','80000','-MapSeed',"$MapSeed")
if($SourceRoot){$argsList+=@('-SourceRoot',$SourceRoot)}
if($SeedMods){$argsList+=@('-SeedMods',$SeedMods)}
if($TraceEcology){$argsList+=@('-TraceEcology','-TraceOffsetTicks',"$TraceOffsetTicks")}
& powershell @argsList
if($LASTEXITCODE -ne 0){throw "Native V2 stress fixture failed: $OutputRoot"}
if($TraceEcology){Write-Output 'Diagnostic component timers add overhead; release timing analysis skipped.';return}
& python -B (Join-Path $repo 'scripts/qc/terrain-evolution/analyze-stress.py') $OutputRoot
if($LASTEXITCODE -ne 0){throw "Native V2 stress timing gate failed: $OutputRoot/profile-analysis.json"}
