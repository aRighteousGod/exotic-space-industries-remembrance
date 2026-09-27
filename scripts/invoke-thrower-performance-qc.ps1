[CmdletBinding()]
param(
    [ValidateSet('original','2x','4x','8x','16x')][string[]]$Profiles=@('original','2x','4x','8x','16x'),
    [switch]$Disabled,
    [switch]$DataOnly,
    [switch]$Performance,
    [switch]$Diagnostic,
    [switch]$Behavior,
    [switch]$Transition,
    [switch]$Visual,
    [string]$ReuseRun,
    [string]$FrozenPack
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$sourcePack=if ($FrozenPack) { (Resolve-Path -LiteralPath $FrozenPack).Path } else { Join-Path $repo 'exotic-space-industries-remembrance' }
if ($FrozenPack -and -not $sourcePack.StartsWith((Join-Path $repo '.factorio-qc\thrower-performance\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Frozen source must be an existing thrower QC gameplay copy' }
if ($FrozenPack) {
    $sourceInfo=Get-Content -LiteralPath (Join-Path $sourcePack 'info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($sourceInfo.name -ne 'exotic-space-industries-remembrance' -or $sourceInfo.factorio_version -ne '2.0') { throw 'Frozen source must be the ESIR Factorio 2.0 gameplay pack' }
}
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
$run=if ($ReuseRun) { (Resolve-Path -LiteralPath $ReuseRun).Path } else { Join-Path $repo ('.factorio-qc\thrower-performance\'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')) }
if ($ReuseRun -and -not ($Performance -and $Diagnostic)) { throw '-ReuseRun is reserved for diagnostic replays of a completed timing matrix' }
if ($ReuseRun -and -not $run.StartsWith((Join-Path $repo '.factorio-qc\thrower-performance\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Reuse must stay inside this checkout''s thrower QC staging directory' }
$mods=Join-Path $run 'mods'
if (-not $ReuseRun) {
New-Item -ItemType Directory -Path $mods -Force | Out-Null
foreach ($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
    New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
}
foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
    if (Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json')) {
        New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null
    }
}
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
Get-ChildItem -LiteralPath $sourcePack | Copy-Item -Destination $pack -Recurse -Force
$final=Join-Path $pack 'data-final-fixes.lua'
$source=Get-Content -LiteralPath $final -Raw -Encoding UTF8
$source=$source.Replace('require("__zzz-esir-thrower-qc__/snapshot").verify()','').Replace('require("__zzz-esir-thrower-qc__/snapshot")','')
$source=$source.Replace('require("scripts/data-final-updates/thrower-performance")',"require(`"__zzz-esir-thrower-qc__/snapshot`")`nrequire(`"scripts/data-final-updates/thrower-performance`")`nrequire(`"__zzz-esir-thrower-qc__/snapshot`").verify()")
[IO.File]::WriteAllText($final,$source,[Text.UTF8Encoding]::new($false))
$helper=Join-Path $mods 'zzz-esir-thrower-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\thrower-performance') -File | Copy-Item -Destination $helper
$list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$list.mods=@($list.mods | Where-Object { $_.name -notmatch 'qc|benchmark' })
$info=Get-Content -LiteralPath (Join-Path $pack 'info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($dependency in $info.dependencies) {
    if ($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') {
        $incompatible=$Matches[1]
        foreach ($mod in $list.mods) {
            if ($mod.name -eq $incompatible) { $mod.enabled=$false }
        }
    }
}
$list.mods+=@{name='zzz-esir-thrower-qc';enabled=$true}
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$configuration=Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $configuration -Encoding UTF8
} else {
    $helper=Join-Path $mods 'zzz-esir-thrower-qc'
    $configuration=Join-Path $run 'config.ini'
    $baseline=Get-Content -LiteralPath (Join-Path $run 'original-performance.json') -Raw | ConvertFrom-Json
    if ($baseline.diagnostic) { throw 'Reuse requires a timing matrix, not diagnostic timings' }
}
$adaptation=if ($ReuseRun) {
    $match=[regex]::Match((Get-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Raw),'adaptation=(true|false)')
    if (-not $match.Success) { throw 'Missing frozen fuel-adaptation setting' }
    $match.Groups[1].Value
} else { (-not $Disabled.IsPresent).ToString().ToLowerInvariant() }
Write-Host "Thrower QC artifacts: $run"
if ($Visual) {
    # The full staging path pushes existing sprite names past Windows MAX_PATH.
    # A short, private junction lets the graphical loader resolve the same assets.
    $visualMods=Join-Path $env:TEMP ('etv-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Junction -Path $visualMods -Target $mods | Out-Null
    Write-Host "Visual mod-path alias: $visualMods"
    if ($FrozenPack) {
        # Headless timing snapshots can precede delivery of unrelated graphics.
        # Supply missing assets only; retain all frozen Lua and existing images.
        $graphicsRoot=Join-Path $repo 'exotic-space-industries-remembrance\graphics'
        $addedAssets=0
        foreach ($asset in Get-ChildItem -LiteralPath $graphicsRoot -File -Recurse) {
            $relative=$asset.FullName.Substring($graphicsRoot.Length+1)
            $destination=Join-Path $visualMods ('exotic-space-industries-remembrance\graphics\'+$relative)
            if (-not (Test-Path -LiteralPath $destination)) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                Copy-Item -LiteralPath $asset.FullName -Destination $destination
                $addedAssets++
            }
        }
        Write-Host "Supplied $addedAssets missing graphics files from the working tree"
    }
}
if ($Transition) { $Profiles=@('original','16x','2x','original') }
$previousSave=$null
foreach ($profile in $Profiles) {
    $mode=if ($Performance) {'performance'} elseif ($Behavior) {'behavior'} elseif ($Transition) {'transition'} elseif ($Visual) {'visual'} else {'combat'}
    $diagnosticValue=$Diagnostic.IsPresent.ToString().ToLowerInvariant()
    "return {profile='$profile',adaptation=$adaptation,mode='$mode',diagnostic=$diagnosticValue}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    $save=Join-Path $run "$profile.zip"
    if ($previousSave) { $save=$previousSave }
    elseif (-not $ReuseRun) {
        & $factorio --create $save --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run "$profile-create.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "Create failed: $run\$profile-create.txt" }
        if (-not (Select-String -LiteralPath (Join-Path $run "$profile-create.txt") -Pattern 'THROWER_QC_DATA all_pass=true' -Quiet)) { throw 'Missing prototype assertions' }
    }
    Write-Host "$profile prototype checks passed"
    if ($Transition) {
        $serverSettings=Join-Path $run 'server-settings.json'
        $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name='ESIR thrower transition QC';$server.description='Disposable local fixture';$server.auto_pause=$false
        $server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false
        $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverSettings -Encoding UTF8
        $savedPath=Join-Path $run "saves\thrower-transition-$profile.zip"
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $started=Get-Date
        $arguments=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$serverSettings+'"'),'--port','34198','--config',('"'+$configuration+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run "$profile-server.txt") -RedirectStandardError (Join-Path $run "$profile-server-error.txt")
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            $ready=$false;$deadline=(Get-Date).AddMinutes(4)
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
                if ((Test-Path -LiteralPath $savedPath) -and (Get-Item -LiteralPath $savedPath).LastWriteTime -gt $started) {
                    try { $zip=[IO.Compression.ZipFile]::OpenRead($savedPath);$zip.Dispose();$ready=$true;break } catch { }
                }
                Start-Sleep -Milliseconds 500;$process.Refresh()
            }
            if (-not $ready) { throw "Transition failed: $run\$profile-server.txt" }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
        $previousSave=$savedPath
        Write-Host "$profile transition saved"
        continue
    }
    if ($Visual) {
        '427520' | Set-Content -LiteralPath (Join-Path $run 'steam_appid.txt') -Encoding ASCII
        $arguments=@('--benchmark-graphics',('"'+$save+'"'),'--benchmark-ticks','1401','--config',('"'+$configuration+'"'),'--mod-directory',('"'+$visualMods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WorkingDirectory $run -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run "$profile-client.txt") -RedirectStandardError (Join-Path $run "$profile-client-error.txt")
        # Keep a process handle: Windows PowerShell can otherwise lose ExitCode
        # when a short-lived redirected process is refreshed after termination.
        $null=$process.Handle
        try {
            $deadline=(Get-Date).AddMinutes(6)
            while (-not $process.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500;$process.Refresh() }
            if (-not $process.HasExited) { throw "Visual run timed out: $run\$profile-client.txt" }
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { throw "Visual run failed (exit $($process.ExitCode)): $run\$profile-client.txt" }
            if (-not (Test-Path -LiteralPath (Join-Path $run "script-output\thrower-$profile-1380-0.5.png"))) { throw 'No final tail screenshots produced' }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
        continue
    }
    if (-not $DataOnly) {
        $ticks=if ($Performance) {21601} elseif ($Behavior) {3601} else {10801}
        $runs=if ($Performance -and -not $Diagnostic) {3} else {1}
        $extra=if ($Performance -and -not $Diagnostic) {@('--benchmark-verbose','wholeUpdate')} else {@()}
        $suffix=if ($Performance -and $Diagnostic) {'-diagnostic'} else {''}
        & $factorio --benchmark $save --benchmark-ticks $ticks --benchmark-runs $runs @extra --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run "$profile-$mode$suffix.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "Benchmark failed: $run\$profile-$mode$suffix.txt" }
        $report=if ($Performance) {'thrower-performance.json'} elseif ($Behavior) {'thrower-behavior.json'} else {'thrower-report.json'}
        Copy-Item -LiteralPath (Join-Path $run "script-output\$report") -Destination (Join-Path $run "$profile-$mode$suffix.json")
        Write-Host "$profile $mode report written"
    }
}
if ($Transition) {
    "return {profile='original',adaptation=$adaptation,mode='expiry'}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    & $factorio --benchmark $previousSave --benchmark-ticks 7802 --benchmark-runs 1 --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run 'expiry.txt') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw "Expiry failed: $run\expiry.txt" }
    Copy-Item -LiteralPath (Join-Path $run 'script-output\thrower-expiry.json') -Destination (Join-Path $run 'expiry.json')
    Write-Host 'Saved effects expired naturally'
}
