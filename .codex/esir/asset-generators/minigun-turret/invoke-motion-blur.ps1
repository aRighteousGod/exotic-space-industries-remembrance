param(
    [ValidateSet('All','Render','Review')][string]$Phase='All',
    [int]$Samples=256,
    [string]$Blender='C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$out=Join-Path $repo 'output\meshy\minigun-prototypes\prototype-2\handoff-256\motion-blur'
$prepared=Join-Path $repo 'output\meshy\minigun-prototypes\prototype-2\handoff-256\prepared\minigun-render-scene.blend'
if(-not (Test-Path -LiteralPath $prepared)){throw 'Prepare and preflight prototype 2 before running this retained-scene inspection.'}
Push-Location -LiteralPath $repo
try {
    if($Phase -in @('All','Render')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $out 'implementation') | Out-Null
        foreach($leaf in @('render_motion_blur.py','build_motion_blur_review.py','invoke-motion-blur.ps1','MOTION-BLUR-INSPECTION.md')) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $leaf) -Destination (Join-Path $out "implementation\$leaf") -Force
        }
        # Native warnings are retained in the log; the actual process exit code decides success.
        $ErrorActionPreference='Continue'
        & $Blender --factory-startup --background --threads 8 --python-exit-code 1 --python (Join-Path $PSScriptRoot 'render_motion_blur.py') -- --samples $Samples *> (Join-Path $out 'render.log')
        $renderExit=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($renderExit -ne 0){throw "Motion-blur render failed ($renderExit); see $out\render.log"}
    }
    if($Phase -in @('All','Review')) {
        & python (Join-Path $PSScriptRoot 'build_motion_blur_review.py')
        if($LASTEXITCODE -ne 0){throw 'Motion-blur review checks failed.'}
    }
} finally { Pop-Location }
