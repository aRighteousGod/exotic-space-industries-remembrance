[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunId,
    [ValidateSet('Prepare','Baseline','Candidate','Save','Reload')][string]$Phase = 'Candidate'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$record = Read-EsirArtifactRun $repo $RunId
if ($record.workflow -ne 'slag-recovery') { throw 'Wrong artifact owner.' }
$run = Assert-EsirArtifactTarget $repo $record.payload_path
$mods = Join-Path $run 'mods'
$helper = Join-Path $mods 'zzz-slag-recovery-qc'
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
$alias = Join-Path $repo ('.factorio-qc/sr-' + $RunId.Substring(0,8))
$exe = 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$config = Join-Path $run 'config.ini'
$utf8 = [Text.UTF8Encoding]::new($false)

if ($Phase -eq 'Prepare') {
    foreach ($file in @('purifier.lua','vulcanus-fumaroles.lua')) {
        if (-not (Test-Path -LiteralPath (Join-Path $run "baseline/$file"))) { throw "Capture the pre-change source first: baseline/$file" }
    }
    New-Item -ItemType Directory -Path $mods -Force | Out-Null
    # Reuse immutable asset staging; all mutable gameplay files are independent copies.
    python (Join-Path $PSScriptRoot 'qc/auric-productivity/stage-assets.py') $repo $mods
    if ($LASTEXITCODE -ne 0) { throw 'Asset staging failed.' }
    New-Item -ItemType Directory -Path $pack,$helper -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $list = Get-Content -LiteralPath (Join-Path $repo '.factorio-qc/fmqc/mods-live/mod-list.json') -Raw | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-slag-recovery-qc') + @{name='zzz-slag-recovery-qc';enabled=$true}
    [IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 6), $utf8)
    [IO.File]::WriteAllLines($config, @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false'), $utf8)
    Write-Output $run
    return
}

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/slag-recovery') -File | Copy-Item -Destination $helper -Force
$baseline = $Phase -eq 'Baseline'
$info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
$info.version = switch ($Phase) { Baseline {'0.0.1'} Reload {'0.0.3'} default {'0.0.2'} }
[IO.File]::WriteAllText((Join-Path $helper 'info.json'), ($info | ConvertTo-Json -Depth 4), $utf8)
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'), "return {baseline=$($baseline.ToString().ToLowerInvariant()), reload=$(($Phase -eq 'Reload').ToString().ToLowerInvariant())}", $utf8)
foreach ($relative in @('prototypes/electricity-age/purifier.lua','prototypes/planet-vulcanus/vulcanus-fumaroles.lua')) {
    $source = if ($baseline) { Join-Path $run ('baseline/' + (Split-Path $relative -Leaf)) } else { Join-Path $repo "exotic-space-industries-remembrance/$relative" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $pack $relative) -Force
}
if (Test-Path -LiteralPath $alias) { throw "Short path already exists: $alias" }
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
try {
    $save = Join-Path $run 'baseline.zip'
    $arguments = @('--config',$config,'--mod-directory',$alias,'--disable-audio','--disable-migration-window')
    if ($baseline) { $arguments += @('--create',$save) }
    elseif ($Phase -eq 'Save') {
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $server = Get-Content 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name = 'Disposable slag recovery acceptance fixture'
        $server.visibility.public = $false; $server.visibility.lan = $false
        $server.require_user_verification = $false; $server.auto_pause = $false
        [IO.File]::WriteAllText((Join-Path $run 'server-settings.json'), ($server | ConvertTo-Json -Depth 6), $utf8)
        $arguments += @('--start-server',$save,'--server-settings',(Join-Path $run 'server-settings.json'),'--bind','127.0.0.1:34419')
    } else {
        if ($Phase -eq 'Reload') { $save = Join-Path $run 'saves/slag-recovery-checkpoint.zip' }
        $ticks = if ($Phase -eq 'Reload') { '120' } else { '30000' }
        $arguments += @('--benchmark',$save,'--benchmark-ticks',$ticks,'--benchmark-runs','1')
    }
    $started = Get-Date
    $process = Start-Process -FilePath $exe -ArgumentList @($arguments | ForEach-Object { '"'+$_+'"' }) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run "$Phase.stdout.txt") -RedirectStandardError (Join-Path $run "$Phase.stderr.txt")
    $process.Handle | Out-Null
    Write-Output "Slag $Phase process: $($process.Id)"
    $saved = $false
    try {
        while (-not $process.HasExited) {
            if (((Get-Date) - $started).TotalSeconds -gt 300) { throw "Timeout: $Phase" }
            if (Select-String -LiteralPath (Join-Path $run "$Phase.stdout.txt") -Pattern 'Error while running event|Error Util.cpp|Hosting multiplayer game failed|Quitting: multiplayer error' -Quiet) { throw "Engine error: $Phase; inspect $run" }
            if ($Phase -eq 'Save') {
                $checkpoint = Join-Path $run 'saves/slag-recovery-checkpoint.zip'
                if ((Test-Path -LiteralPath $checkpoint) -and (Select-String -LiteralPath (Join-Path $run "$Phase.stdout.txt") -Pattern 'Saving finished' -Quiet)) {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $archive = [IO.Compression.ZipFile]::OpenRead($checkpoint); $archive.Dispose()
                    $saved = $true; break
                }
            }
            Start-Sleep -Milliseconds 500; $process.Refresh()
        }
        if (-not $saved -and $process.ExitCode -ne 0) { throw "Factorio failed: $Phase; inspect $run" }
    } finally {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    }
    Copy-Item -LiteralPath (Join-Path $run 'factorio-current.log') -Destination (Join-Path $run "$Phase.factorio.log") -Force
    $reports = if ($baseline) { @('slag-final-data.json') } elseif ($Phase -eq 'Reload') { @('slag-reload.json') } else { @('slag-final-data.json','slag-runtime.json') }
    foreach ($report in $reports) {
        $file = Get-Item -LiteralPath (Join-Path $run "script-output/$report")
        if ($file.LastWriteTime -lt $started) { throw "Stale report: $report" }
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $run "$Phase-$report") -Force
    }
    Write-Output "Slag $Phase passed: $run"
} finally {
    $link = Get-Item -LiteralPath $alias -ErrorAction SilentlyContinue
    if ($link) {
        if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $link.Target -ne $mods) { throw 'Unexpected short path target.' }
        [IO.Directory]::Delete($alias)
    }
}
