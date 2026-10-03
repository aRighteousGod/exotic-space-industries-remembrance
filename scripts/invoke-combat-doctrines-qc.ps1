[CmdletBinding()]
param([switch]$Matrix,[switch]$Runtime,[switch]$Visual,[switch]$Performance,[switch]$Rendering,[switch]$Transition,[switch]$Overlap,[switch]$Compatibility,[switch]$MissScene,
    [string]$Pyric='tempered',[string]$Ballistic='tempered',[switch]$PyricDisabled,[switch]$BallisticDisabled,[string]$ReuseRun)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
$run=if ($ReuseRun) { (Resolve-Path -LiteralPath $ReuseRun).Path } else { Join-Path $repo ('.factorio-qc\pr-bd\'+(Get-Date -Format 'MMdd-HHmmss')) }
if (-not $run.StartsWith((Join-Path $repo '.factorio-qc\pr-bd\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'QC staging must remain inside .factorio-qc/pr-bd' }
$mods=Join-Path $run 'mods'
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
$helper=Join-Path $mods 'zzz-esir-combat-doctrines-qc'
$configuration=Join-Path $run 'config.ini'
New-Item -ItemType Directory -Path $mods,$pack,$helper -Force | Out-Null
if (-not $ReuseRun) {
    foreach ($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
        New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
    }
    foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
        if (Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json')) { New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null }
    }
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object { $_.name -notmatch 'qc|benchmark' })
    $info=Get-Content -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance\info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($dependency in $info.dependencies) {
        if ($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') { foreach ($mod in $list.mods) { if ($mod.name -eq $Matches[1]) { $mod.enabled=$false } } }
    }
    $list.mods+=@{name='zzz-esir-combat-doctrines-qc';enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $configuration -Encoding UTF8
}
foreach ($entry in Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance')) {
    if ($entry.PSIsContainer -and $entry.Name -in @('graphics','sound','sounds','music')) {
        if (-not (Test-Path -LiteralPath (Join-Path $pack $entry.Name))) { New-Item -ItemType Junction -Path (Join-Path $pack $entry.Name) -Target $entry.FullName | Out-Null }
    } else { Copy-Item -LiteralPath $entry.FullName -Destination $pack -Recurse -Force }
}
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\combat-doctrines') -File | Copy-Item -Destination $helper -Force
if ($Overlap) {
    $metadata=Get-Content -LiteralPath (Join-Path $pack 'lib\combat-doctrines-dependencies.lua') -Raw -Encoding UTF8
    $counterparts=@([regex]::Matches($metadata,'=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $list=Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($id in ($counterparts+@('data-utils'))) {
        $archive=Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Factorio\mods') -File -Filter ($id+'_*.zip') | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $archive) { throw "Missing locally installed optional dependency: $id" }
        Copy-Item -LiteralPath $archive.FullName -Destination $mods -Force
        $list.mods=@($list.mods | Where-Object { $_.name -ne $id })
        $list.mods+=@{name=$id;enabled=$true}
    }
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    # Observe the real production print branches in the disposable source copy.
    $compatPath=Join-Path $pack 'scripts\control\compat.lua'
    $compatSource=Get-Content -LiteralPath $compatPath -Raw -Encoding UTF8
    foreach ($family in @('pyric-radiance','ballistic-divergence')) {
        $statement='player.print({"combat-doctrines.overlap-warning", {"exotic-industries-informatron.'+$family+'"}})'
        $compatSource=$compatSource.Replace($statement,$statement+"`n        log(`"COMBAT_DOCTRINES_OVERLAP_WARNING $family`")")
    }
    [IO.File]::WriteAllText($compatPath,$compatSource,[Text.UTF8Encoding]::new($false))
}
$final=Join-Path $pack 'data-final-fixes.lua'
$source=Get-Content -LiteralPath $final -Raw -Encoding UTF8
foreach ($family in @('ballistic-divergence','pyric-radiance')) {
    $hook=if ($family -eq 'ballistic-divergence') { 'ballistics' } else { 'radiance' }
    $source=$source.Replace("require(`"scripts/data-final-updates/$family`")","require(`"__zzz-esir-combat-doctrines-qc__/snapshot`").$hook()`nrequire(`"scripts/data-final-updates/$family`")")
}
[IO.File]::WriteAllText($final,$source,[Text.UTF8Encoding]::new($false))
Write-Host "Combat doctrine QC artifacts: $run"
$mode=if ($Overlap) { 'overlap' } elseif ($Compatibility) { 'compatibility' } elseif ($Rendering) { 'rendering' } elseif ($Visual) { 'visual' } elseif ($Performance) { 'performance' } elseif ($Transition) { 'transition' } else { 'firing' }
$phases=@(@{phase="$mode-$Pyric-$Ballistic";pyric=$Pyric;ballistic=$Ballistic;pe=(-not $PyricDisabled);be=(-not $BallisticDisabled)})
if ($Matrix) {
    $pyricProfiles=@('ember','veiled','furnace-vigil','iron-benediction','signal-threads','tempered','night-liturgy','siege-hymn','cataclysm','apotheosis')
    $ballisticProfiles=@('needle-oath','measured-volleys','breach-doctrine','tempered','distant-thunder','fortress-oath','wildfire-doctrine','crossfire','saturation','terminal-barrage')
    $phases=@()
    foreach ($p in $pyricProfiles) { $phases+=@{phase="pyric-$p";pyric=$p;ballistic='tempered';pe=$true;be=$true} }
    foreach ($b in $ballisticProfiles) { $phases+=@{phase="ballistic-$b";pyric='tempered';ballistic=$b;pe=$true;be=$true} }
    foreach ($pe in @($false,$true)) { foreach ($be in @($false,$true)) { $phases+=@{phase="toggle-$pe-$be";pyric='tempered';ballistic='tempered';pe=$pe;be=$be} } }
}
if ($Overlap) {
    $phases=@()
    foreach ($pe in @($false,$true)) { foreach ($be in @($false,$true)) {
        $phases+=@{phase="overlap-$pe-$be";pyric='tempered';ballistic='tempered';pe=$pe;be=$be}
    } }
}
if ($Compatibility) {
    $phases=@()
    foreach ($b in @('tempered','wildfire-doctrine','terminal-barrage')) {
        $phases+=@{phase="compatibility-$b";pyric='tempered';ballistic=$b;pe=$true;be=$true}
    }
    $phases+=@{phase='compatibility-disabled';pyric='tempered';ballistic='terminal-barrage';pe=$false;be=$false}
}
if ($Transition) {
    $phases=@(
        @{phase='transition-source';pyric='apotheosis';ballistic='terminal-barrage';pe=$true;be=$true},
        @{phase='transition-off';pyric='apotheosis';ballistic='terminal-barrage';pe=$false;be=$false;load='transition-source'},
        @{phase='transition-reload';pyric='apotheosis';ballistic='terminal-barrage';pe=$false;be=$false;load='transition-off'},
        @{phase='transition-tempered';pyric='tempered';ballistic='tempered';pe=$true;be=$true;load='transition-source'}
    )
    New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
    $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
    $server.name='ESIR combat doctrine acceptance';$server.visibility.public=$false;$server.visibility.lan=$false
    $server.require_user_verification=$false;$server.auto_pause=$false
    $serverPath=Join-Path $run 'server-settings.json'
    $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverPath -Encoding UTF8
}
$results=@()
foreach ($phase in $phases) {
    $reportName=if ($mode -eq 'visual') { 'combat-doctrines-visual.json' }
        elseif ($mode -eq 'rendering' -or $mode -eq 'performance') { 'combat-doctrines-performance.json' }
        elseif ($mode -eq 'overlap') { 'combat-doctrines-overlap.json' }
        elseif ($mode -eq 'transition') { "$($phase.phase).json" } else { 'combat-doctrines-runtime.json' }
    $oldReport=Join-Path $run "script-output\$reportName"
    if (Test-Path -LiteralPath $oldReport) { Remove-Item -LiteralPath $oldReport -Force }
    "return {mode='$mode',phase='$($phase.phase)',['miss-scene']=$($MissScene.ToString().ToLowerInvariant()),['pyric-radiance']='$($phase.pyric)',['ballistic-divergence']='$($phase.ballistic)',['pyric-radiance-enabled']=$($phase.pe.ToString().ToLowerInvariant()),['ballistic-divergence-enabled']=$($phase.be.ToString().ToLowerInvariant())}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    $save=Join-Path $run "$($phase.phase).zip"
    if ($phase.load) { $save=Join-Path $run "saves\combat-doctrines-$($phase.load).zip" }
    else { & $factorio --create $save --map-gen-seed 42 --config $configuration --mod-directory $mods 2>&1 | Out-File -LiteralPath (Join-Path $run "$($phase.phase)-create.txt") -Encoding UTF8 }
    if ($LASTEXITCODE -ne 0) { throw "Data checks failed: $($phase.phase)-create.txt" }
    $marker=if ($phase.load) { 'Transition uses actual saved startup reconciliation' } else { Select-String -LiteralPath (Join-Path $run "$($phase.phase)-create.txt") -Pattern 'COMBAT_DOCTRINES_DATA_QC' }
    if (-not $marker) { throw 'Missing final data.raw assertions' }
    Write-Host $marker.Line
    $results+=@{phase=$phase.phase;data=$marker.Line;pass=$true}
    if ($Runtime -and -not $Matrix -and $mode -eq 'firing') {
        & $factorio --benchmark $save --benchmark-ticks 28000 --benchmark-runs 1 --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run "$($phase.phase)-runtime.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw 'Native firing checks failed; inspect runtime log and JSON' }
        $report=Get-Content -LiteralPath (Join-Path $run 'script-output\combat-doctrines-runtime.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $report.all_pass) { throw 'Native firing assertions failed' }
        Write-Host "Native firing passed: $($report.cases.Count) cases; $($report.checks.Count) checks"
    }
    if ($Performance) {
        & $factorio --benchmark $save --benchmark-ticks 3600 --benchmark-runs 3 --config $configuration --mod-directory $mods --disable-audio --benchmark-verbose all 2>&1 | Out-File -LiteralPath (Join-Path $run "$($phase.phase)-performance.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw 'Simulation benchmark failed' }
    }
    if ($Visual -or $Rendering -or $Overlap -or $Transition) {
        $stdout=Join-Path $run "$($phase.phase)-runtime.txt"
        $stderr=Join-Path $run "$($phase.phase)-stderr.txt"
        if ($Visual -or $Rendering -or $Overlap) {
            $ticks=if ($Overlap) { '100' } elseif ($Rendering) { '3600' } else { '2200' }
            $arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks',$ticks,'--benchmark-runs','1','--output-perf-stats',('"'+(Join-Path $run 'render-stats.csv')+'"'),'--window-size','1440x1080')
        } else {
            $arguments=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$serverPath+'"'),'--port','34198')
        }
        $arguments+=@('--config',('"'+$configuration+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio','--disable-migration-window')
        $savedPath=Join-Path $run "saves\combat-doctrines-$($phase.phase).zip"
        if ($Transition -and (Test-Path -LiteralPath $savedPath)) { Remove-Item -LiteralPath $savedPath -Force }
        if ($Visual -or $Rendering -or $Overlap) {
            # Native asset loading still encounters Windows' long-path limit.
            # A disposable short alias avoids altering graphics or their paths.
            $shortMods=Join-Path $repo ('.factorio-qc\v'+(Get-Date -Format 'HHmmss'))
            New-Item -ItemType Junction -Path $shortMods -Target $mods | Out-Null
            $arguments[($arguments.IndexOf('--mod-directory'))+1]='"'+$shortMods+'"'
            $env:SteamAppId='427520';$env:SteamGameId='427520'
        }
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null=$process.Handle
        try {
            $deadline=(Get-Date).AddMinutes(4)
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
                if ($Transition -and (Test-Path -LiteralPath $savedPath)) {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    try { $archive=[IO.Compression.ZipFile]::OpenRead($savedPath);$archive.Dispose();break } catch { }
                }
                Start-Sleep -Milliseconds 500
                $process.Refresh()
                if (Select-String -LiteralPath $stdout -Quiet -Pattern 'non-recoverable error|changing state.*Failed') { throw "Engine failure: $stdout" }
            }
            if (($Visual -or $Rendering -or $Overlap) -and (-not $process.HasExited -or $process.ExitCode -ne 0)) { throw "Graphical fixture did not finish: $stdout" }
            if ($Visual -and -not (Test-Path -LiteralPath (Join-Path $run 'script-output\combat-doctrines-visual.json'))) { throw "Graphical fixture produced no evidence: $stdout" }
            if ($Transition -and -not (Test-Path -LiteralPath $savedPath)) { throw "Transition did not save: $stdout" }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
        if ($Transition) {
            $report=Get-Content -LiteralPath (Join-Path $run "script-output\$($phase.phase).json") -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $report.all_pass) { throw 'Transition assertions failed' }
            Write-Host "$($phase.phase) saved and passed"
        }
        if ($Overlap) {
            $report=Get-Content -LiteralPath (Join-Path $run 'script-output\combat-doctrines-overlap.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $report.all_pass) { throw 'Native load-entry fixture failed' }
            foreach ($family in @('pyric-radiance','ballistic-divergence')) {
                $expected=if (($family -eq 'pyric-radiance' -and $phase.pe) -or ($family -eq 'ballistic-divergence' -and $phase.be)) { 1 } else { 0 }
                $warnings=@(Select-String -LiteralPath $stdout -Pattern "COMBAT_DOCTRINES_OVERLAP_WARNING $family")
                if ($warnings.Count -ne $expected) { throw "Unexpected load warning count for $family" }
            }
            Copy-Item -LiteralPath (Join-Path $run 'script-output\combat-doctrines-overlap.json') -Destination (Join-Path $run "$($phase.phase).json") -Force
            Write-Host "$($phase.phase) native load warnings passed"
        }
        if ($Rendering -and -not (Test-Path -LiteralPath (Join-Path $run 'script-output\combat-doctrines-performance.json'))) {
            throw 'Rendering benchmark did not finish its native firing scene'
        }
        if ($Rendering) {
            $report=Get-Content -LiteralPath (Join-Path $run 'script-output\combat-doctrines-performance.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $report.viewer -or $report.projectiles -le 0) { throw 'Rendering benchmark must view the active native projectile scene' }
        }
    }
}
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'matrix.json') -Encoding UTF8
