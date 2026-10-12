param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
    [ValidateSet('smoke','full')][string]$Matrix='smoke',
    [ValidateSet('none','high-quality')][string]$TextureCompression='none',
    [string]$Tier='all',
    [string]$ShadowCandidatesPath,
    [string]$ReferencePath,
    [string]$RenderReferencesPath,
    [ValidateSet('auto','full','cells')][string]$ReferenceSelection='auto',
    [string]$SmokeSummary,
    [string]$RunPath,
    [string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'invoke-native-fixture.ps1'
if($Task -ne 'Stage') {
    if(-not $RunPath){throw '-RunPath is required for Run/Analyze'}
    $stage=Get-Content -LiteralPath (Join-Path $RunPath 'native-fixture-stage.json') -Raw | ConvertFrom-Json
    if($stage.fixture_kind -ne 'shadow'){throw 'RunPath is not a native shadow fixture'}
    & $runner -Task $Task -RunPath $RunPath -RepoRoot $RepoRoot
    return
}
if($RunPath){throw 'Stage requires a fresh payload; -RunPath is only for Run/Analyze'}
if(-not $ShadowCandidatesPath -or -not $ReferencePath){throw 'Stage requires -ShadowCandidatesPath and -ReferencePath'}
$candidates=(Resolve-Path -LiteralPath $ShadowCandidatesPath).Path
$reference=(Resolve-Path -LiteralPath $ReferencePath).Path
$referenceMetadata=Get-Content -LiteralPath (Join-Path $reference 'metadata.json') -Raw | ConvertFrom-Json
$actualReferenceSelection=$ReferenceSelection
if($actualReferenceSelection -eq 'auto') {
    $actualReferenceSelection=if($referenceMetadata.direction_indices.Count -eq 256){'cells'}else{'full'}
}
$renderReferences=if($RenderReferencesPath){(Resolve-Path -LiteralPath $RenderReferencesPath).Path}else{Split-Path -Parent $reference}
if($Tier -in @('combined','combined_sd','combined_hd')) {
    foreach($name in @('render-configuration.json','render-records.jsonl')) {
        if(-not (Test-Path -LiteralPath (Join-Path $renderReferences $name))){throw 'Combined source proof requires -RenderReferencesPath with retained render configuration and records'}
    }
}
foreach($root in @($candidates,$reference)) {
    if(-not (Test-Path -LiteralPath (Join-Path $root 'metadata.json'))){throw 'Required metadata.json is missing'}
}
if($Matrix -eq 'full') {
    if($Tier -eq 'all' -or -not $SmokeSummary){throw 'Full requires one selected -Tier and -SmokeSummary from its passing smoke run'}
    $smoke=Get-Content -LiteralPath $SmokeSummary -Raw | ConvertFrom-Json
    $tierProperty=$smoke.tiers.PSObject.Properties[$Tier]
    if(-not $smoke.automated_checks_passed -or $smoke.matrix -ne 'smoke' -or
        -not $smoke.capture_geometry.passed -or $smoke.capture_geometry.method -ne 'entity-relative-camera-v3' -or
        $smoke.texture_compression_observed -ne $TextureCompression -or -not $tierProperty -or -not $tierProperty.Value.passed -or
        $smoke.reference_selection -ne $actualReferenceSelection -or
        ($Tier -in @('combined_sd','combined_hd') -and (-not $smoke.source_cells_verified -or -not $smoke.native_shadow_policy_verified)) -or
        $smoke.candidate_metadata_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $candidates 'metadata.json') -Algorithm SHA256).Hash -or
        $smoke.reference_metadata_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $reference 'metadata.json') -Algorithm SHA256).Hash) {
        throw 'Selected shadow tier lacks a passed smoke result for these exact candidate/reference inputs and compression mode'
    }
}
$saved=@{}
$values=@{ESIR_MINIGUN_SHADOW_CANDIDATES=$candidates;ESIR_MINIGUN_SHADOW_REFERENCE=$reference;
    ESIR_MINIGUN_SHADOW_MATRIX=$Matrix;ESIR_MINIGUN_SHADOW_TIER=$Tier;ESIR_MINIGUN_SHADOW_COMPRESSION=$TextureCompression;
    ESIR_MINIGUN_SHADOW_RENDERS=$renderReferences;ESIR_MINIGUN_SHADOW_REFERENCE_SELECTION=$actualReferenceSelection}
try {
    foreach($name in $values.Keys){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process');[Environment]::SetEnvironmentVariable($name,$values[$name],'Process')}
    $stageLines=@(& $runner -Task Stage -FixtureKind shadow -FixtureDirectory (Join-Path $PSScriptRoot 'native-shadow-fixture') -RepoRoot $RepoRoot)
    $stageLines | Write-Output
    $payloadLine=@($stageLines | Where-Object {$_ -match '^STAGED ONLY; Factorio was not started\. RunPath: '})
    if($payloadLine.Count -ne 1){throw 'Could not identify the new shadow payload'}
    $run=$payloadLine[0] -replace '^STAGED ONLY; Factorio was not started\. RunPath: ',''
    $configPath=Join-Path $run 'config.ini'
    $config=Get-Content -LiteralPath $configPath -Raw
    if(([regex]::Matches($config,'\[graphics\]')).Count -ne 1){throw 'Unexpected native config sections'}
    $config=$config.Replace('[graphics]',('[graphics]'+[Environment]::NewLine+'texture-compression-level='+$TextureCompression))
    Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
    Write-Output "Shadow matrix=$Matrix tier=$Tier compression=$TextureCompression; Factorio was not started."
} finally {
    foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
}
