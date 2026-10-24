[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunId,
    [ValidateSet('Prepare','Baseline','Candidate')][string]$Phase = 'Candidate',
    [Parameter(Mandatory)][string]$SavePath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$record = Read-EsirArtifactRun $repo $RunId
if ($record.workflow -ne 'alien-beacon-repair') { throw 'Wrong artifact owner.' }
$run = Assert-EsirArtifactTarget $repo $record.payload_path
$mods = Join-Path $run 'mods'
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
$helper = Join-Path $mods 'zzz-alien-beacon-repair-qc'
$config = Join-Path $run 'config.ini'
$utf8 = [Text.UTF8Encoding]::new($false)
$exe = 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
if ($Phase -eq 'Prepare') {
    New-Item -ItemType Directory -Path $mods,$pack,$helper -Force | Out-Null
    python -B (Join-Path $PSScriptRoot 'qc/auric-productivity/stage-assets.py') $repo $mods
    if ($LASTEXITCODE -ne 0) { throw 'Asset staging failed.' }
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $list = Get-Content -LiteralPath (Join-Path $repo '.factorio-qc/fmqc/mods-live/mod-list.json') -Raw | ConvertFrom-Json
    $info = Get-Content -LiteralPath (Join-Path $pack 'info.json') -Raw | ConvertFrom-Json
    $excluded = @($info.dependencies | Where-Object { $_ -match '^!\s+' } | ForEach-Object { ($_ -replace '^!\s+','') -replace '\s+[<>=].*$','' })
    foreach ($mod in $list.mods) {
        if ($mod.name -match 'qc|benchmark' -or $mod.name -in $excluded) { $mod.enabled = $false }
        if ($mod.name -eq 'zzz-nonstandard-beacons') { $mod.enabled = $true }
    }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-alien-beacon-repair-qc') + @{name='zzz-alien-beacon-repair-qc';enabled=$true}
    [IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 6), $utf8)
    [IO.File]::WriteAllLines($config, @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false'), $utf8)
    [IO.File]::AppendAllText((Join-Path $pack 'control.lua'), "`n" + (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'qc/alien-beacon-repair/bridge.lua') -Raw), $utf8)
    Write-Output "Prepared: $run"
    return
}
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/alien-beacon-repair') -File | Copy-Item -Destination $helper -Force
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'), "return {baseline=$(($Phase -eq 'Baseline').ToString().ToLowerInvariant())}", $utf8)
$source = if ($Phase -eq 'Baseline') { Join-Path $run 'baseline/alien-system.lua' } else { Join-Path $repo 'exotic-space-industries-remembrance/scripts/control/alien-system.lua' }
Copy-Item -LiteralPath $source -Destination (Join-Path $pack 'scripts/control/alien-system.lua') -Force
$alias = Join-Path $repo ('.factorio-qc/abr-' + $RunId.Substring(0,8))
if (Test-Path -LiteralPath $alias) { throw "Short path already exists: $alias" }
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
try {
    & $exe --benchmark $SavePath --benchmark-ticks 500 --benchmark-runs 1 --config $config --mod-directory $alias --disable-audio --disable-migration-window 2>&1 | Out-File -LiteralPath (Join-Path $run "$Phase.log") -Encoding UTF8
    $engineExit = $LASTEXITCODE
    $log = Get-Content -LiteralPath (Join-Path $run "$Phase.log") -Raw
    if ($Phase -eq 'Baseline') {
        if ($log -notmatch "control.lua:556: attempt to index local 'metadata'" -or $log -notmatch 'ALIEN_BEACON_REPAIR_BASELINE') {
            throw "Baseline did not reproduce the reported crash: $run"
        }
        Write-Output 'Baseline reproduced Nonstandard Beacons 1.4.2 control.lua:556 missing metadata.'
    } else {
        if ($engineExit -ne 0 -or $log -match 'Error while running event|Error Util.cpp' -or $log -notmatch 'ALIEN_BEACON_REPAIR_QC') {
            throw "Candidate failed: $run"
        }
        Get-Content -LiteralPath (Join-Path $run 'script-output/alien-beacon-repair.json')
    }
} finally {
    $link = Get-Item -LiteralPath $alias -ErrorAction SilentlyContinue
    if ($link -and ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $link.FullName.StartsWith(([IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc')) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
        [IO.Directory]::Delete($link.FullName)
    }
}
