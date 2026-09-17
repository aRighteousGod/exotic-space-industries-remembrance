[CmdletBinding()]
param(
    [string[]]$Profiles = @('restrained','standard','expanded','generous','industrial','massive','vast','extreme'),
    [switch]$WithK2SO,
    [switch]$SkipRuntime
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$seed = Join-Path $repo '.factorio-qc\fmqc\mods-live'
if (-not (Test-Path (Join-Path $seed 'mod-list.json'))) { throw 'Run invoke-esir-dev.ps1 -Task qc-fast to seed dependencies first.' }
$run = Join-Path $repo ('.factorio-qc\container-capacity-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$mods = Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
# Isolated mod list/settings/helper; immutable dependency archives are hard-linked.
foreach ($archive in Get-ChildItem -LiteralPath $seed -File -Filter '*.zip') {
    New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
}
foreach ($pack in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance*') {
    if (Test-Path (Join-Path $pack.FullName 'info.json')) {
        New-Item -ItemType Junction -Path (Join-Path $mods $pack.Name) -Target $pack.FullName | Out-Null
    }
}
$list = Get-Content (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods = @($list.mods | Where-Object { $_.name -notmatch '(^zzz-esir|qc$|Krastorio|^k2so)' })
if ($WithK2SO) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($name in @('Krastorio2-spaced-out','Krastorio2Assets','Krastorio2MenuSimulations','k2so-assets','flib','ChangeInserterDropLane')) {
        $archive = Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Factorio\mods') -Filter ($name + '_*.zip') | Where-Object {
            $zip = [IO.Compression.ZipFile]::OpenRead($_.FullName)
            try {
                $entry = $zip.Entries | Where-Object FullName -Match '^[^/]+/info.json$' | Select-Object -First 1
                $reader = [IO.StreamReader]::new($entry.Open())
                try { $metadata = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                $metadata.factorio_version -eq '2.0'
            } finally { $zip.Dispose() }
        } | Sort-Object { [version]($_.BaseName.Substring($name.Length + 1)) } -Descending | Select-Object -First 1
        if (-not $archive) { throw "Missing installed K2SO dependency: $name" }
        if (-not (Test-Path (Join-Path $mods $archive.Name))) {
            Copy-Item -LiteralPath $archive.FullName -Destination (Join-Path $mods $archive.Name)
        }
        $list.mods = @($list.mods | Where-Object name -ne $name)
        $list.mods += [pscustomobject]@{name=$name;enabled=$true}
    }
}
$list.mods += [pscustomobject]@{name='zzz-esir-container-qc';enabled=$true}
$list | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $mods 'mod-list.json') -Encoding UTF8
$helper = Join-Path $mods 'zzz-esir-container-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem (Join-Path $PSScriptRoot 'qc\container-capacities') | Copy-Item -Destination $helper
$configuration = Join-Path $run 'config.ini'
@('[path]', 'read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data', "write-data=$run", '[other]', 'check-updates=false') | Set-Content $configuration -Encoding UTF8
$results = @()
function Set-TestProfile([string]$Profile) {
    if ($Profile -notin @('restrained','standard','expanded','generous','industrial','massive','vast','extreme')) { throw "Invalid profile: $Profile" }
    $k2 = $WithK2SO.IsPresent.ToString().ToLowerInvariant()
    "return {profile='$Profile',k2so=$k2}" | Set-Content (Join-Path $helper 'test-config.lua') -Encoding ASCII
}
function Invoke-Fixture([string[]]$Arguments, [string]$Label) {
    $output = Join-Path $run ($Label + '.txt')
    & $factorio @Arguments --config $configuration --mod-directory $mods --disable-audio 2>&1 | Out-File -FilePath $output -Encoding UTF8
    $exitCode = $LASTEXITCODE
    Copy-Item (Join-Path $run 'factorio-current.log') (Join-Path $run ($Label + '.log'))
    if ($exitCode -ne 0) { throw "Factorio failed: $run\$Label.log" }
    if (-not (Select-String -LiteralPath (Join-Path $run ($Label + '.log')) -Pattern 'CONTAINER_QC_DATA .*all_pass=true' -Quiet)) { throw "Missing data assertions: $output" }
    Write-Host "$Label passed"
}
foreach ($profile in $Profiles) {
    Set-TestProfile $profile
    $save = Join-Path $run ($profile + '.zip')
    Invoke-Fixture @('--create',$save) "create-$profile"
    $results += [pscustomobject]@{profile=$profile;data_pass=$true}
    if (-not $SkipRuntime) {
        Invoke-Fixture @('--benchmark',$save,'--benchmark-ticks','20','--benchmark-runs','1') "runtime-$profile"
        $report = Get-Content (Join-Path $run 'script-output\container-capacity-runtime.json') -Raw | ConvertFrom-Json
        if (-not $report.all_pass -or $report.profile -ne $profile) { throw 'Runtime assertions failed.' }
        Copy-Item (Join-Path $run 'script-output\container-capacity-runtime.json') (Join-Path $run "runtime-$profile.json")
    }
}
if (-not $SkipRuntime -and 'restrained' -in $Profiles -and 'extreme' -in $Profiles) {
    foreach ($transition in @(@('restrained','extreme'),@('extreme','restrained'))) {
        $from,$to = $transition
        Set-TestProfile $to
        Invoke-Fixture @('--benchmark',(Join-Path $run "$from.zip"),'--benchmark-ticks','20','--benchmark-runs','1') "transition-$from-to-$to"
        $report = Get-Content (Join-Path $run 'script-output\container-capacity-runtime.json') -Raw | ConvertFrom-Json
        if ($report.profile -ne $to -or $report.original_profile -ne $from -or -not $report.all_pass) { throw 'Transition used incorrect startup settings.' }
        Copy-Item (Join-Path $run 'script-output\container-capacity-runtime.json') (Join-Path $run "transition-$from-to-$to.json")
    }
}
$results | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $run 'summary.json') -Encoding UTF8
Write-Host "Container capacity QC artifacts: $run"
