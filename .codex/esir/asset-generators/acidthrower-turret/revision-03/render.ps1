param([string]$ArtifactRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03',[switch]$BaseOnly)
$ErrorActionPreference='Stop'
$env:ESIR_ACID_REVISION_ROOT=$ArtifactRoot
$env:CUDA_CACHE_PATH=Join-Path $ArtifactRoot 'cache/cuda'
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
$parts=@(@{name='base';input='base';frames=4;grid='4x1'})
if(-not $BaseOnly){$parts+=@{name='head';input='head-centred';frames=256;grid='16x16'}}
foreach($part in $parts){
    $arguments=@('--factory-startup','--background','--python-exit-code','1','--python',"$ArtifactRoot/render_model.py",'--',
        '--preset-blend','factorioRenderingPreset_v4.blend','--input',"$ArtifactRoot/prepared/$($part.input).glb",
        '--asset-name',"acidthrower-revision03-$($part.name)",'--output-dir',"$ArtifactRoot/renders/$($part.name)",
        '--frames',$part.frames,'--directions',$part.frames,'--animation-frames','1','--grid',$part.grid,
        '--initial-angle','0','--ortho-scale','7','--tile-size','64','--no-normalize','--no-auto-ortho-scale',
        '--passes','object,shadow','--quality','final','--samples','64','--cycles-compute-device','cuda',
        '--material-report','--fail-framing-risk')
    $ErrorActionPreference='Continue'
    & $blender @arguments *> "$ArtifactRoot/render-$($part.name).log"
    $ErrorActionPreference='Stop'
    if($LASTEXITCODE -ne 0){throw "Render failed: $ArtifactRoot/render-$($part.name).log"}
    Write-Output "Completed $($part.name)"
}
