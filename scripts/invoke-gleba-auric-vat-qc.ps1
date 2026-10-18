[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunId,
    [ValidateSet('Prepare','Baseline','Candidate','NoScaling','Dump','Save','Reload','Visual')][string]$Phase = 'Candidate',
    [switch]$ShowVisualWindow
)
$ErrorActionPreference = 'Stop'
if ($Phase -eq 'Visual' -and -not $ShowVisualWindow) {
    throw 'Native GUI acceptance requires an interactive client. Invoke Visual with -ShowVisualWindow when ready to inspect its window.'
}
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$record = Read-EsirArtifactRun $repo $RunId
if ($record.workflow -ne 'gleba-auric-vat') { throw 'Wrong artifact owner.' }
$run = Assert-EsirArtifactTarget $repo $record.payload_path
$mods = Join-Path $run 'mods'
$helper = Join-Path $mods 'zzz-gleba-auric-vat-qc'
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
$alias = Join-Path $repo ('.factorio-qc/gv-' + $RunId.Substring(0,8))
$exe = 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$config = Join-Path $run 'config.ini'
$utf8 = [Text.UTF8Encoding]::new($false)

if ($Phase -eq 'Prepare') {
    New-Item -ItemType Directory -Path $mods -Force | Out-Null
    $seed = Join-Path $repo '.factorio-qc/fmqc/mods-live'
    # Immutable assets use file hard links; directories remain ordinary directories for retention.
    python (Join-Path $PSScriptRoot 'qc/gleba-auric-vat/stage-assets.py') $repo $mods
    if ($LASTEXITCODE -ne 0) { throw 'Asset staging failed.' }
    New-Item -ItemType Directory -Path $pack,$helper -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $list = Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-gleba-auric-vat-qc') + @{name='zzz-gleba-auric-vat-qc';enabled=$true}
    [IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 6), $utf8)
    [IO.File]::WriteAllLines($config, @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false'), $utf8)
    Write-Output $run
    return
}

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/gleba-auric-vat') -File | Copy-Item -Destination $helper -Force
foreach ($language in @('de','en','fr','ja','pl','ru','zh-CN','zh-TW')) {
    foreach ($localeFile in @('auric-inoculation-vat.cfg','auric-inoculation-vat-informatron.cfg')) {
        Copy-Item -LiteralPath (Join-Path $repo "exotic-space-industries-remembrance/locale/$language/$localeFile") -Destination (Join-Path $pack "locale/$language/$localeFile") -Force
    }
}
$baseline = $Phase -eq 'Baseline'
$noScaling = $Phase -eq 'NoScaling'
$version = switch ($Phase) { Baseline {'0.0.1'} Candidate {'0.0.2'} NoScaling {'0.0.3'} Dump {'0.0.2'} Save {'0.0.2'} Reload {'0.0.4'} Visual {'0.0.5'} }
$info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
$info.version = $version
[IO.File]::WriteAllText((Join-Path $helper 'info.json'), ($info | ConvertTo-Json -Depth 4), $utf8)
$luaConfig = "return {baseline=$($baseline.ToString().ToLowerInvariant()), no_scaling=$($noScaling.ToString().ToLowerInvariant()), reload=$(($Phase -eq 'Reload').ToString().ToLowerInvariant()), visual=$(($Phase -eq 'Visual').ToString().ToLowerInvariant())}"
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'), $luaConfig, $utf8)
[IO.File]::WriteAllText((Join-Path $helper 'settings-updates.lua'), "data.raw['bool-setting']['ei-no-tech-scaling'].default_value = $($noScaling.ToString().ToLowerInvariant())", $utf8)
# Discard only this fixture's generated settings so the phase's startup default takes effect.
$fixtureSettings = Join-Path $mods 'mod-settings.dat'
if (Test-Path -LiteralPath $fixtureSettings) { Remove-Item -LiteralPath $fixtureSettings }
$vatFiles = @('prototypes/planet-gleba/auric-cysts.lua','prototypes/planet-gleba/auric-inoculation-vat.lua','scripts/control/auric-inoculation-vat.lua')
foreach ($vatFile in $vatFiles) {
    $source = if ($baseline) { Join-Path (Join-Path $run 'baseline') $vatFile } else { Join-Path (Join-Path $repo 'exotic-space-industries-remembrance') $vatFile }
    Copy-Item -LiteralPath $source -Destination (Join-Path $pack $vatFile) -Force
}
$runtimePath = Join-Path $pack 'scripts/control/auric-inoculation-vat.lua'
$runtimeSource = [IO.File]::ReadAllText($runtimePath)
$bridge = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'qc/gleba-auric-vat/bridge.lua'))
if (-not $runtimeSource.TrimEnd().EndsWith('return model')) { throw 'Unexpected vat module tail.' }
$runtimeSource = $runtimeSource.Substring(0, $runtimeSource.LastIndexOf('return model')) + $bridge + [Environment]::NewLine + 'return model'
[IO.File]::WriteAllText($runtimePath, $runtimeSource, $utf8)
if (Test-Path -LiteralPath $alias) { throw "Short mod path already exists: $alias" }
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
try {
    $save = Join-Path $run 'baseline.zip'
    $arguments = @('--config',$config,'--mod-directory',$alias,'--disable-audio','--disable-migration-window')
    if ($baseline) { $arguments += @('--create',$save) }
    elseif ($Phase -eq 'Dump') { $arguments += '--dump-data' }
    elseif ($Phase -eq 'Save') {
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $server = Get-Content 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name = 'Disposable auric productivity acceptance fixture'
        $server.visibility.public = $false; $server.visibility.lan = $false
        $server.require_user_verification = $false; $server.auto_pause = $false
        [IO.File]::WriteAllText((Join-Path $run 'server-settings.json'), ($server | ConvertTo-Json -Depth 6), $utf8)
        $arguments += @('--start-server',$save,'--server-settings',(Join-Path $run 'server-settings.json'),'--bind','127.0.0.1:34419')
    } elseif ($Phase -eq 'Visual') {
        $save = Join-Path $run 'saves/gleba-auric-vat-checkpoint.zip'
        # Keep native GUI capture advancing; single-player research normally pauses simulation.
        [IO.File]::WriteAllLines($config, @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false','technology-gui-pauses-game=false','[graphics]','full-screen=false','halt-rendering-when-minimized=false'), $utf8)
        $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
        $arguments += @('--load-game',$save,'--window-size','1600x1000','--graphics-quality','medium','--video-memory-usage','low','--max-texture-size','8192')
    } else {
        if ($Phase -eq 'Reload') { $save = Join-Path $run 'saves/gleba-auric-vat-checkpoint.zip' }
        $ticks = if ($Phase -eq 'Reload') { '120' } else { '30000' }
        $arguments += @('--benchmark',$save,'--benchmark-ticks',$ticks,'--benchmark-runs','1')
    }
    $quoted = @($arguments | ForEach-Object { '"'+$_+'"' })
    $started = Get-Date
    $windowStyle = if ($Phase -eq 'Visual' -and $ShowVisualWindow) { 'Normal' } else { 'Hidden' }
    $process = Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle $windowStyle -PassThru -RedirectStandardOutput (Join-Path $run "$Phase.stdout.txt") -RedirectStandardError (Join-Path $run "$Phase.stderr.txt")
    $process.Handle | Out-Null
    Write-Output "Auric $Phase process: $($process.Id)"
    $saved = $false
    try {
        while (-not $process.HasExited) {
            if (((Get-Date) - $started).TotalSeconds -gt 300) { throw "Timeout: $Phase" }
            if (Select-String -LiteralPath (Join-Path $run "$Phase.stdout.txt") -Pattern 'Error while running event|Error Util.cpp|Hosting multiplayer game failed|Quitting: multiplayer error' -Quiet) { throw "Engine error: $Phase; inspect $run" }
            if ($Phase -eq 'Visual') {
                $capture = Join-Path $run 'script-output/auric-research.png'
                if ((Test-Path -LiteralPath $capture) -and (Get-Item -LiteralPath $capture).LastWriteTime -gt $started) {
                    try {
                        Add-Type -AssemblyName System.Drawing
                        $bitmap = [Drawing.Bitmap]::new($capture)
                        $bitmap.Dispose()
                        $saved = $true; break
                    } catch { }
                }
            }
            if ($Phase -eq 'Save') {
                $checkpoint = Join-Path $run 'saves/gleba-auric-vat-checkpoint.zip'
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
    $report = switch ($Phase) { Candidate {'auric-runtime.json'} NoScaling {'auric-runtime.json'} Reload {'auric-reload.json'} Visual {'auric-vat.png'} }
    if ($report) {
        $file = Get-Item -LiteralPath (Join-Path $run "script-output/$report")
        if ($file.LastWriteTime -lt $started) { throw "Stale report: $report" }
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $run "$Phase-$report") -Force
        if ($Phase -in @('Candidate','NoScaling')) { Copy-Item -LiteralPath (Join-Path $run 'script-output/auric-final-data.json') -Destination (Join-Path $run "$Phase-final-data.json") -Force }
    }
    if ($Phase -eq 'Visual') { Write-Output "Auric visual capture written; inspect before UI acceptance: $run" }
    else { Write-Output "Auric $Phase passed: $run" }
} finally {
    $link = Get-Item -LiteralPath $alias -ErrorAction SilentlyContinue
    if ($link) {
        if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $link.Target -ne $mods) { throw 'Unexpected short path target.' }
        [IO.Directory]::Delete($alias)
    }
}
