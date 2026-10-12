param(
    [ValidateSet('Stage','Run','Analyze')][string]$Task='Stage',
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
if($RunPath){throw 'Stage creates a fresh managed payload'}
$oldMatrix=$env:ESIR_MINIGUN_COLOR_MATRIX
$oldCompression=$env:ESIR_MINIGUN_COLOR_COMPRESSION
try {
    $env:ESIR_MINIGUN_COLOR_MATRIX='delta-blend-proof'
    $env:ESIR_MINIGUN_COLOR_COMPRESSION='none'
    $lines=@(& $runner -Task Stage -FixtureKind color -FixtureDirectory (Join-Path $PSScriptRoot 'native-delta-blend-fixture') -RepoRoot $RepoRoot)
    $lines | Write-Output
    $line=@($lines | Where-Object {$_ -match '^STAGED ONLY; Factorio was not started\. RunPath: '})
    if($line.Count -ne 1){throw 'Cannot identify staged delta-blend payload'}
    $run=$line[0] -replace '^STAGED ONLY; Factorio was not started\. RunPath: ',''
    $configPath=Join-Path $run 'config.ini'
    $config=Get-Content -LiteralPath $configPath -Raw
    if(([regex]::Matches($config,'\[graphics\]')).Count -ne 1){throw 'Unexpected graphics config'}
    $config=$config.Replace('[graphics]',('[graphics]'+[Environment]::NewLine+'texture-compression-level=none'))
    Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
    Write-Output 'Delta-blend hypothesis staged; no engine run or production approval.'
} finally {
    $env:ESIR_MINIGUN_COLOR_MATRIX=$oldMatrix
    $env:ESIR_MINIGUN_COLOR_COMPRESSION=$oldCompression
}
