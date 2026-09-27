[CmdletBinding()]
param(
    [ValidateSet('mechanics','benchmark','visual','dump','save','reload')][string]$Mode = 'mechanics',
    [ValidateSet('no-lance','idle','direct','normal-power','dense','diagonal','research')][string]$Scene = 'dense',
    [ValidateSet('lean','standard','cinematic','maximal','unbounded')][string]$Fidelity = 'standard',
    [switch]$Baseline, [switch]$NoScaling, [switch]$Flatten, [switch]$Profile,
    [int]$Ticks = 900, [int]$Runs = 5, [string]$SaveInput, [string]$BaselineSource,
    [switch]$CurrentSource, [string]$RunName, [switch]$NoCounters
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$exe = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$label = if ($Baseline) { 'baseline' } else { 'candidate' }
$run = Join-Path $repo ".factorio-qc\lance\$($label.Substring(0,1))-$($Mode.Substring(0,1))-$Scene-$Fidelity-$([int][bool]$NoScaling)$([int][bool]$Flatten)"
if ($Profile) { $run += '-profile' }
if ($CurrentSource) {
    $currentLabel = if ($RunName) { $RunName } else { "$label-$Mode-$Scene-$Fidelity-$([int][bool]$NoScaling)$([int][bool]$Flatten)-p$([int][bool]$Profile)-c$([int][bool]$NoCounters)" }
    if ($currentLabel -notmatch '^[A-Za-z0-9_-]+$') { throw 'RunName must be a simple directory name.' }
    # Keep copied prototype paths below Windows PowerShell's MAX_PATH limit.
    $run = Join-Path $repo ".factorio-qc\cu\l\$currentLabel"
    if (Test-Path -LiteralPath $run) { throw 'Choose a fresh RunName to preserve current-source evidence.' }
}
$mods = Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed = Join-Path $repo '.factorio-qc\fmqc\mods-live'
$frozenSeed = Join-Path $repo '.factorio-qc\singularity-lance\dependency-seed'
if (Test-Path -LiteralPath "$frozenSeed\mod-list.json") { $seed = $frozenSeed }
foreach ($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip') {
    $target = Join-Path $mods $archive.Name
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType HardLink -Path $target -Target $archive.FullName | Out-Null }
}
foreach ($pack in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance*') {
    $target = Join-Path $mods $pack.Name
    if ($pack.Name -eq 'exotic-space-industries-remembrance') { continue }
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Junction -Path $target -Target $pack.FullName | Out-Null }
}
$main = Join-Path $mods 'exotic-space-industries-remembrance'
$source = if ($BaselineSource) { (Resolve-Path -LiteralPath $BaselineSource).Path } elseif ($CurrentSource) {
    if ($Baseline) { throw 'CurrentSource baseline requires an explicit BaselineSource snapshot.' }
    Join-Path $repo 'exotic-space-industries-remembrance'
} else { Join-Path $repo '.factorio-qc\singularity-lance\baseline-source' }
$frozen = Test-Path -LiteralPath $source
if (-not $frozen) {
    if ($Baseline) { throw 'A pre-change source snapshot is required for baseline measurements. Pass -BaselineSource.' }
    $source = Join-Path $repo 'exotic-space-industries-remembrance'
}
New-Item -ItemType Directory -Path $main -Force | Out-Null
foreach ($item in Get-ChildItem -LiteralPath $source) {
    if ($item.Name -eq 'graphics') {
        if (-not (Test-Path -LiteralPath "$main\graphics")) { New-Item -ItemType Junction -Path "$main\graphics" -Target $item.FullName | Out-Null }
    } else { Copy-Item -LiteralPath $item.FullName -Destination $main -Recurse -Force }
}
$utf8 = New-Object Text.UTF8Encoding($false)
if (-not $Baseline -and -not $CurrentSource) {
    # Freeze unrelated development at the captured baseline for matched tests.
    $live = Join-Path $repo 'exotic-space-industries-remembrance'
    $owned = @('lib\singularity-lance-config.lua', 'scripts\control\singularity-lance.lua',
        'scripts\control\informatron.lua', 'prototypes\alien-system\singularity-lance.lua',
        'prototypes\alien-system\singularity-lance-upgrades.lua',
        'scripts\data-final-updates\final-tech-fixes.lua',
        'scripts\data-final-updates\singularity-lance-science.lua',
        'scripts\data-final-updates\singularity-lance-damage-category.lua')
    foreach ($relative in $owned) { Copy-Item -LiteralPath "$live\$relative" -Destination "$main\$relative" -Force }
    foreach ($lang in @('en','fr','ja','pl','ru','zh-CN','zh-TW')) {
        Copy-Item -Path "$live\locale\$lang\singularity-lance*.cfg" -Destination "$main\locale\$lang" -Force
    }
    if ($frozen) {
    $control = Get-Content -Raw "$main\control.lua"
    $control = $control.Replace('local SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS = {', "local SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS = {`n    [ei_singularity_lance.script_trigger_effect_id] = ei_singularity_lance.on_script_trigger_effect,")
    $control = $control.Replace('    ei_singularity_lance.on_script_trigger_effect(event)', '')
    $control = $control.Replace('        ei_singularity_lance.check_global()', '')
    foreach ($pair in @(@('on_forces_merged','on_forces_merged'),@('on_research_reversed','on_research_finished'),@('on_force_created','on_force_reset'),@('on_object_destroyed','on_object_destroyed'))) {
        $control = $control.Replace("script.on_event(defines.events.$($pair[0]), function(e)", "script.on_event(defines.events.$($pair[0]), function(e)`n    ei_singularity_lance.$($pair[1])(e)")
    }
    $control += @'

script.on_event({defines.events.on_force_reset, defines.events.on_technology_effects_reset}, ei_singularity_lance.on_force_reset)
script.on_event({defines.events.on_force_friends_changed, defines.events.on_force_cease_fire_changed}, ei_singularity_lance.on_diplomacy_changed)
script.on_event({defines.events.on_pre_surface_deleted, defines.events.on_pre_surface_cleared}, ei_singularity_lance.on_surface_deleted)
'@
    [IO.File]::WriteAllText("$main\control.lua", $control, $utf8)
    }
}
$helper = Join-Path $mods 'zzz-lance-upgrade-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Copy-Item -Path "$repo\scripts\qc\singularity-lance\*" -Destination $helper -Force
$legacyBaseline = $Baseline.IsPresent -and -not $CurrentSource.IsPresent
$cfg = "return {mode='$Mode',scene='$Scene',fidelity='$Fidelity',ticks=$Ticks,baseline=$($legacyBaseline.ToString().ToLowerInvariant()),no_scaling=$($NoScaling.ToString().ToLowerInvariant()),flatten=$($Flatten.ToString().ToLowerInvariant()),profile=$($Profile.ToString().ToLowerInvariant()),no_counters=$($NoCounters.ToString().ToLowerInvariant())}"
[IO.File]::WriteAllText("$helper\test-config.lua", $cfg, $utf8)
$list = Get-Content -Raw "$seed\mod-list.json" | ConvertFrom-Json
foreach ($mod in $list.mods) {
    if ($mod.name -match 'qc|benchmark') { $mod.enabled = $false }
    if ($mod.name -eq 'extinguisher') {
        $mainInfo = Get-Content -Raw "$main\info.json" | ConvertFrom-Json
        $mod.enabled = -not [bool]($mainInfo.dependencies | Where-Object { $_ -match '^!\s*extinguisher' })
    }
}
$list.mods += [pscustomobject]@{name='zzz-lance-upgrade-qc';enabled=$true}
[IO.File]::WriteAllText("$mods\mod-list.json", ($list | ConvertTo-Json -Depth 8), $utf8)
# The bridge exists only in the staged main pack, keeping test injection out of shipping code.
$bridge = Get-Content -Raw "$repo\scripts\qc\singularity-lance\bridge.lua"
[IO.File]::AppendAllText("$main\control.lua", "`n$bridge", $utf8)
$config = Join-Path $run 'config.ini'
$forward = $run.Replace('\','/')
[IO.File]::WriteAllText($config, "[path]`nread-data=__PATH__executable__/../../data`nwrite-data=$forward`n[other]`ncheck-updates=false`n", $utf8)
function Invoke-Engine([string[]]$Extra, [string]$Tag) {
    $arguments = @('--config', ('"'+$config+'"'), '--mod-directory', ('"'+$mods+'"'), '--disable-audio') + $Extra
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\$Tag-stdout.txt" -RedirectStandardError "$run\$Tag-stderr.txt"
    $process.Handle | Out-Null
    $process.WaitForExit()
    $process.Refresh()
    Copy-Item -LiteralPath "$run\factorio-current.log" -Destination "$run\$Tag.log" -Force
    if (($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or (Select-String -LiteralPath "$run\$Tag.log" -Pattern 'Error Util.cpp|Error while running event' -Quiet)) {
        Get-Content "$run\$Tag.log" -Tail 20; throw "Factorio failed: $run\$Tag.log"
    }
}
if ($Mode -eq 'dump') { Invoke-Engine @('--dump-data') 'dump'; Write-Output $run; exit }
$save = if ($SaveInput) { (Resolve-Path $SaveInput).Path } else { Join-Path $run 'fixture.zip' }
if (-not $SaveInput) { Invoke-Engine @('--create', ('"'+$save+'"')) 'create' }
if ($Mode -eq 'save') {
    New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
    $serverSettings = Join-Path $run 'server-settings.json'
    $install = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $exe))
    $serverOptions = Get-Content -Raw (Join-Path $install 'data\server-settings.example.json') | ConvertFrom-Json
    $serverOptions.name, $serverOptions.description = 'Lance isolated save QC', 'Local counter-seven persistence fixture'
    $serverOptions.visibility.public, $serverOptions.visibility.lan = $false, $false
    $serverOptions.require_user_verification, $serverOptions.auto_pause = $false, $false
    [IO.File]::WriteAllText($serverSettings, ($serverOptions | ConvertTo-Json -Depth 8), $utf8)
    $arguments = @('--config', ('"'+$config+'"'), '--mod-directory', ('"'+$mods+'"'), '--disable-audio', '--start-server', ('"'+$save+'"'), '--server-settings', ('"'+$serverSettings+'"'), '--port','34219')
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\save-stdout.txt" -RedirectStandardError "$run\save-stderr.txt"
    $process.Handle | Out-Null
    $saved = Join-Path $run 'saves\lance-seven.zip'
    $savedValid = $false
    $started = Get-Date; $deadline = $started.AddMinutes(3)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            if ((Test-Path -LiteralPath $saved) -and (Get-Item -LiteralPath $saved).LastWriteTime -ge $started) {
                try { $archive = [IO.Compression.ZipFile]::OpenRead($saved); $archive.Dispose(); $savedValid = $true; break } catch {}
            }
            $serverLog = Get-Item -LiteralPath "$run\factorio-current.log" -ErrorAction SilentlyContinue
            if ($serverLog -and $serverLog.LastWriteTime -ge $started -and
                (Select-String -LiteralPath $serverLog.FullName -Pattern 'Error while running event|Hosting multiplayer game failed' -Quiet)) { break }
            Start-Sleep -Milliseconds 500; $process.Refresh()
        }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    if (-not $savedValid) { throw "Counter-seven save missing or incomplete: $run" }
    Write-Output $saved
    exit
}
if ($Mode -eq 'visual') {
    $arguments = @('--config', ('"'+$config+'"'), '--mod-directory', ('"'+$mods+'"'), '--disable-audio', '--benchmark-graphics', ('"'+$save+'"'), '--benchmark-ticks', '360', '--benchmark-runs', '1')
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\visual-stdout.txt" -RedirectStandardError "$run\visual-stderr.txt"
    $process.Handle | Out-Null
    Write-Output "Visual Factorio PID: $($process.Id); evidence: $run\script-output\lance-visual"
    $deadline = (Get-Date).AddMinutes(5)
    try {
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            if ((Test-Path -LiteralPath "$run\factorio-current.log") -and (Select-String -LiteralPath "$run\factorio-current.log" -Pattern 'LANCE_VISUAL COMPLETE' -Quiet)) {
                Start-Sleep -Seconds 2
                break
            }
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    $captures = @(Get-ChildItem -LiteralPath "$run\script-output\lance-visual" -Filter '*.png' -ErrorAction SilentlyContinue)
    Write-Output "Captured $($captures.Count) frames."
    if ($captures.Count -lt 9) { throw "Visual capture incomplete: $run" }
    exit
}
$engineRuns = if ($Mode -eq 'benchmark' -and -not $Profile) { $Runs + 1 } else { $Runs }
$engineTicks = if ($Profile) { $Ticks + 1 } else { $Ticks }
Invoke-Engine @('--benchmark', ('"'+$save+'"'), '--benchmark-ticks', "$engineTicks", '--benchmark-runs', "$engineRuns") 'benchmark'
if ($Mode -in @('mechanics','reload')) {
    $marker = if ($Mode -eq 'reload') { 'LANCE_QC RELOAD_COMPLETE' } else { 'LANCE_QC ALL_COMPLETE' }
    if (-not (Select-String -LiteralPath "$run\benchmark.log" -Pattern $marker -Quiet)) {
        throw "Fixture did not complete: $run\benchmark.log"
    }
}
Write-Output $run
exit 0
