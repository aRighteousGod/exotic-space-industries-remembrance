[CmdletBinding()]
param([double]$HeadScale=0.75)
$ErrorActionPreference='Stop'
$acidRoot=if($env:ESIR_ACID_STAGING_ROOT){$env:ESIR_ACID_STAGING_ROOT}else{'D:/CodexArtifacts/esir-acidthrower-20261008'}
$env:ESIR_ACID_HEAD_SCALE="$HeadScale"
$env:ESIR_ACID_YAW_ANGLES='[0,90,180,270,-48,-24,24,48]'
$env:ESIR_ACID_ASSEMBLED='0'
$env:CUDA_CACHE_PATH=Join-Path $acidRoot 'cache/cuda'
$acidArguments=@('--factory-startup','--background','--python-exit-code','1',
    '--python',(Join-Path $acidRoot 'render_model.py'),'--',
    '--preset-blend','factorioRenderingPreset_v4.blend',
    '--input',(Join-Path $acidRoot 'prepared/head-only.glb'),
    '--asset-name','acidthrower-existing-base-fitted',
    '--output-dir',(Join-Path $acidRoot 'comparison-renders/head-fitted'),
    '--frames','8','--directions','8','--animation-frames','1','--grid','4x2',
    '--initial-angle','0','--ortho-scale','7','--tile-size','64','--no-normalize','--no-auto-ortho-scale',
    '--passes','object,shadow','--quality','smoke','--samples','16','--cycles-compute-device','cuda',
    '--material-report','--fail-framing-risk')
$acidOldPreference=$ErrorActionPreference
$ErrorActionPreference='Continue'
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' @acidArguments *> (Join-Path $acidRoot 'render-head-fitted.log')
$acidExit=$LASTEXITCODE
$ErrorActionPreference=$acidOldPreference
Remove-Item Env:/ESIR_ACID_HEAD_SCALE,Env:/ESIR_ACID_YAW_ANGLES
if($acidExit -ne 0){throw 'Fitted upper render failed'}
Write-Output 'Completed fitted upper: 75 percent, aligned cardinal facings and +/-48 degree arc samples.'
