[CmdletBinding()]
param([ValidateSet('sweeping-radar','phased-array-radar','both')][string]$Asset='both',
      [ValidateSet('Prepare','Render','Check','All')][string]$Stage='All',
      [ValidateSet('cuda','cpu')][string]$ComputeDevice='cpu')
$ErrorActionPreference='Stop'
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
$source=$PSScriptRoot
if(-not(Test-Path -LiteralPath 'exotic-space-industries-remembrance/info.json')){throw 'Run from the ESIR repository root.'}
$gallery=Join-Path (Get-Location) 'output/meshy/radar-production'
New-Item -ItemType Directory -Force -Path $gallery | Out-Null
foreach($document in @('index.html','README-source.md')){
    $inputFile=Join-Path $source $document
    $outputFile=Join-Path $gallery $document
    if([IO.Path]::GetFullPath($inputFile) -ne [IO.Path]::GetFullPath($outputFile)){
        Copy-Item -LiteralPath $inputFile -Destination $outputFile -Force
    }
}
$assets=if($Asset -eq 'both'){@('sweeping-radar','phased-array-radar')}else{@($Asset)}
$env:CUDA_CACHE_PATH=Join-Path (Get-Location) 'output/meshy/radar-production/cache/cuda'
New-Item -ItemType Directory -Force -Path $env:CUDA_CACHE_PATH | Out-Null
foreach($name in $assets){
    $root=Join-Path (Get-Location) ('output/meshy/'+$name)
    if($Stage -in @('Prepare','All')){
        & $blender --factory-startup --background --python-exit-code 1 --python (Join-Path $source 'inspect_blender.py') -- --input (Join-Path $root 'source/attempt-01.glb') --output (Join-Path $root 'inspection')
        if($LASTEXITCODE -ne 0){throw "Inspection failed: $name"}
        & $blender --factory-startup --background --python-exit-code 1 --python (Join-Path $source 'prepare_radar.py') -- --asset $name
        if($LASTEXITCODE -ne 0){throw "Preparation failed: $name"}
    }
    if($Stage -in @('Render','All')){
        $passes=if($name -eq 'phased-array-radar'){'object,shadow,light-alpha'}else{'object,shadow'}
        & $blender --factory-startup --background --python-exit-code 1 --python (Join-Path $source 'render_radar.py') -- --preset-blend factorioRenderingPreset_v4.blend --input (Join-Path $root "prepared/$name.blend") --asset-name "$name-review" --output-dir (Join-Path $root 'review/Render') --frames 8 --directions 8 --animation-frames 1 --grid 4x2 --ortho-scale 6 --tile-size 64 --no-normalize --passes $passes --quality smoke --samples 16 --cycles-compute-device $ComputeDevice --pack-sheets --material-report --footprint-tiles 3x3 --save-blend (Join-Path $root 'review/review.blend')
        if($LASTEXITCODE -ne 0){throw "Review rendering failed: $name"}
        python -B (Join-Path $source 'pack_review.py') --asset $name
        if($LASTEXITCODE -ne 0){throw "Raw frame packing failed: $name"}
    }
    if($Stage -in @('Check','All')){
        & $blender --factory-startup --background --python-exit-code 1 --python (Join-Path $source 'check_rig.py') -- --asset $name
        if($LASTEXITCODE -ne 0){throw "Rig checks failed: $name"}
    }
}
