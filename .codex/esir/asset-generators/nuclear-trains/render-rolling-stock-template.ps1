[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("all", "goliath", "black-ark-cargo-wagon", "black-grail-fluid-wagon")]
    [string] $Variant = "all",
    [int] $Samples = 64,
    [int] $Resolution = 800,
    [ValidateSet("CPU", "GPU")]
    [string] $Device = "CPU",
    [double] $OrthoScale = 12.5,
    [double] $WorldStrengthScale = 3.0,
    [double] $AreaFillEnergy = 0,
    [double] $AreaFillSize = 8,
    [double] $RotationZDegrees = -90,
    [int] $SpritterPadding = 16,
    [switch] $SkipRender,
    [switch] $SkipSpritter,
    [switch] $Optimize,
    [string] $Blender = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$template = Join-Path $repo "rolling_stock_template.blend"
$renderScript = Join-Path $PSScriptRoot "render-rolling-stock-template.py"
$padScript = Join-Path $PSScriptRoot "pad-spritter-sheets.py"
$spritter = Join-Path $repo "spritter.exe"
$modelRoot = Join-Path $repo "models"
$renderRoot = Join-Path $repo "output\meshy\nuclear-trains\rolling-stock-template"
$graphicsRoot = Join-Path $repo "exotic-space-industries-remembrance-graphics-4\graphics\entities"

if (-not (Test-Path -LiteralPath $template)) {
    throw "Missing rolling stock template: $template"
}
if (-not (Test-Path -LiteralPath $spritter)) {
    throw "Missing spritter.exe: $spritter"
}

$variants = @(
    @{
        Name = "goliath"
        AssetName = "ei-nuclear-locomotive"
        Model = Join-Path $modelRoot "goliath.glb"
        Output = Join-Path $renderRoot "goliath"
        Graphics = Join-Path $graphicsRoot "nuclear-locomotive"
        FitLength = "7.2"
        BottomZ = "0.50"
        XOffset = "0.08"
        YOffset = "0.24"
    },
    @{
        Name = "black-ark-cargo-wagon"
        AssetName = "ei-advanced-cargo-wagon"
        Model = Join-Path $modelRoot "black-ark-cargo-wagon.glb"
        Output = Join-Path $renderRoot "black-ark-cargo-wagon"
        Graphics = Join-Path $graphicsRoot "advanced-cargo-wagon"
        FitLength = "7.0"
        BottomZ = "0.78"
        XOffset = "0"
        YOffset = "0"
    },
    @{
        Name = "black-grail-fluid-wagon"
        AssetName = "ei-advanced-fluid-wagon"
        Model = Join-Path $modelRoot "black-grail-fluid-wagon.glb"
        Output = Join-Path $renderRoot "black-grail-fluid-wagon"
        Graphics = Join-Path $graphicsRoot "advanced-fluid-wagon"
        FitLength = "7.0"
        BottomZ = "0.78"
        XOffset = "0"
        YOffset = "0"
    }
)

function Invoke-TemplateRender {
    param(
        [hashtable] $Entry,
        [string] $Layer,
        [int] $Start,
        [int] $End
    )

    $outputDir = Join-Path $Entry.Output $Layer
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $args = @(
        "--factory-startup",
        "--background",
        $template,
        "--python", $renderScript,
        "--",
        "--input", $Entry.Model,
        "--asset-name", "$($Entry.AssetName)-$Layer",
        "--output-dir", $outputDir,
        "--start", [string] $Start,
        "--end", [string] $End,
        "--resolution", [string] $Resolution,
        "--samples", [string] $Samples,
        "--device", $Device,
        "--fit-length", $Entry.FitLength,
        "--rotation-z-degrees", [string] $RotationZDegrees,
        "--bottom-z", $Entry.BottomZ,
        "--x-offset", $Entry.XOffset,
        "--y-offset", $Entry.YOffset,
        "--ortho-scale", [string] $OrthoScale,
        "--metallic", "0",
        "--roughness", "0.78",
        "--world-strength-scale", [string] $WorldStrengthScale,
        "--area-fill-energy", [string] $AreaFillEnergy,
        "--area-fill-size", [string] $AreaFillSize,
        "--force-opaque"
    )

    if ($PSCmdlet.ShouldProcess($outputDir, "render template frames $Start..$End")) {
        Write-Host "Rendering $($Entry.Name) $Layer frames $Start..$End -> $outputDir"
        & $Blender @args
        if ($LASTEXITCODE -ne 0) {
            throw "Blender render failed for $($Entry.Name) $Layer with exit code $LASTEXITCODE"
        }
    }
}

function Invoke-SpritterSheet {
    param(
        [hashtable] $Entry,
        [string] $Layer,
        [int] $MaxSheetRows
    )

    $source = Join-Path $Entry.Output $Layer
    $target = $Entry.Graphics
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing Spritter source folder for $($Entry.Name) ${Layer}: $source. Run without -SkipRender first."
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null

    $sourceArg = (Resolve-Path -LiteralPath $source).Path + [IO.Path]::DirectorySeparatorChar
    $targetArg = (Resolve-Path -LiteralPath $target).Path + [IO.Path]::DirectorySeparatorChar
    $args = @(
        "spritesheet",
        "-l",
        "-m", [string] $MaxSheetRows,
        "-w", "4",
        "--layout-mode", "fill-row",
        $sourceArg,
        $targetArg
    )

    if ($PSCmdlet.ShouldProcess($target, "spritter $($Entry.Name) $Layer")) {
        Write-Host "Packing $($Entry.Name) $Layer with Spritter -> $target"
        & $spritter @args
        if ($LASTEXITCODE -ne 0) {
            throw "Spritter failed for $($Entry.Name) $Layer with exit code $LASTEXITCODE"
        }
    }
}

foreach ($entry in $variants) {
    if ($Variant -ne "all" -and $Variant -ne $entry.Name) {
        continue
    }
    if (-not (Test-Path -LiteralPath $entry.Model)) {
        throw "Missing model: $($entry.Model)"
    }

    if (-not $SkipRender) {
        Invoke-TemplateRender -Entry $entry -Layer "body" -Start 0 -End 255
        Invoke-TemplateRender -Entry $entry -Layer "sloped" -Start 256 -End 415
    }

    if (-not $SkipSpritter) {
        Invoke-SpritterSheet -Entry $entry -Layer "body" -MaxSheetRows 8
        Invoke-SpritterSheet -Entry $entry -Layer "sloped" -MaxSheetRows 5
        if ($SpritterPadding -gt 0) {
            & python $padScript $entry.Graphics --layer body --layer sloped --padding $SpritterPadding
            if ($LASTEXITCODE -ne 0) {
                throw "Spritter padding failed for $($entry.Name) with exit code $LASTEXITCODE"
            }
        }

        if ($Optimize) {
            $targetArg = (Resolve-Path -LiteralPath $entry.Graphics).Path + [IO.Path]::DirectorySeparatorChar
            if ($PSCmdlet.ShouldProcess($entry.Graphics, "spritter optimize --lossy --group")) {
                & $spritter optimize --lossy --group $targetArg
                if ($LASTEXITCODE -ne 0) {
                    throw "Spritter optimize failed for $($entry.Name) with exit code $LASTEXITCODE"
                }
            }
        }
    }
}
