[CmdletBinding()]
param(
    [string]$RunRoot,
    [string]$FactorioPath='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe',
    [string]$SeedMods,
    [ValidateSet('all','visual','player','legacy','layouts','profiles','accept')][string]$Suite='all',
    [string]$BaselineRoot,
    [ValidateSet('high','medium')][string]$GraphicsQuality='high'
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
if(-not $SeedMods){$SeedMods=Join-Path $repo '.factorio-qc/dependency-seeds/2.1-core'}
$retained=@('scripts/qc/acid-eight-way','.codex/esir/asset-generators/acidthrower-turret/revision-03')
if($RunRoot){$retained+=([IO.Path]::GetFullPath($RunRoot))}
$registration=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'acid-eight-way' -Scenario $Suite -EngineVersion '2.1.23' `
    -Reproduction "scripts/invoke-acid-eight-way-qc.ps1 -Suite $Suite -FactorioPath <2.1.23> -SeedMods <locked-seed> -BaselineRoot <pre-change-receipts>" -RetainedPaths $retained
if(-not $RunRoot){$RunRoot=Join-Path $repo $registration.payload_path}
$arguments=@('-B',(Join-Path $PSScriptRoot 'qc/acid-eight-way/run.py'),'--run',$RunRoot,'--engine',$FactorioPath,'--seed',$SeedMods,'--suite',$Suite,'--graphics-quality',$GraphicsQuality)
if($BaselineRoot){$arguments+=@('--baseline-root',$BaselineRoot)}
$code=1
try{
    & python @arguments
    $code=$LASTEXITCODE
    if($code -ne 0){throw "Eight-way $Suite failed; retained evidence: $RunRoot"}
}finally{
    Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode $code -Summary @{
        overall_status=$(if($code -eq 0){'ok'}else{'failed'});suite=$Suite;engine_version='2.1.23';evidence=$RunRoot
    }
    Set-EsirArtifactRunState -RepoRoot $repo -RunId $registration.id -Action close
}
