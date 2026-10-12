param(
    [ValidateSet('preview','final','preflight')][string]$Phase = 'preview',
    [ValidateSet(1,2)][int]$Prototype = 1,
    [string]$LightingProfile = 'preset-default',
    [double]$OrthoScale = 8.4
)
$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$root = Join-Path $repo "output\meshy\minigun-prototypes\prototype-$Prototype"
$blender = 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
$wrapper = Join-Path $repo '.codex\esir\asset-generators\minigun-turret\render_samples.py'
$profiles = if ($Phase -eq 'preview') { @('preset-default','rail-fill','gamma-rescue') } else { @($LightingProfile) }
foreach ($profile in $profiles) {
    $destination = if ($Phase -eq 'preview') { Join-Path $root "lighting-compare\$profile" } else { Join-Path $root $Phase }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $count = if ($Phase -eq 'preview') { 1 } else { 8 }
    $resolution = if ($Phase -eq 'preview') { 512 } else { 1024 }
    $samples = if ($Phase -eq 'preview') { 32 } else { 256 }
    $arguments = @('--factory-startup','--background','--python-exit-code','1','--python',$wrapper,'--',
        '--preset-blend',(Join-Path $repo 'factorioRenderingPreset_v4.blend'),
        '--input',(Join-Path $root 'source\model.glb'), '--asset-name',"minigun-prototype-$Prototype",
        '--output-dir',$destination,'--frames',"$count",'--directions','8','--animation-frames','1',
        '--initial-angle','225','--ortho-scale',"$OrthoScale",'--resolution',"$resolution",
        '--tile-size','128','--no-normalize','--footprint-tiles','3x3','--passes','object,shadow',
        '--quality','final','--samples',"$samples",'--cycles-compute-device','auto',
        '--lighting-profile',$profile,'--material-report','--warn-alpha-materials',
        '--preflight-margin','0.08','--fail-framing-risk','--pack-sheets','--grid','4x2')
    if ($Phase -eq 'preflight') { $arguments += '--preflight-only' }
    if ($Phase -eq 'final') { $arguments += @('--save-blend',(Join-Path $root 'sample-scene.blend')) }
    @{ executable=$blender; arguments=$arguments; phase=$Phase; prototype=$Prototype } |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destination 'command.json') -Encoding UTF8
    Write-Output "START prototype=$Prototype phase=$Phase profile=$profile"
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $blender @arguments *> (Join-Path $destination 'blender.log')
        $result = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    Write-Output "FINISH prototype=$Prototype phase=$Phase profile=$profile exit=$result"
    if ($result -ne 0) { Get-Content -LiteralPath (Join-Path $destination 'blender.log') -Tail 35; exit $result }
}
