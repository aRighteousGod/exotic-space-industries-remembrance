[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunName,
    [Parameter(Mandatory=$true)][string]$BaselineSource,
    [Parameter(Mandatory=$true)][ValidateSet('scheduler','dispatch','research')][string]$Mode,
    [string]$SourceRoot,
    [string]$SaveInput,
    [int]$Ticks=240
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
if (-not $SaveInput) { $SaveInput=Join-Path $repo '.factorio-qc/wtr/player/fixture.zip' }
$extra=@{}
if ($SourceRoot) { $extra.SourceRoot=$SourceRoot }
if ($Mode -eq 'research') { $extra.Helper=Join-Path $repo '.codex/skills/esir-dev/assets/zzz-scripted-research-qc_0.0.1' }
$bridge=Join-Path $PSScriptRoot "qc/runtime-contracts/$Mode.lua"
& "$PSScriptRoot/invoke-control-ups-qc.ps1" -RunName $RunName -BaselineSource $BaselineSource -PrepareOnly -SaveInput $SaveInput -BridgePath $bridge -Ticks $Ticks -Runs 1 @extra | Out-Null
$run=Join-Path $repo ".factorio-qc/cu/g/$RunName"
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
# Reuse existing isolated staging. This lane verifies correctness only; it may
# coexist with an existing client and never stops or inspects that process.
$arguments=@('--config',('"'+$run+'/config.ini"'),'--mod-directory',('"'+$run+'/mods"'),
    '--disable-audio','--benchmark',('"'+(Resolve-Path -LiteralPath $SaveInput).Path+'"'),
    '--benchmark-ticks',"$Ticks",'--benchmark-runs','1')
$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/runtime-stdout.txt" -RedirectStandardError "$run/runtime-stderr.txt"
$process.Handle | Out-Null
if (-not $process.WaitForExit(300000)) { $process.Kill(); throw "Owned QC process timed out: $run" }
$process.Refresh()
$logPath=Join-Path $run 'factorio-current.log'
if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or
    (Select-String -LiteralPath $logPath -Pattern 'Error Util.cpp|Error while running event' -Quiet)) {
    Get-Content -LiteralPath "$run/runtime-stdout.txt" -Tail 25
    throw "Factorio correctness QC failed: $run"
}
$report=Join-Path $run "script-output/runtime-contracts-$Mode.json"
if (-not (Test-Path -LiteralPath $report) -or -not (Select-String -LiteralPath $logPath -Pattern "RUNTIME_CONTRACTS mode=$Mode COMPLETE" -Quiet)) { throw "QC did not complete: $run" }
$result=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
if (-not $result.all_pass) { throw "QC assertions failed: $report" }
[ordered]@{all_pass=$true;mode=$Mode;checks=@($result.checks).Count;report=$report;performance_evidence=$false} | ConvertTo-Json
