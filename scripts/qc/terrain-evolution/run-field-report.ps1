[CmdletBinding()]
param(
    [ValidateSet('en','ja','ru','de')][string]$Locale='en',
    [ValidateRange(1,2)][double]$Scale=1,
    [switch]$Quick,
    [string]$OutputRoot='.factorio-qc/efr1/en',
    [string]$SeedMods='.factorio-qc/egi1/mods',
    [string]$SaveInput='.factorio-qc/egi1/fixture.zip'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$profile=[IO.Path]::GetFullPath($OutputRoot)
$utf8=[Text.UTF8Encoding]::new($false)
& (Join-Path $repo 'scripts/invoke-terrain-evolution-qc.ps1') -HelperRoot $PSScriptRoot/field-connected `
    -SeedMods $SeedMods -SaveInput $SaveInput -PrepareOnly -OutputRoot $profile
if($LASTEXITCODE -ne 0){throw 'Field-report profile staging failed.'}
$full=$Locale -eq 'en' -and $Scale -eq 1 -and -not $Quick
$all=if($full){'true'}else{'false'}
$probes=if($full){50}else{8}
$timings=if($full){100}else{0}
$scaleText=$Scale.ToString([Globalization.CultureInfo]::InvariantCulture)
[IO.File]::WriteAllText((Join-Path $profile 'mods/zzz-esir-field-report-qc/config.lua'),
    "return {locale='$Locale',scale=$scaleText,all_planets=$all,timeout_ticks=24000,capture_prefix='ecology-field',instrumented_services=$probes,profiled_services=$timings}`n",$utf8)
$ini=@"
[path]
read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data
write-data=$profile
[other]
check-updates=false
[general]
locale=$Locale
[interface]
ui-scale-mode=manual-pixels
custom-ui-scale=$scaleText
[graphics]
full-screen=false
graphics-quality=medium
video-memory-usage=low
"@
[IO.File]::WriteAllText((Join-Path $profile 'config.ini'),$ini,$utf8)
& (Join-Path $PSScriptRoot 'run-admin.ps1') -OutputRoot $profile -TimeoutSeconds 900
