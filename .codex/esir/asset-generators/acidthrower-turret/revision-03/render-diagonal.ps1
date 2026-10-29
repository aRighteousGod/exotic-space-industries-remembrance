[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactRoot,
    [Parameter(Mandatory)][string]$SourceRoot,
    [string]$Blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe',
    [switch]$Promote)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $ArtifactRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot 'model-anchors.json') -Destination (Join-Path $ArtifactRoot 'model-anchors.json')
$env:ESIR_ACID_REVISION_ROOT=$ArtifactRoot
$env:CUDA_CACHE_PATH=Join-Path $ArtifactRoot 'cuda-cache'
$arguments=@('--factory-startup','--background','--python-exit-code','1','--python',(Join-Path $PSScriptRoot 'render_model.py'),'--',
    '--preset-blend','factorioRenderingPreset_v4.blend','--input',(Join-Path $SourceRoot 'prepared/base.glb'),
    '--asset-name','acidthrower-diagonal-base','--output-dir',(Join-Path $ArtifactRoot 'renders/base'),
    '--frames','4','--directions','4','--animation-frames','1','--grid','4x1','--initial-angle','45',
    '--ortho-scale','7','--tile-size','64','--no-normalize','--no-auto-ortho-scale',
    '--passes','object,shadow','--quality','final','--samples','64','--cycles-compute-device','cuda','--material-report','--fail-framing-risk')
$ErrorActionPreference='Continue'
& $Blender @arguments *> (Join-Path $ArtifactRoot 'render.log')
$renderExit=$LASTEXITCODE
$ErrorActionPreference='Stop'
if($renderExit -ne 0){throw "Diagonal rendering failed: $ArtifactRoot/render.log"}
$packing=@('-B',(Join-Path $PSScriptRoot 'pack_diagonal.py'),'--root',$ArtifactRoot)
if($Promote){$packing+=@('--promote','exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret')}
& python @packing
if($LASTEXITCODE -ne 0){throw 'Diagonal layer packing failed'}
