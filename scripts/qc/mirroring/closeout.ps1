[CmdletBinding()]
param([Parameter(Mandatory)][string]$Record,
    [Parameter(Mandatory)][ValidateSet('original','legacy','current')][string]$Kind)
$ErrorActionPreference='Stop'
$r=Get-Content -LiteralPath $Record -Raw | ConvertFrom-Json
. (Join-Path $r.repo 'scripts/esir-housekeeping.ps1')
$run=Read-EsirArtifactRun $r.repo $r.run_id
if (-not $run.task_open) { throw 'This task is already closed.' }
$root=$r.write_data
$reports=Join-Path $root 'script-output/mirroring'
$recordCopy=Join-Path $root 'run-record.json'
Copy-Item -LiteralPath $Record -Destination $recordCopy
$selection=Join-Path $root 'staged-selection.json'
Copy-Item -LiteralPath (Join-Path $r.mods 'mod-list.json') -Destination $selection
$main=Join-Path $r.mods 'exotic-space-industries-remembrance'
$source=@{}
Get-ChildItem -LiteralPath $main -Recurse -File | Where-Object { $_.Extension -eq '.lua' -or $_.Name -eq 'info.json' } | ForEach-Object {
    $source[$_.FullName.Substring($main.Length+1)]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$identity=Join-Path $root 'source-identity.json'
$source | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $identity -Encoding UTF8
$fixture=Join-Path $root 'fixture-source.zip'
Compress-Archive -Path (Join-Path $PSScriptRoot '*') -DestinationPath $fixture -Force
$selected=@($recordCopy,$selection,$identity,$fixture)
if ($Kind -eq 'legacy') {
    $selected+=@(Join-Path $root 'donor.zip')
    $selected+=@(Join-Path $reports 'legacy-donor.json')
} else {
    $selected+=@(Get-ChildItem -LiteralPath $reports -File | Where-Object {
        $_.Name -like '*-reload.json' -or $_.Name -like '*-transport.json' -or
        $_.Name -like '*-heat.json' -or $_.Name -like '*-furnaces.json' -or
        $_.Name -in @('acceptance.json','historical-boundary.json','legacy-adopt.json','current-profile.json','visual-review.json')
    } | ForEach-Object FullName)
    $selected+=@(Join-Path $root 'candidate-quality-enabled.zip')
    $selected+=@(Join-Path $root 'candidate-quality-disabled.zip')
    if ($Kind -eq 'original') {
        $selected+=@(Join-Path $root 'saves/_autosave-mirroring-migrated.zip')
        $selected+=@(Get-ChildItem (Join-Path $reports 'render') -File | Where-Object { $_.Name -ne 'review-pump.png' } | ForEach-Object FullName)
        $selected+=@(Get-ChildItem -LiteralPath $root -Recurse -Filter 'preflight-summary.json' | ForEach-Object FullName)
    }
}
$selected+=@(Get-ChildItem -LiteralPath $root -File -Filter '*.log' | ForEach-Object FullName)
Set-EsirQcSelectedEvidence -RepoRoot $r.repo -RunId $r.run_id -Paths $selected
$summary=@{run_id=$run.id;workflow=$run.workflow;engine_version=$run.engine_version;repo_root=$run.repo_root;
    payload_path=$run.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='warning';
    result='Focused mirroring checks completed. Historical baseline differences and unrelated preflight encoding finding are documented in scripts/qc/mirroring/VERIFICATION.md.'}
$completed=Complete-EsirArtifactRun -RepoRoot $r.repo -RunId $run.id -ExitCode 0 -Summary $summary
if ($completed.cleanup_status -ne 'ready') {
    $completed | Select-Object id,status,cleanup_status,housekeeping_error | ConvertTo-Json -Depth 5
}
$closed=Set-EsirArtifactRunState -RepoRoot $r.repo -RunId $run.id -Action close
$closed | Select-Object id,status,task_open,cleanup_status,housekeeping_error,payload_path | ConvertTo-Json -Depth 5
