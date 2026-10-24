[CmdletBinding()]
param(
    [string]$ModelPath = 'C:\Users\Theorun\Documents\Development\sniper-turret-prototype-4.glb',
    [string]$OutputRoot = 'D:\ESIR\output\meshy\sniper-turret-prototype-4\preview-20261019',
    [ValidateSet('preset-default', 'rail-fill', 'gamma-rescue')]
    [string]$Profile = 'preset-default',
    [int]$Resolution = 768,
    [int]$Samples = 32,
    [int]$Directions = 8,
    [switch]$PreflightOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$blenderExe = 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
$renderer = Join-Path $repoRoot '.codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py'
$sourcePreset = Join-Path $repoRoot 'factorioRenderingPreset_v4.blend'
$ModelPath = (Resolve-Path -LiteralPath $ModelPath).Path
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$previewPreset = Join-Path $OutputRoot 'factorio-preview.blend'

# The preset's Blender 5.1 compositor paths are relative to its .blend directory.
# A local copy plus matching cwd keeps the existing renderer usable across drives.
if (-not (Test-Path -LiteralPath $previewPreset)) {
    Copy-Item -LiteralPath $sourcePreset -Destination $previewPreset
}
if ((Get-FileHash -LiteralPath $sourcePreset).Hash -ne (Get-FileHash -LiteralPath $previewPreset).Hash) {
    throw 'The staging preset differs from the source preset; choose a fresh OutputRoot.'
}

$variant = if ($PreflightOnly) { 'preflight' } else { $Profile }
$renderRoot = Join-Path $OutputRoot $variant
$renderArgs = @(
    '--background', '--factory-startup', '--python-exit-code', '1',
    '--python', $renderer, '--', '--base-dir', $repoRoot,
    '--preset-blend', $previewPreset, '--input', $ModelPath,
    '--asset-name', "sniper-turret-prototype-4-$Profile",
    '--output-dir', $renderRoot,
    '--frames', "$Directions", '--directions', "$Directions", '--animation-frames', '1',
    '--resolution', "$Resolution", '--samples', "$Samples", '--ortho-scale', '3',
    '--auto-prep', '--prep-origin-mode', 'ground', '--passes', 'object,shadow',
    '--material-report', '--fail-framing-risk', '--quality', 'smoke',
    '--lighting-profile', $Profile, '--pack-sheets', '--grid', "${Directions}x1"
)
if ($PreflightOnly) { $renderArgs += '--preflight-only' }

$sourceHash = (Get-FileHash -LiteralPath $ModelPath -Algorithm SHA256).Hash
$replay = [ordered]@{
    source = $ModelPath; source_sha256 = $sourceHash
    source_bytes = (Get-Item -LiteralPath $ModelPath).Length
    preset_sha256 = (Get-FileHash -LiteralPath $sourcePreset -Algorithm SHA256).Hash
    blender = $blenderExe; arguments = $renderArgs; working_directory = $OutputRoot
    profile = $Profile; resolution = $Resolution; samples = $Samples
    started_utc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Draft model preview; each complete model rotates as one assembly.'
}
$replayPath = Join-Path $OutputRoot "replay-$variant.json"
$replay | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $replayPath -Encoding utf8
Push-Location -LiteralPath $OutputRoot
try {
    & $blenderExe @renderArgs
    $renderExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($renderExitCode -ne 0) { throw "Blender failed with exit code $renderExitCode." }
if ((Get-FileHash -LiteralPath $ModelPath -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'The source model changed during rendering.'
}
$replay['completed_utc'] = [DateTime]::UtcNow.ToString('o')
$replay['exit_code'] = $renderExitCode
$replay | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $replayPath -Encoding utf8
Write-Output "preview_render=$renderRoot"
