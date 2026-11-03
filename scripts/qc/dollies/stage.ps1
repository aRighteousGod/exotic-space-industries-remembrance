param([Parameter(Mandatory)][string]$Repo,[Parameter(Mandatory)][string]$Record)
$ErrorActionPreference='Stop'
. (Join-Path $Repo 'scripts/esir-dev-lib.ps1')
$context=Get-EsirQcContext -Paths (Get-EsirPaths $Repo)
$package=Join-Path $env:APPDATA 'Factorio/mods/even-pickier-dollies_3.2.0.zip'
if ((Get-FileHash $package).Hash -ne '92C6828B919FD23CE88AF55E8D4320A8F3F25F4878B8CBBFC99A91D696EC393D') {throw 'Unexpected EPD package identity'}
$context | Add-Member required_helper_sources @(@{name='esir-dollies-qc';path=(Join-Path $PSScriptRoot 'helper')})
$context | Add-Member extra_dependency_packages @(@{path=$package})
$managed=Start-EsirManagedQc -RepoRoot $Repo -Context $context -Workflow dollies -Scenario movement -SourceMode private-mutable -Reproduction 'python -B scripts/qc/dollies/run.py'
if (!$managed.run) {throw $managed.error}
if ($managed.run.engine_version -ne '2.1.24') {throw 'Wrong engine'}
$seed=Join-Path $context.scratch_root ([IO.Path]::GetFileName($package))
Copy-Item -LiteralPath $package -Destination $seed
$context.extra_dependency_packages[0].path=$seed
$mods=Sync-FactorioRunMods -Context $context -Result (New-FactorioQCResult -Name dollies)
$config=New-FactorioWriteDataConfig -Context $context -Label dollies
$dataPath=Join-Path (Split-Path (Split-Path (Split-Path $context.factorio_exe))) 'data'
$configText="[path]`nread-data=$($dataPath.Replace('\','/'))`nwrite-data=$($config.write_data_dir.Replace('\','/'))`n[graphics]`nfull-screen=false`nhalt-rendering-when-minimized=false`nmax-sprite-loading-threads=2`ncache-sprite-atlas=false`n"
[IO.File]::WriteAllText($config.config_path,$configText,[Text.UTF8Encoding]::new($false))
Write-EsirJson -Path $Record -Data @{run_id=$managed.run.id;engine=$context.factorio_exe;mods=$mods;config=$config.config_path;write_data=$config.write_data_dir;evidence=$context.evidence_root;scratch=$context.scratch_root}
