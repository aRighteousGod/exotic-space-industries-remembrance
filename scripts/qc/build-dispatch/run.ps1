[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Record,
    [ValidateSet('baseline','candidate','reload')][string]$Phase = 'candidate',
    [string]$Save,
    [switch]$ServerSave,
    [switch]$Reuse
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$recordData = Read-EsirJson $Record
$context = Get-EsirQcContext -Paths (Get-EsirPaths $repo)
if ($Reuse) {
    $run=Read-EsirArtifactRun $repo $recordData.run_id
    if ($run.workflow -ne 'build-dispatch' -or -not $run.task_open) { throw 'Reuse requires an open build-dispatch fixture.' }
    [void](Initialize-EsirManagedQcContext -RepoRoot $repo -Context $context -RunId $run.id -SourceMode private-mutable)
    [void](Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$run.id})
    $context.run_mod_directory=$recordData.mods
    $source=Join-Path $recordData.scratch 'frozen-source'
} else {
$state = Start-EsirManagedQc -RepoRoot $repo -Context $context -Workflow build-dispatch -SourceMode private-mutable -Reproduction "scripts/qc/build-dispatch/run.ps1 -Record $Record -Phase $Phase"
if (-not $state.run) { throw $state.error }
$run = $state.run
$source = Join-Path $context.scratch_root 'frozen-source'
$inputSource = if ($Phase -eq 'baseline') { $recordData.baseline } else { Join-Path $repo 'exotic-space-industries-remembrance' }
Copy-Item -LiteralPath $inputSource -Destination $source -Recurse
$main = @($context.source_mods | Where-Object name -eq 'exotic-space-industries-remembrance')[0]
$main.directory = $source
$main.info_path = Join-Path $source 'info.json'
$result = New-FactorioQCResult -Name build-dispatch
$mods = Sync-FactorioRunMods -Context $context -Result $result
$recordData = @{run_id=$run.id;repo=$repo;mods=$mods;baseline=$recordData.baseline;engine=$context.factorio_exe;
    scratch=$context.scratch_root;evidence=$context.evidence_root;payload=(Join-Path $repo $run.payload_path)}
$Record = Join-Path $recordData.payload 'context.json'
Write-EsirJson -Path $Record -Data $recordData
}
& python -B (Join-Path $PSScriptRoot 'stage.py') --record $Record --source $source --phase $Phase
if ($LASTEXITCODE -ne 0) { throw 'Private fixture staging failed.' }
$config = New-FactorioWriteDataConfig -Context $context -Label $Phase
if (-not $Save) { $Save = Join-Path $repo $context.esir_development_profile.smoke_save }
$arguments = @('--config',$config.config_path,'--mod-directory',$recordData.mods,'--disable-audio')
if ($ServerSave) {
    [void][IO.Directory]::CreateDirectory((Join-Path $config.write_data_dir 'saves'))
    $engineRoot=Split-Path (Split-Path (Split-Path $context.factorio_exe))
    $settings=Read-EsirJson (Join-Path $engineRoot 'data/server-settings.example.json')
    $settings.name='Private build dispatch QC'
    $settings.visibility.public=$false;$settings.visibility.lan=$false
    $settings.require_user_verification=$false;$settings.auto_pause=$false
    $settingsPath=Join-Path $config.write_data_dir 'server-settings.json'
    Write-EsirJson -Path $settingsPath -Data $settings
    $arguments+=@('--start-server',$Save,'--server-settings',$settingsPath,'--port','34327')
    $quoted=@($arguments | ForEach-Object { '"'+$_+'"' })
    $native=Start-Process -FilePath $context.factorio_exe -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $config.write_data_dir 'stdout.log') -RedirectStandardError (Join-Path $config.write_data_dir 'stderr.log')
    $saved=Join-Path $config.write_data_dir 'saves/build-dispatch-reload.zip'
    $deadline=(Get-Date).AddMinutes(4)
    $verified=$false
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        while (-not $native.HasExited -and (Get-Date) -lt $deadline) {
            if (Test-Path -LiteralPath $saved) {
                try { $zip=[IO.Compression.ZipFile]::OpenRead($saved);$zip.Dispose();$verified=$true;break } catch {}
            }
            $partial=Join-Path $config.write_data_dir "script-output/build-dispatch-$Phase.json"
            if ((Test-Path -LiteralPath $partial) -and -not (Read-EsirJson $partial).passed) { break }
            Start-Sleep -Milliseconds 500
            $native.Refresh()
        }
    } finally { if (-not $native.HasExited) { Stop-Process -Id $native.Id; $native.WaitForExit() } }
    if (-not $verified) { throw "No verified fixture save; inspect $($config.write_data_dir)" }
    Copy-Item -LiteralPath $saved -Destination (Join-Path $recordData.evidence 'reload.zip')
    $process=[pscustomobject]@{exit_code=0}
} else {
    $arguments+=@('--benchmark',$Save,'--benchmark-ticks','60','--benchmark-runs','1')
    $process = Invoke-NativeProcess -FilePath $context.factorio_exe -Arguments $arguments -OutputPath (Join-Path $config.write_data_dir 'stdout.log')
}
$reportPath = Join-Path $config.write_data_dir "script-output/build-dispatch-$Phase.json"
if (-not (Test-Path -LiteralPath $reportPath)) { throw "Missing report; inspect $($config.write_data_dir)" }
$report = Read-EsirJson $reportPath
Copy-Item -LiteralPath $reportPath -Destination (Join-Path $recordData.evidence "$Phase.json")
Copy-Item -LiteralPath (Join-Path $config.write_data_dir 'stdout.log') -Destination (Join-Path $recordData.evidence "$Phase.stdout.log")
Write-EsirJson -Path (Join-Path $recordData.evidence "$Phase-run.json") -Data @{
    engine=$context.factorio_exe; engine_version=$context.esir_development_profile.engine_version;
    write_data=$config.write_data_dir; save=$Save; process_exit=$process.exit_code; passed=$report.passed
}
[void](Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$run.id})
@{phase=$Phase;passed=$report.passed;checks=@($report.checks).Count;record=$Record;report=(Join-Path $recordData.evidence "$Phase.json");write_data=$config.write_data_dir} | ConvertTo-Json
if ($process.exit_code -ne 0 -or -not $report.passed) { throw 'Build dispatch acceptance failed.' }
