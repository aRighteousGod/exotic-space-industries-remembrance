$ErrorActionPreference='Stop'
$acidRoot=if($env:ESIR_ACID_REVISION_ROOT){$env:ESIR_ACID_REVISION_ROOT}else{'D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'}
$env:ESIR_ACID_REVISION_ROOT=$acidRoot
$env:CUDA_CACHE_PATH=Join-Path $acidRoot 'cache/cuda'
$acidArgs=@('--factory-startup','--background','--python-exit-code','1',
    '--python',(Join-Path $acidRoot 'render_revision.py'),'--',
    '--preset-blend','factorioRenderingPreset_v4.blend','--input',(Join-Path $acidRoot 'prepared/assembled.glb'),
    '--asset-name','acidthrower-revision02-details','--output-dir',(Join-Path $acidRoot 'renders/details'),
    '--frames','4','--directions','4','--animation-frames','1','--grid','4x1',
    '--initial-angle','0','--ortho-scale','7','--tile-size','256','--no-normalize','--no-auto-ortho-scale',
    '--passes','object,shadow','--quality','smoke','--samples','32','--cycles-compute-device','cuda',
    '--material-report','--fail-framing-risk')
$acidPreference=$ErrorActionPreference
$ErrorActionPreference='Continue'
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' @acidArgs *> (Join-Path $acidRoot 'render-details.log')
$acidExit=$LASTEXITCODE
$ErrorActionPreference=$acidPreference
if($acidExit -ne 0){throw 'Detail renders failed'}
Write-Output 'Completed high-resolution detail renders'
