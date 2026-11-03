[CmdletBinding()]
param([ValidateSet('Prepare','Configure','Sync','Create','Run','Settle','Visual','Finish')][string]$Phase='Prepare',
    [string]$ContextPath,[int]$Ticks=110,[int]$Runs=1,[string]$Save,[string]$Label='candidate',
    [switch]$BaseOnly,[ValidateSet('vanilla','squeak-through','esir')][string]$PipeMode='esir',
    [ValidateRange(1,1024)][int]$Budget=256,[switch]$Administration,[int]$Performance=0,[switch]$Disabled,[string]$DisabledCategory,[switch]$Render,[switch]$Actors,[switch]$Companion,[switch]$Burst,
    [ValidateSet('functional','transition','reload','performance-idle','performance-burst','visual','actors','companion','administration','administration-reload')][string]$ExpectedReceipt='functional',
    [string]$AcceptancePlan)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-dev-lib.ps1')
if ($Phase -eq 'Prepare') {
    $context=Get-EsirQcContext -Paths (Get-EsirPaths $repo)
    if ($BaseOnly) {
        $context.is_esir=$false
        $context.PSObject.Properties.Remove('esir_development_profile')
        $context.source_mods=@()
    }
    $fixture='helper'
    $helperPath=Join-Path $PSScriptRoot "qc/factory-passage/$fixture"
    $info=Get-Content -Raw -Encoding UTF8 (Join-Path $helperPath 'info.json') | ConvertFrom-Json
    $context | Add-Member -NotePropertyName required_helper_sources -NotePropertyValue @(@{name=$info.name;path=$helperPath})
    if ($Companion) {
        $package=Join-Path $env:APPDATA 'Factorio/mods/squeak-through-2_0.2.0.zip'
        if (-not (Test-Path -LiteralPath $package)) { throw 'The explicit 2.1 companion package is unavailable.' }
        $context | Add-Member -NotePropertyName extra_dependency_packages -NotePropertyValue @(@{path=$package})
    }
    $managed=Start-EsirManagedQc -RepoRoot $repo -Context $context -Workflow factory-passage -Scenario $fixture -SourceMode private-mutable -Reproduction 'powershell -ExecutionPolicy Bypass -File scripts/invoke-factory-passage-qc.ps1 -Phase Prepare'
    if (-not $managed.run) { throw $managed.error }
    if ($managed.run.engine_version -ne '2.1.24') { throw 'Factory passage acceptance requires exact Factorio 2.1.24.' }
    if ($Companion) {
        # Import a task-owned copy; never hardlink or move the installed package.
        $seed=Join-Path $context.scratch_root ([IO.Path]::GetFileName($package))
        Copy-Item -LiteralPath $package -Destination $seed
        if ((Get-FileHash -LiteralPath $seed).Hash -ne (Get-FileHash -LiteralPath $package).Hash) { throw 'Companion seed copy hash mismatch.' }
        $context.extra_dependency_packages[0].path=$seed
    }
    $result=New-FactorioQCResult -Name factory-passage
    $mods=Sync-FactorioRunMods -Context $context -Result $result
    if ($fixture -eq 'helper') {
        $private=Invoke-EsirQcStorage -RepoRoot $repo -Action mutable-sources -Data @{run_id=$managed.run.id}
        $helperRoot=$private.names.($info.name)
        if (-not $helperRoot) { throw 'No private helper backing.' }
        foreach ($relative in @('lib/factory-passage-config.lua','lib/runtime-scheduler.lua','prototypes/factory-passage.lua','scripts/data-final-updates/factory-passage.lua','scripts/control/factory-passage.lua')) {
            $target=Join-Path $helperRoot $relative
            [void][IO.Directory]::CreateDirectory((Split-Path $target))
            Copy-Item -LiteralPath (Join-Path $repo "exotic-space-industries-remembrance/$relative") -Destination $target
        }
        [IO.File]::WriteAllText((Join-Path $helperRoot 'lib/lib.lua'),'return {entity_check=function(e) return e and e.valid and e.object_name=="LuaEntity" end}',[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $helperRoot 'fixture-config.lua'),"return {mode='$PipeMode',enabled=$((!$Disabled).ToString().ToLowerInvariant()),performance=$Performance,budget=$Budget,administration=$($Administration.ToString().ToLowerInvariant()),visual=$($Render.ToString().ToLowerInvariant()),actors=$($Actors.ToString().ToLowerInvariant()),burst=$($Burst.ToString().ToLowerInvariant()),disabled_category='$DisabledCategory'}",[Text.UTF8Encoding]::new($false))
    }
    $config=New-FactorioWriteDataConfig -Context $context -Label factory-passage
    if ($Administration) {
        if ($BaseOnly) { throw 'Administration QC requires the full ESIR profile.' }
        $mainRoot=$private.names.'exotic-space-industries-remembrance'
        if (-not $mainRoot) { throw 'No private main-mod backing for administration QC.' }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'qc/factory-passage/admin-bridge.lua') -Destination (Join-Path $mainRoot 'factory-passage-qc.lua')
        [IO.File]::AppendAllText((Join-Path $mainRoot 'control.lua'),"`nrequire('factory-passage-qc')`n",[Text.UTF8Encoding]::new($false))
    }
    $record=@{run_id=$managed.run.id;engine=$context.factorio_exe;mods=$mods;config=$config.config_path;
        write_data=$config.write_data_dir;evidence=$context.evidence_root;scratch=$context.scratch_root;helper=$info.name;mode=$PipeMode;performance=$Performance;budget=$Budget;administration=[bool]$Administration;enabled=(!$Disabled);disabled_category=$DisabledCategory;visual=[bool]$Render;actors=[bool]$Actors;burst=[bool]$Burst}
    if ($Companion) {
        $listPath=Join-Path $mods 'mod-list.json';$list=Read-EsirJson $listPath
        $list.mods=@($list.mods | Where-Object name -ne 'squeak-through-2')+@{name='squeak-through-2';enabled=$true}
        Write-EsirJson -Path $listPath -Data $list
    }
    $ContextPath=Join-Path $context.evidence_root 'context.json'
    Write-EsirJson -Path $ContextPath -Data $record
    Write-Output "CONTEXT=$ContextPath"
    if ($Phase -eq 'Prepare') { return }
} else { $record=Read-EsirJson $ContextPath }
if ($Phase -eq 'Configure') {
    $private=Invoke-EsirQcStorage -RepoRoot $repo -Action mutable-sources -Data @{run_id=$record.run_id}
    $helperRoot=$private.names.($record.helper)
    if (-not $helperRoot) { throw 'No private helper backing.' }
    [IO.File]::WriteAllText((Join-Path $helperRoot 'fixture-config.lua'),"return {mode='$PipeMode',enabled=$((!$Disabled).ToString().ToLowerInvariant()),performance=$Performance,budget=$Budget,administration=$($Administration.ToString().ToLowerInvariant()),visual=$($Render.ToString().ToLowerInvariant()),actors=$($Actors.ToString().ToLowerInvariant()),burst=$($Burst.ToString().ToLowerInvariant()),disabled_category='$DisabledCategory'}",[Text.UTF8Encoding]::new($false))
    $record.budget=$Budget;$record.administration=[bool]$Administration
    $record.mode=$PipeMode;$record.performance=$Performance;$record.enabled=(!$Disabled)
    $record | Add-Member -NotePropertyName disabled_category -NotePropertyValue $DisabledCategory -Force
    $record | Add-Member -NotePropertyName visual -NotePropertyValue ([bool]$Render) -Force
    $record | Add-Member -NotePropertyName actors -NotePropertyValue ([bool]$Actors) -Force
    $record | Add-Member -NotePropertyName burst -NotePropertyValue ([bool]$Burst) -Force
    Write-EsirJson -Path $ContextPath -Data $record
    return
}
if ($Phase -eq 'Sync') {
    $mutable=Invoke-EsirQcStorage -RepoRoot $repo -Action mutable-sources -Data @{run_id=$record.run_id}
    if ($record.helper -notin $mutable.names.PSObject.Properties.Name) { throw 'Helper is not a private mutable source.' }
    $fixture='helper'
    $helperRoot=$mutable.names.($record.helper)
    Copy-Item -Path (Join-Path $PSScriptRoot "qc/factory-passage/$fixture/*") -Destination $helperRoot -Recurse -Force
    if ($fixture -eq 'helper') {
        foreach ($relative in @('lib/factory-passage-config.lua','lib/runtime-scheduler.lua','prototypes/factory-passage.lua','scripts/data-final-updates/factory-passage.lua','scripts/control/factory-passage.lua')) {
            Copy-Item -LiteralPath (Join-Path $repo "exotic-space-industries-remembrance/$relative") -Destination (Join-Path $helperRoot $relative) -Force
        }
        [IO.File]::WriteAllText((Join-Path $helperRoot 'fixture-config.lua'),"return {mode='$($record.mode)',enabled=$($record.enabled.ToString().ToLowerInvariant()),performance=$($record.performance),budget=$($record.budget),administration=$($record.administration.ToString().ToLowerInvariant()),visual=$($record.visual.ToString().ToLowerInvariant()),actors=$($record.actors.ToString().ToLowerInvariant()),burst=$($record.burst.ToString().ToLowerInvariant()),disabled_category='$($record.disabled_category)'}",[Text.UTF8Encoding]::new($false))
    }
    return
}
if ($Phase -eq 'Finish') {
    if (-not $AcceptancePlan) { throw 'Finish requires an explicit acceptance plan listing every required receipt label.' }
    $plan=Read-EsirJson $AcceptancePlan
    if (-not $plan.required_labels -or $plan.passed -ne $true) { throw 'Acceptance plan is missing or failed.' }
    foreach ($required in $plan.required_labels) {
        $accepted=Read-EsirJson (Join-Path $record.evidence "$required.json")
        if ($accepted.passed -ne $true) { throw "Missing passing receipt: $required" }
    }
    Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$record.run_id} | Out-Null
    $run=Read-EsirArtifactRun $repo $record.run_id
    $summary=@{run_id=$run.id;workflow=$run.workflow;engine_version=$run.engine_version;repo_root=$repo;payload_path=$run.payload_path;
        timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';result='Factory passage focused checks passed.'}
    Complete-EsirArtifactRun -RepoRoot $repo -RunId $run.id -ExitCode 0 -Summary $summary | Out-Null
    Set-EsirArtifactRunState -RepoRoot $repo -RunId $run.id -Action close | ConvertTo-Json -Depth 6
    return
}
Invoke-EsirQcStorage -RepoRoot $repo -Action validate -Data @{run_id=$record.run_id} | Out-Null
$common=@('--config',$record.config,'--mod-directory',$record.mods,'--disable-audio','--disable-migration-window')
if (-not $Save) { $Save=Join-Path $record.write_data "$Label.zip" }
if ($Phase -eq 'Settle') {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [void][IO.Directory]::CreateDirectory((Join-Path $record.write_data 'saves'))
    $complete=$false
    $serverSettings=Join-Path $record.evidence 'server-settings.json'
    Write-EsirJson -Path $serverSettings -Data @{name='ESIR private passage QC';description='Isolated acceptance fixture';visibility=@{public=$false;lan=$false};require_user_verification=$false;auto_pause=$false}
    $stdout=Join-Path $record.evidence "$Label-settle.log"
    $stderr=Join-Path $record.evidence "$Label-settle-error.log"
    $arguments=@('--start-server',$Save,'--server-settings',$serverSettings,'--bind','127.0.0.1','--port','34299')+$common
    $quoted=($arguments | ForEach-Object {'"'+$_+'"'}) -join ' '
    $started=[DateTime]::UtcNow
    $process=Start-Process -FilePath $record.engine -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $processHandle=$process.Handle
    $checkpoint=Join-Path $record.write_data 'saves/factory-passage-performance.zip'
    $deadline=[DateTime]::UtcNow.AddMinutes(5)
    $peakWorking=[long]0;$peakPrivate=[long]0
    try {
        while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
            $peakWorking=[Math]::Max($peakWorking,$process.PeakWorkingSet64)
            $peakPrivate=[Math]::Max($peakPrivate,$process.PrivateMemorySize64)
            if ((Test-Path -LiteralPath $checkpoint) -and (Get-Item -LiteralPath $checkpoint).LastWriteTimeUtc -ge $started) {
                try {
                    $archive=[IO.Compression.ZipFile]::OpenRead($checkpoint)
                    $complete=$archive.Entries.Count -gt 2 -and (Select-String -LiteralPath $stdout -Pattern 'Saving finished' -Quiet)
                    $archive.Dispose()
                    if ($complete) { break }
                } catch { }
            }
            Start-Sleep -Milliseconds 250
            $process.Refresh()
        }
        if (-not $complete) { throw 'No completed settled checkpoint; inspect private server logs.' }
        python -c 'import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None; z.close()' $checkpoint
        if ($LASTEXITCODE -ne 0) { throw 'Checkpoint ZIP integrity check failed.' }
        Copy-Item -LiteralPath $checkpoint -Destination (Join-Path $record.write_data "$Label-settled.zip")
        $receiptName=if($record.performance -gt 0){'performance-ready'}else{$ExpectedReceipt}
        $receiptPath=Join-Path $record.write_data "script-output/factory-passage/$receiptName.json"
        $accepted=Read-EsirJson $receiptPath
        if ((Get-Item -LiteralPath $receiptPath).LastWriteTimeUtc -lt $started -or $accepted.passed -ne $true -or $accepted.mode -ne $record.mode) { throw 'Missing fresh passing checkpoint receipt.' }
        Copy-Item -LiteralPath $receiptPath -Destination (Join-Path $record.evidence "$Label-ready.json")
        Write-EsirJson -Path (Join-Path $record.evidence "$Label-settle-monitor.json") -Data @{peak_working_set_bytes=$peakWorking;peak_private_bytes=$peakPrivate;elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds;checkpoint_sha256=(Get-FileHash -LiteralPath $checkpoint).Hash.ToLowerInvariant()}
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }; $process.Dispose() }
    return
}
if ($Phase -eq 'Create') {
    $created=Invoke-NativeProcess -FilePath $record.engine -Arguments (@('--create',$Save,'--map-gen-seed','137013')+$common) -OutputPath (Join-Path $record.evidence "$Label-create.log")
    if ($created.exit_code -ne 0) { throw 'Fixture creation failed; inspect evidence log.' }
    if ($Phase -eq 'Create') { return }
}
$arguments=if($Phase -eq 'Visual'){@('--benchmark-graphics',$Save,'--benchmark-ticks',"$Ticks",'--benchmark-runs',"$Runs",'--window-size','1280x720')}else{@('--benchmark',$Save,'--benchmark-ticks',"$Ticks",'--benchmark-runs',"$Runs",'--benchmark-verbose','all')}
if ($record.performance -gt 0 -and $Phase -eq 'Run') {
    $deadline=[DateTime]::UtcNow.AddMinutes(10)
    while (Get-Process factorio -ErrorAction SilentlyContinue) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Another Factorio run is still active; performance measurement requires an idle engine slot.' }
        Start-Sleep -Seconds 1
    }
}
$started=[DateTime]::UtcNow
python (Join-Path $PSScriptRoot 'qc/factory-passage/process.py') --context $ContextPath --phase $Phase --save $Save --label $Label --ticks $Ticks --runs $Runs --receipt $ExpectedReceipt
if ($LASTEXITCODE -ne 0) { throw 'Native fixture failed; inspect evidence log.' }
if ($record.helper -eq 'esir-factory-passage-qc') {
    if ($record.performance -gt 0) { $ExpectedReceipt=if($record.burst){'performance-burst'}else{'performance-idle'} }
    $receiptPath=Join-Path $record.write_data "script-output/factory-passage/$ExpectedReceipt.json"
    $accepted=Read-EsirJson $receiptPath
    if ((Get-Item -LiteralPath $receiptPath).LastWriteTimeUtc -lt $started -or $accepted.passed -ne $true -or $accepted.engine -ne '2.1.24' -or $accepted.mode -ne $record.mode -or $accepted.enabled -ne $record.enabled -or @($accepted.checks).Count -eq 0 -or @($accepted.checks | Where-Object {$_.passed -ne $true}).Count -gt 0) { throw 'Missing, stale, mismatched or failed native receipt.' }
    if ($ExpectedReceipt -eq 'transition' -and $accepted.transition -ne $true) { throw 'Configuration change was not observed.' }
    Copy-Item -LiteralPath $receiptPath -Destination (Join-Path $record.evidence "$Label.json")
}
