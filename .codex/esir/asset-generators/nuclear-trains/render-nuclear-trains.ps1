[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("all", "goliath-rotated", "goliath-sloped", "black-ark-rotated", "black-ark-sloped")]
    [string] $Variant = "all",
    [int] $Samples = 64,
    [string] $Blender = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$renderScript = Join-Path $repo ".codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py"
$preset = Join-Path $repo "factorioRenderingPreset_v4.blend"
$modelRoot = Join-Path $repo "models"

$variants = @(
    @{
        Name = "goliath-rotated"
        Model = Join-Path $modelRoot "goliath.glb"
        Output = Join-Path $repo "output\meshy\nuclear-trains\goliath-rotated\Render"
        Asset = "ei-nuclear-locomotive-rotated"
        Frames = 256
        Directions = 256
        AnimationFrames = 1
        Grid = "16x16"
        Sloped = $false
    },
    @{
        Name = "goliath-sloped"
        Model = Join-Path $modelRoot "goliath.glb"
        Output = Join-Path $repo "output\meshy\nuclear-trains\goliath-sloped\Render"
        Asset = "ei-nuclear-locomotive-sloped"
        Frames = 160
        Directions = 32
        AnimationFrames = 5
        Grid = "16x10"
        Sloped = $true
    },
    @{
        Name = "black-ark-rotated"
        Model = Join-Path $modelRoot "black-ark-cargo-wagon.glb"
        Output = Join-Path $repo "output\meshy\nuclear-trains\black-ark-rotated\Render"
        Asset = "ei-advanced-cargo-wagon-rotated"
        Frames = 128
        Directions = 128
        AnimationFrames = 1
        Grid = "16x8"
        Sloped = $false
        BackEqualsFront = $true
    },
    @{
        Name = "black-ark-sloped"
        Model = Join-Path $modelRoot "black-ark-cargo-wagon.glb"
        Output = Join-Path $repo "output\meshy\nuclear-trains\black-ark-sloped\Render"
        Asset = "ei-advanced-cargo-wagon-sloped"
        Frames = 80
        Directions = 16
        AnimationFrames = 5
        Grid = "16x5"
        Sloped = $true
        BackEqualsFront = $true
    }
)

foreach ($entry in $variants) {
    if ($Variant -ne "all" -and $Variant -ne $entry.Name) {
        continue
    }

    $args = @(
        "--factory-startup",
        "--background",
        "--python", $renderScript,
        "--",
        "--preset-blend", $preset,
        "--input", $entry.Model,
        "--asset-name", $entry.Asset,
        "--output-dir", $entry.Output,
        "--auto-prep",
        "--prep-origin-mode", "ground",
        "--prep-target-size", "7",
        "--prep-alpha-mode", "force-opaque",
        "--prep-vehicle-material-lift",
        "--prep-material-metallic", "0",
        "--prep-material-roughness", "0.76",
        "--prep-base-color-gamma", "0.74",
        "--prep-base-color-value", "1.08",
        "--frames", [string] $entry.Frames,
        "--directions", [string] $entry.Directions,
        "--animation-frames", [string] $entry.AnimationFrames,
        "--resolution", "384",
        "--ortho-scale", "8",
        "--passes", "object,shadow,light-alpha-reduced,light-alpha,mask",
        "--quality", "final",
        "--samples", [string] $Samples,
        "--cycles-compute-device", "cpu",
        "--material-report",
        "--warn-alpha-materials",
        "--pack-sheets",
        "--grid", $entry.Grid,
        "--preflight-margin", "0.08",
        "--auto-ortho-max", "9",
        "--footprint-tiles", "2x6",
        "--denoise",
        "--preset-sun-energy-scale", "1.40",
        "--preset-world-strength-scale", "3.00"
    )

    if ($entry.BackEqualsFront) {
        $args += @("--back-equals-front")
    }

    if ($entry.Sloped) {
        $args += @(
            "--rolling-stock-sloped",
            "--slope-samples", "5",
            "--slope-angle-between-frames", "1.25",
            "--slope-axis", "y",
            "--slope-sign", "-1"
        )
    }

    if ($PSCmdlet.ShouldProcess($entry.Output, "render $($entry.Name)")) {
        Write-Host "Rendering $($entry.Name) -> $($entry.Output)"
        & $Blender @args
        if ($LASTEXITCODE -ne 0) {
            throw "Blender render failed for $($entry.Name) with exit code $LASTEXITCODE"
        }
    }
}
