[CmdletBinding()]
param([ValidateSet('All','assembled','head-only','base')][string]$Role='All')
$ErrorActionPreference='Stop'
$root=if($env:ESIR_ACID_STAGING_ROOT){$env:ESIR_ACID_STAGING_ROOT}else{Join-Path (Get-Location).Path 'output/meshy/acidthrower-turret'}
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
$env:CUDA_CACHE_PATH=Join-Path $root 'cache/cuda'
New-Item -ItemType Directory -Path $env:CUDA_CACHE_PATH -Force | Out-Null
foreach($part in @('assembled','head-only','base')) {
    if($Role -ne 'All' -and $Role -ne $part){continue}
    $frames=if($part -eq 'base'){4}else{8}
    $grid=if($part -eq 'base'){'4x1'}else{'4x2'}
    $env:ESIR_ACID_ASSEMBLED=if($part -eq 'assembled'){'1'}else{'0'}
    $arguments=@('--factory-startup','--background','--python-exit-code','1',
        '--python',(Join-Path $root 'render_model.py'),'--',
        '--preset-blend','factorioRenderingPreset_v4.blend',
        '--input',(Join-Path $root "prepared/$part.glb"),
        '--asset-name',"acidthrower-$part-preview",'--output-dir',(Join-Path $root "comparison-renders/$part"),
        '--frames',"$frames",'--directions',"$frames",'--animation-frames','1','--grid',$grid,
        '--initial-angle','0','--ortho-scale','7','--tile-size','64','--no-normalize','--no-auto-ortho-scale',
        '--passes','object,shadow','--quality','smoke','--samples','16','--cycles-compute-device','cuda',
        '--material-report','--fail-framing-risk')
    $acidOldPreference=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    & $blender @arguments *> (Join-Path $root "render-$part.log")
    $acidRenderExit=$LASTEXITCODE
    $ErrorActionPreference=$acidOldPreference
    if($acidRenderExit -ne 0){throw "Comparison render failed: $part"}
    Write-Output "Completed $part"
}
