param(
    [ValidateSet('prepare','preflight','pilot','benchmark','production')][string]$Phase='pilot',
    [int]$Samples=0,
    [int]$StartDirection=0,
    [int]$EndDirection=256
)
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$root=Join-Path $repo 'output\meshy\minigun-prototypes\prototype-2\handoff-256'
$blender='C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
$scriptRoot=$PSScriptRoot
if($Phase -eq 'production') {
    $gate=Get-Content -LiteralPath (Join-Path $root 'qa-summary.json') -Raw | ConvertFrom-Json
    if($gate.production_gate -ne 'passed') {throw "Production gate is $($gate.production_gate): $($gate.blocker)"}
    $free=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($repo)).AvailableFreeSpace
    if($free -lt 12GB) {throw 'Require at least 12 GiB free for retained sheets, a scratch chunk and 5 GiB headroom'}
}
if($Phase -eq 'prepare') {
    $script=Join-Path $scriptRoot 'prepare_prototype2.py'
    $arguments=@('--factory-startup','--background','--threads','8','--python-exit-code','1','--python',$script)
} else {
    $script=Join-Path $scriptRoot 'render_prototype2.py'
    $arguments=@('--factory-startup','--background','--threads','8','--python-exit-code','1','--python',$script,'--','--mode',$Phase)
    if($Samples -gt 0){$arguments+=@('--samples',"$Samples")}
    if($Phase -eq 'production'){$arguments+=@('--start-direction',"$StartDirection",'--end-direction',"$EndDirection")}
}
@{executable=$blender;arguments=$arguments;phase=$Phase;source_sha256='453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59'} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root "$Phase-command.json") -Encoding UTF8
$oldPreference=$ErrorActionPreference
$ErrorActionPreference='Continue'
try {& $blender @arguments *> (Join-Path $root "$Phase.log");$result=$LASTEXITCODE}
finally {$ErrorActionPreference=$oldPreference}
if($result -ne 0){Get-Content -LiteralPath (Join-Path $root "$Phase.log") -Tail 25;exit $result}
Write-Output "Completed $Phase; see $root"
