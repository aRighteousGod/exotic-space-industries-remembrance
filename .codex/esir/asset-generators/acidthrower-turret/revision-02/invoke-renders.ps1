[CmdletBinding()]
param([ValidateSet('base','assembled','head-only','all')][string]$Role='all')
$ErrorActionPreference='Stop'
$acidRoot=if($env:ESIR_ACID_REVISION_ROOT){$env:ESIR_ACID_REVISION_ROOT}else{'D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'}
$env:ESIR_ACID_REVISION_ROOT=$acidRoot
$env:CUDA_CACHE_PATH=Join-Path $acidRoot 'cache/cuda'
New-Item -ItemType Directory -Path $env:CUDA_CACHE_PATH -Force | Out-Null
foreach($part in @('base','assembled','head-only')){
    if($Role -ne 'all' -and $Role -ne $part){continue}
    $frames=if($part -eq 'base'){4}else{20}
    $animation=if($part -eq 'base'){1}else{5}
    $grid=if($part -eq 'base'){'4x1'}else{'5x4'}
    $acidArgs=@('--factory-startup','--background','--python-exit-code','1',
        '--python',(Join-Path $acidRoot 'render_revision.py'),'--',
        '--preset-blend','factorioRenderingPreset_v4.blend','--input',(Join-Path $acidRoot "prepared/$part.glb"),
        '--asset-name',"acidthrower-revision02-$part",'--output-dir',(Join-Path $acidRoot "renders/$part"),
        '--frames',"$frames",'--directions','4','--animation-frames',"$animation",'--grid',$grid,
        '--initial-angle','0','--ortho-scale','7','--tile-size','64','--no-normalize','--no-auto-ortho-scale',
        '--passes','object,shadow','--quality','smoke','--samples','32','--cycles-compute-device','cuda',
        '--material-report','--fail-framing-risk')
    $acidPreference=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    & 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' @acidArgs *> (Join-Path $acidRoot "render-$part.log")
    $acidExit=$LASTEXITCODE
    $ErrorActionPreference=$acidPreference
    if($acidExit -ne 0){throw "Revision render failed: $part"}
    Write-Output "Completed $part"
}
