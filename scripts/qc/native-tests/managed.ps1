# Native-test adapter to the existing managed storage/ownership contract.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('stage','validate','finish')][string]$Action,
    [Parameter(Mandatory)][string]$Request)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$requestData=Read-EsirJson $Request
if ($Action -eq 'stage') {
    $profile=Read-EsirJson (Join-Path $repo '.codex/esir/factorio-development.json')
    $engine=if($requestData.engine){$requestData.engine}else{Join-Path $repo $profile.engine_path}
    $base=Read-EsirJson (Join-Path (Split-Path (Split-Path (Split-Path $engine))) 'data/base/info.json')
    if ($profile.engine_version -ne '2.1.24' -or $base.version -ne $profile.engine_version) { throw 'Native testing requires exact profile/base 2.1.24.' }
    # Reject other executable families before generic context fallback can run.
    $probe=[Diagnostics.Process]::new()
    $probe.StartInfo.FileName=$engine
    $probe.StartInfo.Arguments='--version'
    $probe.StartInfo.UseShellExecute=$false
    $probe.StartInfo.CreateNoWindow=$true
    $probe.StartInfo.RedirectStandardOutput=$true
    $probe.StartInfo.RedirectStandardError=$true
    try {
        [void]$probe.Start()
        $stdout=$probe.StandardOutput.ReadToEndAsync();$stderr=$probe.StandardError.ReadToEndAsync()
        if(-not $probe.WaitForExit(15000)){$probe.Kill();$probe.WaitForExit();throw 'Native executable version probe timed out.'}
        $versionText=$stdout.Result+$stderr.Result
        if($probe.ExitCode -ne 0 -or $versionText -notmatch 'Version:\s*(2\.1\.24)(?:\s|\()') { throw 'Native testing rejects executable/base/profile disagreement; exact executable 2.1.24 is required.' }
    } finally { $probe.Dispose() }
    $context=Get-EsirQcContext -Paths (Get-EsirPaths $repo) -FactorioPath $engine
    if ($requestData.base_only) {
        $context.is_esir=$false
        $context.PSObject.Properties.Remove('esir_development_profile')
        $context.source_mods=@()
        $context | Add-Member -NotePropertyName dependency_packages -NotePropertyValue @()
        $context | Add-Member -NotePropertyName qc_mod_list -NotePropertyValue @{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$false},@{name='quality';enabled=$false},@{name='elevated-rails';enabled=$false},@{name='recycler';enabled=$false})}
    }
    $context | Add-Member -NotePropertyName required_helper_sources -NotePropertyValue @(@{name='esir-qc-native-tests';path=(Join-Path $PSScriptRoot 'helper')})
    $context | Add-Member -NotePropertyName test_quality -NotePropertyValue $requestData.quality
    $managed=Start-EsirManagedQc -RepoRoot $repo -Context $context -Workflow qc-test -Scenario $requestData.scenario -SourceMode private-mutable -Reproduction $requestData.reproduction
    if (-not $managed.run) {
        if ($managed.PSObject.Properties.Name -contains 'failed_registration' -and $managed.failed_registration) {
            $failed=$managed.failed_registration
            $summary=@{run_id=$failed.id;workflow=$failed.workflow;engine_version=$failed.engine_version;repo_root=$repo;
                payload_path=$failed.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='failed';error=$managed.error}
            try {
                $null=Complete-EsirArtifactRun -RepoRoot $repo -RunId $failed.id -ExitCode 1 -Summary $summary
                $null=Set-EsirArtifactRunState -RepoRoot $repo -RunId $failed.id -Action close
            } catch { throw ('Registration initialization failed; protected run_id='+$failed.id+'; '+$managed.error+'; '+$_.Exception.Message) }
        }
        throw $managed.error
    }
    try {
    if ($managed.run.engine_version -ne $profile.engine_version) { throw 'Executable does not match native-test profile.' }
    $result=New-FactorioQCResult -Name native-tests
    $mods=Sync-FactorioRunMods -Context $context -Result $result
    $config=New-FactorioWriteDataConfig -Context $context -Label native-tests
    # config-path.cfg may otherwise redirect this portable engine to Steam data.
    $dataPath=Join-Path (Split-Path (Split-Path (Split-Path $engine))) 'data'
    $configText="[path]`nread-data=$($dataPath.Replace('\','/'))`nwrite-data=$($config.write_data_dir.Replace('\','/'))`n`n[other]`ncheck-updates=false`n`n[graphics]`nfull-screen=false`nhalt-rendering-when-minimized=false`nmax-sprite-loading-threads=2`ncache-sprite-atlas=false`n"
    [IO.File]::WriteAllText($config.config_path,$configText,[Text.UTF8Encoding]::new($false))
    $mutable=Invoke-EsirQcStorage -RepoRoot $repo -Action mutable-sources -Data @{run_id=$managed.run.id}
    $record=@{run_id=$managed.run.id;workflow='qc-test';engine_version=$profile.engine_version;engine=$engine;
        repo_root=$repo;payload_path=$managed.run.payload_path;mods=$mods;config=$config.config_path;write_data=$config.write_data_dir;
        evidence=$context.evidence_root;scratch=$context.scratch_root;mutable=$mutable.names;started_at=$managed.run.started_at}
    Write-EsirJson -Path (Join-Path $context.evidence_root 'context.json') -Data $record
    $record | ConvertTo-Json -Depth 12 -Compress
    } catch {
        $failure=$_.Exception.Message
        $summary=@{run_id=$managed.run.id;workflow=$managed.run.workflow;engine_version=$managed.run.engine_version;
            repo_root=$repo;payload_path=$managed.run.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='failed';error=$failure}
        try {
            Write-EsirJson -Path (Join-Path $context.evidence_root 'staging-failure.json') -Data $summary
            $null=Complete-EsirArtifactRun -RepoRoot $repo -RunId $managed.run.id -ExitCode 1 -Summary $summary
            $null=Set-EsirArtifactRunState -RepoRoot $repo -RunId $managed.run.id -Action close
        } catch { $failure += '; closeout: '+$_.Exception.Message }
        throw ('Managed staging failed; run_id='+$managed.run.id+'; '+$failure)
    }
} elseif ($Action -eq 'validate') {
    Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$requestData.run_id} | Out-Null
    @{valid=$true} | ConvertTo-Json -Compress
} else {
    $run=Read-EsirArtifactRun $repo $requestData.run_id
    $summary=@{run_id=$run.id;workflow=$run.workflow;engine_version=$run.engine_version;repo_root=$repo;payload_path=$run.payload_path;
        timestamp=[DateTime]::UtcNow.ToString('o');overall_status=$requestData.overall_status;result=$requestData.result}
    $exitCode=if($requestData.overall_status -eq 'failed'){1}else{0}
    $completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $run.id -ExitCode $exitCode -Summary $summary
    $closed=Set-EsirArtifactRunState -RepoRoot $repo -RunId $run.id -Action close
    # Closing task ownership never authorizes deletion of protected input data.
    if ($completed.cleanup_status -eq 'protected-error') { throw $completed.housekeeping_error }
    $closed | ConvertTo-Json -Depth 8 -Compress
}
