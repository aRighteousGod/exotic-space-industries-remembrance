param([string]$ArtifactRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02',
    [string[]]$Parts=@('spine','droplet','splash','flecks'))
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path "$ArtifactRoot/cache" -Force | Out-Null
$env:CUDA_CACHE_PATH="$ArtifactRoot/cache/cuda"
$env:TEMP="$ArtifactRoot/cache"; $env:TMP=$env:TEMP
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
foreach($part in @(@{name='spine';frames=16;ortho=2},@{name='droplet';frames=16;ortho=2},@{name='splash';frames=24;ortho=8},@{name='flecks';frames=16;ortho=2})){
    if($part.name -notin $Parts){continue}
    $env:ESIR_JET_PART=$part.name
    $args=@('--factory-startup','--background','--python-exit-code','1','--python',(Join-Path $PSScriptRoot 'render_fx.py'),'--',
        '--preset-blend','factorioRenderingPreset_v4.blend','--test-cube','--asset-name',"acid-pressure-$($part.name)",
        '--output-dir',"$ArtifactRoot/renders/$($part.name)",'--frames',$part.frames,'--directions','1',
        '--animation-frames',$part.frames,'--initial-angle','0','--ortho-scale',$part.ortho,'--tile-size','64',
        '--no-normalize','--no-parent-to-rotation','--passes','object,shadow','--quality','final','--samples','32',
        '--cycles-compute-device','cuda','--save-blend',"$ArtifactRoot/source/$($part.name).blend")
    $ErrorActionPreference='Continue'
    & $blender @args *> "$ArtifactRoot/render-$($part.name).log"
    $ErrorActionPreference='Stop'
    if($LASTEXITCODE -ne 0){throw "FX render failed: $($part.name)"}
    Write-Output "Rendered $($part.name)"
}
