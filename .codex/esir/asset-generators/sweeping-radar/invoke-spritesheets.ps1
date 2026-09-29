[CmdletBinding()]
param([ValidateSet('sweeping-radar','phased-array-radar','both')][string]$Asset='both',
      [ValidateSet('Render','Pack','Check','All')][string]$Stage='All',
      [ValidateRange(1,256)][int]$Facings=256,
      [ValidateRange(1,256)][int]$StartFrame=1,
      [ValidateRange(1,256)][int]$EndFrame=256,
      [ValidateSet('cpu','cuda')][string]$ComputeDevice='cpu')
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath 'exotic-space-industries-remembrance/info.json')){throw 'Run from the ESIR repository root.'}
$source=$PSScriptRoot
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
$assets=if($Asset -eq 'both'){@('sweeping-radar','phased-array-radar')}else{@($Asset)}
if(256 % $Facings -ne 0){throw 'Exact subsets must divide 256; use 256, 128, 64, 32, 16, 8, 4, 2, or 1.'}
foreach($name in $assets){
    $root=Join-Path (Get-Location) ('output/meshy/'+$name)
    if($Stage -in @('Render','All')){
        $passes=if($name -eq 'phased-array-radar'){'object,shadow,light-alpha'}else{'object,shadow'}
        # Blender emits preset startup warnings on stderr before configuration.
        # Preserve those diagnostics while treating its exit status as authority.
        $ErrorActionPreference='Continue'
        & $blender --factory-startup --background --threads 8 --python-exit-code 1 --python (Join-Path $source 'render_radar.py') -- --preset-blend factorioRenderingPreset_v4.blend --input (Join-Path $root "prepared/$name.blend") --asset-name "$name-master-256" --output-dir (Join-Path $root 'master-256/Render') --frames 256 --directions 256 --animation-frames 1 --grid 8x16 --ortho-scale 6 --tile-size 64 --no-normalize --passes $passes --quality final --samples 256 --cycles-compute-device $ComputeDevice --material-report --footprint-tiles 3x3 --radar-master --radar-start $StartFrame --radar-end $EndFrame
        $renderExit=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($renderExit -ne 0){throw "Master rendering failed: $name ($renderExit)"}
    }
    if($Stage -in @('Pack','All')){
        python -B (Join-Path $source 'spritesheets.py') pack --asset $name --facings $Facings
        if($LASTEXITCODE -ne 0){throw "Spritesheet packing failed: $name"}
    }
    if($Stage -in @('Check','All')){
        python -B (Join-Path $source 'spritesheets.py') check --asset $name --facings $Facings
        if($LASTEXITCODE -ne 0){throw "Spritesheet checks failed: $name"}
    }
}
