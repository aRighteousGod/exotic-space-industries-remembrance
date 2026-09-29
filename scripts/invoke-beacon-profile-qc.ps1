[CmdletBinding()]
param(
    [ValidateSet('gentle','vanilla','strict','harsh','severe','saturating')][string[]]$Profiles=@('gentle','vanilla','strict','harsh','severe','saturating'),
    [switch]$Transition,
    [switch]$Geometry,
    [switch]$ResumeTransitions,
    [string]$ReuseRun
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$factorio='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'
$run=if ($ReuseRun) { (Resolve-Path -LiteralPath $ReuseRun).Path } else { Join-Path $repo ('.factorio-qc\bp\'+(Get-Date -Format 'MMdd-HHmmss')) }
if ($ReuseRun -and -not $run.StartsWith((Join-Path $repo '.factorio-qc\bp\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Reuse must remain inside beacon QC staging' }
$mods=Join-Path $run 'mods'
$pack=Join-Path $mods 'exotic-space-industries-remembrance'
$helper=Join-Path $mods 'zzz-esir-beacon-profile-qc'
$configuration=Join-Path $run 'config.ini'
if ($ResumeTransitions) {
    if (-not $ReuseRun) { throw '-ResumeTransitions requires a frozen run with a saved on-gentle fixture' }
    $Transition=$true
}
New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
if (-not $ReuseRun) {
    New-Item -ItemType Directory -Path $mods,$pack,$helper -Force | Out-Null
    foreach ($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
        New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
    }
    foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
        if (Test-Path -LiteralPath (Join-Path $directory.FullName 'info.json')) {
            New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null
        }
    }
    foreach ($entry in Get-ChildItem -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance')) {
        if ($entry.PSIsContainer -and $entry.Name -in @('graphics','sound','sounds','music')) {
            New-Item -ItemType Junction -Path (Join-Path $pack $entry.Name) -Target $entry.FullName | Out-Null
        } else { Copy-Item -LiteralPath $entry.FullName -Destination $pack -Recurse -Force }
    }
    $list=Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object { $_.name -notmatch 'qc|benchmark' })
    $info=Get-Content -LiteralPath (Join-Path $pack 'info.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($dependency in $info.dependencies) {
        if ($dependency -match '^!\s+(.+?)(?:\s+[<>=].*)?$') {
            $incompatible=$Matches[1]
            foreach ($mod in $list.mods) { if ($mod.name -eq $incompatible) { $mod.enabled=$false } }
        }
    }
    $list.mods+=@{name='zzz-esir-beacon-profile-qc';enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    @('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $configuration -Encoding UTF8
    $final=Join-Path $pack 'data-final-fixes.lua'
    $source=Get-Content -LiteralPath $final -Raw -Encoding UTF8
    $source=$source.Replace('require("scripts/data-final-updates/beacon-profiles")',"require(`"__zzz-esir-beacon-profile-qc__/snapshot`")`nrequire(`"scripts/data-final-updates/beacon-profiles`")")
    [IO.File]::WriteAllText($final,$source,[Text.UTF8Encoding]::new($false))
    $control=Join-Path $pack 'control.lua'
    [IO.File]::AppendAllText($control,"`n"+(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'qc\beacon-profiles\bridge.lua') -Raw -Encoding UTF8),[Text.UTF8Encoding]::new($false))
}
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\beacon-profiles') -File | Copy-Item -Destination $helper -Force
$list=Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($mod in $list.mods) { if ($mod.name -eq 'zzz-beacon-overload-geometry-qc') { $mod.enabled=$false } }
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
Write-Host "Beacon profile QC artifacts: $run"
function Invoke-Phase([string]$Profile,[bool]$Overload,[string]$Phase,[string]$LoadSave) {
    "return {profile='$Profile',overload=$($Overload.ToString().ToLowerInvariant()),phase='$Phase'}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    if (-not $LoadSave) {
        $LoadSave=Join-Path $run "$Phase.zip"
        & $factorio --create $LoadSave --map-gen-seed 42 --config $configuration --mod-directory $mods 2>&1 | Out-File -LiteralPath (Join-Path $run "$Phase-create.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "Create/data checks failed: $Phase-create.txt" }
    }
    if (-not (Test-Path -LiteralPath $LoadSave)) { throw "Missing input save: $LoadSave" }
    $report=Join-Path $run 'script-output\beacon-profile-report.json'
    if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force }
    $savedPath=Join-Path $run "saves\beacon-profile-$Phase.zip"
    if ($Transition -and ($Phase -eq 'on-gentle' -or $Phase.StartsWith('transition-'))) {
        $server=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
        $server.name='ESIR beacon profile QC';$server.description='Disposable local acceptance fixture'
        $server.visibility.public=$false;$server.visibility.lan=$false;$server.require_user_verification=$false;$server.auto_pause=$false
        $serverPath=Join-Path $run 'server-settings.json'
        $server | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $serverPath -Encoding UTF8
        if (Test-Path -LiteralPath $savedPath) { Remove-Item -LiteralPath $savedPath -Force }
        $arguments=@('--start-server',('"'+$LoadSave+'"'),'--server-settings',('"'+$serverPath+'"'),'--port','34197','--config',('"'+$configuration+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')
        $process=Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run "$Phase-runtime.txt") -RedirectStandardError (Join-Path $run "$Phase-stderr.txt")
        $null=$process.Handle
        try {
            $deadline=(Get-Date).AddMinutes(3)
            while (-not (Test-Path -LiteralPath $savedPath) -and -not $process.HasExited -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 500
                $process.Refresh()
                if (Select-String -LiteralPath (Join-Path $run "$Phase-runtime.txt") -Quiet -Pattern 'non-recoverable error|changing state.*Failed') { throw "Transition engine failure: $Phase-runtime.txt" }
            }
            if (-not (Test-Path -LiteralPath $savedPath)) { throw "Transition save failed: $Phase-runtime.txt" }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive=[IO.Compression.ZipFile]::OpenRead($savedPath)
            try { if ($archive.Entries.Count -eq 0) { throw 'Empty saved fixture' } } finally { $archive.Dispose() }
        } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
    } else {
        & $factorio --benchmark $LoadSave --benchmark-ticks 1000 --benchmark-runs 1 --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run "$Phase-runtime.txt") -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "Runtime checks failed: $Phase-runtime.txt" }
    }
    $result=Get-Content -LiteralPath $report -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $result.all_pass -or $result.profile -ne $Profile -or $result.overload -ne $Overload) { throw "Invalid report: $Phase" }
    Copy-Item -LiteralPath $report -Destination (Join-Path $run "$Phase.json") -Force
    Write-Host "$Phase passed: $($result.cases.Count) receiver layouts"
    return $savedPath
}
function Invoke-Geometry {
    $geometryDirectory=Join-Path $mods 'zzz-beacon-overload-geometry-qc'
    New-Item -ItemType Directory -Path $geometryDirectory -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo '.codex\skills\esir-dev\assets\zzz-beacon-overload-geometry-qc_0.0.1') -File | Copy-Item -Destination $geometryDirectory -Force
    '-- Profile receivers are disabled for this independent geometry replay.' | Set-Content -LiteralPath (Join-Path $helper 'control.lua') -Encoding ASCII
    "return {profile='strict',overload=true,phase='geometry'}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
    $list=Get-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $list.mods=@($list.mods | Where-Object { $_.name -ne 'zzz-beacon-overload-geometry-qc' })
    $list.mods+=@{name='zzz-beacon-overload-geometry-qc';enabled=$true}
    $list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
    $save=Join-Path $run 'geometry.zip'
    & $factorio --create $save --config $configuration --mod-directory $mods 2>&1 | Out-File -LiteralPath (Join-Path $run 'geometry-create.txt') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw 'Geometry create failed' }
    & $factorio --benchmark $save --benchmark-ticks 3600 --benchmark-runs 1 --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -LiteralPath (Join-Path $run 'geometry-runtime.txt') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw 'Geometry replay failed' }
    if (-not (Select-String -LiteralPath (Join-Path $run 'geometry-runtime.txt') -Pattern '"all_pass":true')) { throw 'Missing geometry pass result' }
    Write-Host 'Existing geometry lifecycle fixture passed'
}
if ($ResumeTransitions) {
    $enabled=Join-Path $run 'saves\beacon-profile-on-gentle.zip'
} else {
    foreach ($profile in $Profiles) { $null=Invoke-Phase $profile $false "off-$profile" '' }
    $enabled=Invoke-Phase 'gentle' $true 'on-gentle' ''
    $null=Invoke-Phase 'saturating' $true 'on-saturating' ''
}
if ($Transition) {
    $disabled=Invoke-Phase 'strict' $false 'transition-off' $enabled
    $reloaded=Invoke-Phase 'strict' $false 'transition-reload' $disabled
    $null=Invoke-Phase 'strict' $true 'transition-on' $reloaded
    foreach ($phase in @('transition-off','transition-on')) {
        $report=Get-Content -LiteralPath (Join-Path $run "$phase.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $report.startup_changed) { throw "Transition did not change actual startup settings: $phase" }
    }
}
if ($Geometry) { Invoke-Geometry }
