[CmdletBinding()]
param(
    [ValidateSet('stage','dump','create','benchmark')][string]$Task = 'dump',
    [string]$RunRoot = (Join-Path (Get-Location).Path '.factorio-qc/21'),
    [string]$Engine = (Join-Path (Get-Location).Path '.factorio-qc/f21/bin/x64/factorio.exe'),
    [string]$DependencyRoot = (Join-Path (Get-Location).Path '.factorio-qc/managed/0422e48554e14570806ee8e7c009f9a8/dependencies'),
    [string]$Save,
    [string]$Tag,
    [int]$Ticks = 600,
    [string[]]$FixtureRoot = @(),
    [switch]$AirOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$engineData = [IO.Path]::GetFullPath((Join-Path (Split-Path $Engine -Parent) '../../data'))
$version = (Get-Content -Raw -LiteralPath (Join-Path $engineData 'base/info.json') | ConvertFrom-Json).version
if ($version -ne '2.1.23') { throw "Expected engine data 2.1.23, found $version" }
$engineVersion = & $Engine --version
if ($engineVersion -notmatch 'Version: 2\.1\.23 ') { throw 'Executable version does not match 2.1.23.' }
$mods = Join-Path $RunRoot 'mods'
New-Item -ItemType Directory -Force -Path $mods | Out-Null
$enabled = @('base','space-age','quality','elevated-rails','recycler')
foreach ($zip in Get-ChildItem -LiteralPath $DependencyRoot -Filter '*.zip') {
    if ($AirOnly -and $zip.Name -notlike 'air-scrubber_*') { continue }
    $destination = Join-Path $mods $zip.Name
    if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $zip.FullName -Destination $destination }
    $enabled += ($zip.BaseName -replace '_\d+\.\d+\.\d+$','')
}
if (-not $AirOnly) {
    $sources = @(Get-ChildItem -LiteralPath $repo -Directory | Where-Object {
        $_.Name -eq 'exotic-space-industries-remembrance' -or
        $_.Name -match '^exotic-space-industries-remembrance-(graphics|soundtrack)-[1-6]$' -or
        $_.Name -in @('doeworks-deer-continued','enhanced-walls-continued')
    } | Select-Object -ExpandProperty FullName)
    $sources += 'C:\Users\Theorun\Documents\github\nonstandard-beacons-continued'
    foreach ($source in $sources) {
        $info = Get-Content -Raw -LiteralPath (Join-Path $source 'info.json') | ConvertFrom-Json
        if ($info.factorio_version -ne '2.1') { throw "Wrong source version: $source" }
        $destination = Join-Path $mods $info.name
        if (-not (Test-Path -LiteralPath $destination)) {
            New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
        }
        $enabled += $info.name
    }
}
foreach ($fixture in $FixtureRoot) {
    $fixturePath = (Resolve-Path -LiteralPath $fixture).Path
    $info = Get-Content -Raw -LiteralPath (Join-Path $fixturePath 'info.json') | ConvertFrom-Json
    if ($info.factorio_version -ne '2.1' -or $info.name -notlike 'esir-qc-*') {
        throw "Fixture must be a separate esir-qc-* mod targeting 2.1: $fixturePath"
    }
    $destination = Join-Path $mods $info.name
    if (-not (Test-Path -LiteralPath $destination)) {
        New-Item -ItemType Junction -Path $destination -Target $fixturePath | Out-Null
    } elseif ((Get-Item -LiteralPath $destination).Target -ne $fixturePath) {
        throw "Existing fixture destination is not the requested source: $destination"
    }
    $enabled += $info.name
}
$modList = @{mods=@($enabled | Sort-Object -Unique | ForEach-Object { @{name=$_;enabled=$true} })}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($modList | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$config = Join-Path $RunRoot 'config.ini'
$configText = "[path]`nread-data=$engineData`nwrite-data=$RunRoot`n[other]`ncheck-updates=false`n"
[IO.File]::WriteAllText($config,$configText,[Text.UTF8Encoding]::new($false))
if ($Task -eq 'stage') { Write-Output $RunRoot; exit 0 }
if (-not $Tag) { $Tag = "$Task-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
$arguments = @('--config',$config,'--mod-directory',$mods,'--disable-audio')
switch ($Task) {
    'dump' { $arguments += '--dump-data' }
    'create' {
        if (-not $Save) { $Save = Join-Path $RunRoot 'fresh.zip' }
        $arguments += @('--create',$Save)
    }
    'benchmark' {
        if (-not $Save) { $Save = Join-Path $RunRoot 'fresh.zip' }
        $arguments += @('--benchmark',$Save,'--benchmark-ticks',"$Ticks",'--benchmark-runs','1')
    }
}
& $Engine @arguments 2>&1 | Tee-Object -FilePath (Join-Path $RunRoot "$Tag.stdout.log")
$code = $LASTEXITCODE
if (Test-Path -LiteralPath (Join-Path $RunRoot 'factorio-current.log')) {
    Copy-Item -LiteralPath (Join-Path $RunRoot 'factorio-current.log') -Destination (Join-Path $RunRoot "$Tag.factorio.log")
}
exit $code
