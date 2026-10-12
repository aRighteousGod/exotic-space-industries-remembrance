param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('smoke','full')][string]$Matrix='smoke',
    [ValidateSet('none','high-quality')][string]$TextureCompression='none',
    [ValidateSet('native-default','not-compressed')][string]$ColorTexturePolicy='native-default',
    [ValidateSet('all','sd','hd')][string]$Profile='all',
    [ValidateSet('auto','full','cells')][string]$ReferenceSelection='auto',
    [string]$CompiledPath,
    [string]$SmokeSummary,
    [string]$RunPath,
    [string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'invoke-native-fixture.ps1'
if($Task -ne 'Stage') {
    if(-not $RunPath){throw '-RunPath is required for Run/Analyze'}
    & $runner -Task $Task -RunPath $RunPath -RepoRoot $RepoRoot
    return
}
if($RunPath){throw 'Stage requires a fresh payload; -RunPath is only for Run/Analyze'}
if(-not $CompiledPath){throw '-CompiledPath is required for Stage'}
$compiled=(Resolve-Path -LiteralPath $CompiledPath).Path
if(-not (Test-Path -LiteralPath (Join-Path $compiled 'metadata.json'))){throw 'Compiled pilot metadata.json is missing'}
$metadata=Get-Content -LiteralPath (Join-Path $compiled 'metadata.json') -Raw | ConvertFrom-Json
$resolvedReference=if($ReferenceSelection -eq 'auto'){if($metadata.profiles.sd.direction_count -eq 256){'cells'}else{'full'}}else{$ReferenceSelection}
$selectedProfiles=if($Profile -eq 'all'){@('sd','hd')}else{@($Profile)}
if($Matrix -eq 'full') {
    if(-not $SmokeSummary){throw 'Full matrix requires -SmokeSummary from a passed smoke run of these same compiled inputs and texture mode'}
    $smoke=Get-Content -LiteralPath $SmokeSummary -Raw | ConvertFrom-Json
    $inputHash=(Get-FileHash -LiteralPath (Join-Path $compiled 'metadata.json') -Algorithm SHA256).Hash
    $smokeProfiles=if($smoke.PSObject.Properties.Name -contains 'selected_profiles'){@($smoke.selected_profiles)}else{@('sd','hd')}
    $smokeReference=if($smoke.PSObject.Properties.Name -contains 'reference_selection'){$smoke.reference_selection}else{'full'}
    if(-not $smoke.automated_checks_passed -or $smoke.matrix -ne 'smoke' -or
        -not $smoke.capture_geometry.passed -or $smoke.capture_geometry.method -ne 'entity-relative-camera-v3' -or
        $smoke.texture_compression_observed -ne $TextureCompression -or
        $smoke.color_texture_policy -ne $ColorTexturePolicy -or
        ($smokeProfiles -join ',') -ne ($selectedProfiles -join ',') -or
        $smokeReference -ne $resolvedReference -or
        $smoke.compiled_metadata_sha256 -ne $inputHash){throw 'Smoke result does not match this input metadata and compression mode, or it did not pass'}
}
$savedInput=$env:ESIR_MINIGUN_COLOR_COMPILED
$savedMatrix=$env:ESIR_MINIGUN_COLOR_MATRIX
$savedCompression=$env:ESIR_MINIGUN_COLOR_COMPRESSION
$savedPolicy=$env:ESIR_MINIGUN_COLOR_TEXTURE_POLICY
$savedProfile=$env:ESIR_MINIGUN_COLOR_PROFILE
$savedReference=$env:ESIR_MINIGUN_COLOR_REFERENCE
try {
    $env:ESIR_MINIGUN_COLOR_COMPILED=$compiled
    $env:ESIR_MINIGUN_COLOR_MATRIX=$Matrix
    $env:ESIR_MINIGUN_COLOR_COMPRESSION=$TextureCompression
    $env:ESIR_MINIGUN_COLOR_TEXTURE_POLICY=$ColorTexturePolicy
    $env:ESIR_MINIGUN_COLOR_PROFILE=$Profile
    $env:ESIR_MINIGUN_COLOR_REFERENCE=$resolvedReference
    # Native runner derives the exact color benchmark length from the staged
    # input manifest. This wrapper neither launches nor duplicates the engine.
    $stageLines=@(& $runner -Task Stage -FixtureKind color -FixtureDirectory (Join-Path $PSScriptRoot 'native-color-fixture') -RepoRoot $RepoRoot)
    $stageLines | Write-Output
    $payloadLine=@($stageLines | Where-Object {$_ -match '^STAGED ONLY; Factorio was not started\. RunPath: '})
    if($payloadLine.Count -ne 1){throw 'Could not identify the newly staged color payload'}
    $run=$payloadLine[0] -replace '^STAGED ONLY; Factorio was not started\. RunPath: ',''
    $configPath=Join-Path $run 'config.ini'
    $config=Get-Content -LiteralPath $configPath -Raw
    if(([regex]::Matches($config,'\[graphics\]')).Count -ne 1){throw 'Unexpected native config sections'}
    $config=$config.Replace('[graphics]',('[graphics]'+[Environment]::NewLine+'texture-compression-level='+$TextureCompression))
    Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
    Write-Output "Color matrix=$Matrix; texture compression=$TextureCompression; Factorio was not started."
} finally {
    $env:ESIR_MINIGUN_COLOR_COMPILED=$savedInput
    $env:ESIR_MINIGUN_COLOR_MATRIX=$savedMatrix
    $env:ESIR_MINIGUN_COLOR_COMPRESSION=$savedCompression
    $env:ESIR_MINIGUN_COLOR_TEXTURE_POLICY=$savedPolicy
    $env:ESIR_MINIGUN_COLOR_PROFILE=$savedProfile
    $env:ESIR_MINIGUN_COLOR_REFERENCE=$savedReference
}
