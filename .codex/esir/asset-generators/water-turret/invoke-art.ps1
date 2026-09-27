[CmdletBinding()]
param([ValidateSet('Prepare','Base','Head','Icon','Export','All')][string]$Stage='All')
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
if(-not(Test-Path -LiteralPath (Join-Path $repo 'exotic-space-industries-remembrance/info.json'))){throw 'Run from the ESIR repository root.'}
$source=Join-Path $repo '.codex/esir/asset-generators/water-turret'
$root=Join-Path $repo 'output/meshy/water-turret'
$blender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
$env:CUDA_CACHE_PATH=Join-Path $root 'cache/cuda'
New-Item -ItemType Directory -Force $env:CUDA_CACHE_PATH | Out-Null
if($Stage -in @('Prepare','All')){
    & $blender --factory-startup --background --python-exit-code 1 --python (Join-Path $source 'prepare_model.py')
    if($LASTEXITCODE -ne 0){throw 'Model preparation failed.'}
}
foreach($role in @('base','head','icon')){
    if($Stage -ne 'All' -and $Stage.ToLowerInvariant() -ne $role){continue}
    $frames=if($role -eq 'head'){64}elseif($role -eq 'base'){4}else{1}
    $grid=if($role -eq 'head'){'8x8'}elseif($role -eq 'base'){'4x1'}else{'1x1'}
    $passes=if($role -eq 'head'){'object,shadow,mask'}elseif($role -eq 'base'){'object,shadow'}else{'object'}
    $inputRole=if($role -eq 'icon'){'assembled'}else{$role}
    $angle=if($role -eq 'icon'){135}else{0}
    $tileSize=if($role -eq 'icon'){96}else{64}
    $env:ESIR_WATER_ASSEMBLED=if($role -eq 'icon'){'1'}else{'0'}
    $env:ESIR_WATER_ICON=if($role -eq 'icon'){'1'}else{'0'}
    $arguments=@('--factory-startup','--background','--python-exit-code','1','--python',(Join-Path $source 'render_model.py'),'--',
        '--preset-blend','factorioRenderingPreset_v4.blend','--input',(Join-Path $root "prepared-3x3/$inputRole.glb"),
        '--asset-name',"water-turret-$role",'--output-dir',(Join-Path $root "$role/Render"),
        '--frames',"$frames",'--directions',"$frames",'--animation-frames','1','--grid',$grid,
        '--initial-angle',"$angle",'--ortho-scale','9','--tile-size',"$tileSize",'--no-normalize','--no-auto-ortho-scale',
        '--passes',$passes,'--quality','final','--samples','64','--cycles-compute-device','cuda','--pack-sheets',
        '--material-report','--fail-framing-risk','--save-blend',(Join-Path $root "$role/water-turret-$role.blend"))
    & $blender @arguments
    if($LASTEXITCODE -ne 0){throw "Render failed: $role"}
}
if($Stage -in @('Export','All')){
    $exporter='.codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py'
    foreach($role in @('base','head')){
        $grid=if($role -eq 'head'){'8x8'}else{'4x1'}
        $field=if($role -eq 'head'){'prepared_animation'}else{'graphics_set'}
        & python $exporter render-bundle --asset-name "water-turret-$role" --bundle "$root/$role/Render" --pack-raw-frames --grid $grid --preset-manifest "$root/$role/Render/factorio-preset-render-manifest.json" --output-dir "$root/$role/factorio-export" --prototype-kind turret --snippet-template turret --target-field $field --target-prototype-type fluid-turret --target-prototype-name ei-water-turret --prototype-mode entity --scale 0.5 --shift 0,0
        if($LASTEXITCODE -ne 0){throw "Export failed: $role"}
    }
    & python $exporter icon --asset-name water-turret --source "$root/icon/Render/Object/0001.png" --output-dir "$root/icon/factorio-export" --target-prototype-name ei-water-turret --canvas-size 128 --fit-size 120 --mip-sizes 64,32
    if($LASTEXITCODE -ne 0){throw 'Item icon export failed.'}
    & python $exporter icon --asset-name water-turret-technology --source "$root/icon/Render/Object/0001.png" --output-dir "$root/technology/factorio-export" --target-prototype-name ei-water-turret --prototype-kind technology --canvas-size 256 --fit-size 240 --mip-sizes 128
    if($LASTEXITCODE -ne 0){throw 'Technology icon export failed.'}
    Copy-Item -LiteralPath (Join-Path $source 'preview.html') -Destination (Join-Path $root 'index.html') -Force
    & python (Join-Path $source 'check-art.py')
    if($LASTEXITCODE -ne 0){throw 'Frame packing, margins or mask validation failed.'}
}
