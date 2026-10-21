[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunId,
    [ValidateSet('Prepare','Baseline','Candidate','Save','Reload','Visual')][string]$Phase = 'Candidate',
    [string]$BaselineRevision = '747d349e3ab693e2acb436fe9a51cf9fbb9eda1d',
    [switch]$ShowVisualWindow
)
$ErrorActionPreference = 'Stop'
if ($Phase -eq 'Visual' -and -not $ShowVisualWindow) {
    throw 'Native GUI acceptance requires -ShowVisualWindow; hidden clients did not advance capture ticks on this workstation.'
}
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$record = Read-EsirArtifactRun $repo $RunId
if ($record.workflow -ne 'robot-progression') { throw 'Wrong artifact owner.' }
$run = Assert-EsirArtifactTarget $repo $record.payload_path
$mods = Join-Path $run 'mods'
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
$helper = Join-Path $mods 'zzz-esir-robot-progression-qc'
$alias = Join-Path $repo ('.factorio-qc/rb-' + $RunId.Substring(0,8))
$exe = 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$config = Join-Path $run 'config.ini'
$utf8 = [Text.UTF8Encoding]::new($false)

if ($Phase -eq 'Prepare') {
    if (Test-Path -LiteralPath $mods) { throw 'Prepare requires new staging.' }
    New-Item -ItemType Directory -Path $mods,$helper -Force | Out-Null
    # Reuse the established immutable-asset hard-link staging; no reparse payloads.
    python (Join-Path $PSScriptRoot 'qc/gleba-auric-vat/stage-assets.py') $repo $mods
    if ($LASTEXITCODE -ne 0) { throw 'Asset staging failed.' }
    New-Item -ItemType Directory -Path $pack -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance') | Copy-Item -Destination $pack -Recurse -Force
    $optional = Join-Path $repo 'minigun-turret-HD'
    if (Test-Path -LiteralPath $optional) { Copy-Item -LiteralPath $optional -Destination $mods -Recurse -Force }
    $list = Get-Content -LiteralPath (Join-Path $repo '.factorio-qc/fmqc/mods-live/mod-list.json') -Raw | ConvertFrom-Json
    foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
    $list.mods = @($list.mods | Where-Object name -ne 'zzz-esir-robot-progression-qc') + @{name='zzz-esir-robot-progression-qc';enabled=$true}
    [IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'), ($list | ConvertTo-Json -Depth 6), $utf8)
    # The pinned revision retains the pre-feature owner after this feature is committed.
    $baseline = & git -C $repo show "${BaselineRevision}:exotic-space-industries-remembrance/prototypes/electricity-age/robots.lua"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot capture robot baseline.' }
    [IO.File]::WriteAllText((Join-Path $run 'baseline-robots.lua'), ($baseline -join "`n"), $utf8)
    $companion = Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Factorio/mods') -Filter 'recipe-icons-improvement-for-esir*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($companion) {
        python -B (Join-Path $repo '.codex/skills/esir-recipe-icon-style/scripts/companion_mod_probe.py') --source $companion.FullName --output (Join-Path $run 'companion-baseline.json')
        if ($LASTEXITCODE -ne 0) { throw 'Recipe icon companion probe failed.' }
    } else {
        [IO.File]::WriteAllText((Join-Path $run 'companion-baseline.json'), '{"available":false,"fallback":"ESIR make_icons convention and native GUI captures"}', $utf8)
    }
    Write-Output $run
    return
}

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc/robot-progression') -File | Copy-Item -Destination $helper -Force
$baseline = $Phase -eq 'Baseline'
$luaConfig = "return {baseline=$($baseline.ToString().ToLowerInvariant()),save_only=$(($Phase -eq 'Save').ToString().ToLowerInvariant()),reload=$(($Phase -eq 'Reload').ToString().ToLowerInvariant()),visual=$(($Phase -eq 'Visual').ToString().ToLowerInvariant())}"
[IO.File]::WriteAllText((Join-Path $helper 'test-config.lua'), $luaConfig, $utf8)
$list = Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw | ConvertFrom-Json
$info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
$info.dependencies = @($list.mods | Where-Object { $_.enabled -and $_.name -ne $info.name } | ForEach-Object name)
[IO.File]::WriteAllText((Join-Path $helper 'info.json'), ($info | ConvertTo-Json -Depth 4), $utf8)
$source = if ($baseline) { Join-Path $run 'baseline-robots.lua' } else { Join-Path $repo 'exotic-space-industries-remembrance/prototypes/electricity-age/robots.lua' }
Copy-Item -LiteralPath $source -Destination (Join-Path $pack 'prototypes/electricity-age/robots.lua') -Force
Copy-Item -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/scripts/data-final-updates/final-recipe-fixes.lua') -Destination (Join-Path $pack 'scripts/data-final-updates/final-recipe-fixes.lua') -Force
[IO.File]::WriteAllLines($config, @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false','technology-gui-pauses-game=false','[graphics]','full-screen=false','halt-rendering-when-minimized=false','max-sprite-loading-threads=2'), $utf8)
if (Test-Path -LiteralPath $alias) { throw "Short path already exists: $alias" }
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
try {
    $save = Join-Path $run 'baseline.zip'
    $arguments = @('--config',$config,'--mod-directory',$alias,'--disable-audio','--disable-migration-window')
    if ($baseline) { $arguments += @('--create',$save) }
    elseif ($Phase -eq 'Save') {
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $server = Get-Content 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name = 'Disposable robot progression acceptance fixture'
        $server.visibility.public = $false; $server.visibility.lan = $false
        $server.require_user_verification = $false; $server.auto_pause = $false
        [IO.File]::WriteAllText((Join-Path $run 'server-settings.json'), ($server | ConvertTo-Json -Depth 6), $utf8)
        $arguments += @('--start-server',$save,'--server-settings',(Join-Path $run 'server-settings.json'),'--bind','127.0.0.1:34429')
    } elseif ($Phase -eq 'Visual') {
        $save = Join-Path $run 'saves/robot-progression-checkpoint.zip'
        $env:SteamAppId = '427520'; $env:SteamGameId = '427520'
        $arguments += @('--load-game',$save,'--window-size','1600x1000','--graphics-quality','medium','--video-memory-usage','low','--max-texture-size','8192')
    } else {
        if ($Phase -eq 'Reload') { $save = Join-Path $run 'saves/robot-progression-checkpoint.zip' }
        $ticks = if ($Phase -eq 'Reload') { '120' } else { '60000' }
        $arguments += @('--benchmark',$save,'--benchmark-ticks',$ticks,'--benchmark-runs','1')
    }
    $stdout = Join-Path $run "$Phase.stdout.txt"
    $stderr = Join-Path $run "$Phase.stderr.txt"
    $started = Get-Date
    $windowStyle = if ($Phase -eq 'Visual' -and $ShowVisualWindow) { 'Normal' } else { 'Hidden' }
    $native = Start-Process -FilePath $exe -ArgumentList @($arguments | ForEach-Object { '"'+$_+'"' }) -WindowStyle $windowStyle -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $native.Handle
    $finished = $false
    try {
        while (-not $native.HasExited -and (Get-Date) -lt $started.AddMinutes(15)) {
            Start-Sleep -Milliseconds 500
            $native.Refresh()
            if (Test-Path -LiteralPath $stdout) {
                if (Select-String -LiteralPath $stdout -Pattern 'Error while running|Failed to load mods|Failed to start server' -Quiet) { throw "Engine error in $Phase; see $stdout" }
                if ($Phase -eq 'Save') {
                    $checkpoint = Join-Path $run 'saves/robot-progression-checkpoint.zip'
                    if ((Test-Path -LiteralPath $checkpoint) -and (Select-String -LiteralPath $stdout -Pattern 'Saving finished' -Quiet)) {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        $archive = [IO.Compression.ZipFile]::OpenRead($checkpoint); $archive.Dispose()
                        $finished = $true; break
                    }
                }
                if ($Phase -eq 'Visual') {
                    $capture = Join-Path $run 'script-output/robot-visual.json'
                    if ((Test-Path -LiteralPath $capture) -and (Get-Item -LiteralPath $capture).LastWriteTime -gt $started) { $finished = $true; break }
                }
            }
        }
        if (-not $finished) {
            if (-not $native.HasExited) { throw "Timed out: $Phase" }
            $native.WaitForExit(); $native.Refresh()
            if ($native.ExitCode -ne 0) { throw "Engine exited $($native.ExitCode): $stdout" }
            if ($Phase -in @('Save','Visual')) { throw "Missing completion evidence: $Phase" }
        }
    } finally { if (-not $native.HasExited) { Stop-Process -Id $native.Id; $native.WaitForExit() } }
    if ($Phase -in @('Candidate','Save')) {
        $reportName = if ($Phase -eq 'Save') { 'robot-save.json' } else { 'robot-runtime.json' }
        $reportPath = Join-Path $run "script-output/$reportName"
        if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started) { throw 'Missing fresh runtime result.' }
        python -B (Join-Path $PSScriptRoot 'qc/robot-progression/check.py') (Join-Path $run 'script-output')
        if ($LASTEXITCODE -ne 0) { throw 'Final prototype comparison failed.' }
    }
    if ($Phase -eq 'Reload' -and -not (Test-Path -LiteralPath (Join-Path $run 'script-output/robot-reload.json'))) { throw 'Missing reload result.' }
    Write-Output "Robot QC $Phase passed: $run"
} finally {
    $link = Get-Item -LiteralPath $alias -Force
    if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $link.Target -ne $mods) { throw 'Unexpected short path target.' }
    [IO.Directory]::Delete($alias)
}
