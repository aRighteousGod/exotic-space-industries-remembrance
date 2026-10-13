[CmdletBinding()]
param(
    [string]$RunName = ('af-' + [Guid]::NewGuid().ToString('N').Substring(0,8)),
    [string]$SeedModDirectory,
    [string]$SaveInput,
    [string]$SourceRoot
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$exe = 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$source = if ($SourceRoot) { (Resolve-Path -LiteralPath $SourceRoot).Path } else { Join-Path $repo 'exotic-space-industries-remembrance' }
$fixture = Join-Path $PSScriptRoot 'qc/auric-fumaroles'
$utf8 = [Text.UTF8Encoding]::new($false)
if ($RunName -notmatch '^[A-Za-z0-9_-]+$') { throw 'RunName must be a simple directory name.' }
if ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -ne '2.0.77') { throw 'This fixture requires Factorio 2.0.77.' }
if (-not $SeedModDirectory) {
    foreach ($candidate in @('.factorio-qc/fmqc/mods-live','output/tesla-run-mods')) {
        if (Test-Path -LiteralPath (Join-Path $repo "$candidate/mod-list.json")) { $SeedModDirectory = Join-Path $repo $candidate; break }
    }
}
if (-not $SeedModDirectory -or -not (Test-Path -LiteralPath (Join-Path $SeedModDirectory 'mod-list.json'))) { throw 'Supply an existing dependency seed with -SeedModDirectory.' }
$registrations = @()
$reports = @()
$benchmarkTicks = 1000
$save = if ($SaveInput) { (Resolve-Path -LiteralPath $SaveInput).Path } else { $null }
try {
foreach ($mode in @('save','ordinary','configuration')) {
    $name = "$RunName-$mode"
    $registration = Register-EsirArtifactRun -RepoRoot $repo -Workflow 'auric-fumaroles' -Scenario $mode -EngineVersion '2.0.77' -PayloadPath ".factorio-qc/cu/g/$name" -Reproduction "scripts/invoke-auric-fumarole-qc.ps1 -RunName $RunName"
    $registrations += $registration
    $run = Join-Path $repo $registration.payload_path
    # Registration creates an empty payload; the reused staging driver requires
    # an absent directory. Remove only this verified empty, non-reparse directory.
    $registered = Get-Item -LiteralPath $run -Force
    if ($registered.FullName -ne [IO.Path]::GetFullPath("$repo/.factorio-qc/cu/g/$name") -or
        ($registered.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        @(Get-ChildItem -LiteralPath $run -Force).Count -ne 0) { throw 'Expected a new empty registered payload.' }
    [IO.Directory]::Delete($registered.FullName)
    $extra = @{}
    if ($save) { $extra.SaveInput = $save }
    if ($mode -eq 'configuration') { $extra.ForceConfig = $true }
    & "$PSScriptRoot/invoke-control-ups-qc.ps1" -RunName $name -BaselineSource $source -SourceRoot $source -PrepareOnly -CaptureConfiguration -Helper "$PSScriptRoot/qc/control-ups/lifecycle-helper" -BridgePath "$fixture/bridge.lua" -ExportsPath "$fixture/exports.json" -SeedModDirectory $SeedModDirectory -Ticks $benchmarkTicks -Runs 1 @extra | Out-Null
    # Capture the real registered command only in the private staged module.
    $module = Join-Path $run 'mods/exotic-space-industries-remembrance/scripts/control/vulcanus-fumaroles.lua'
    $text = [IO.File]::ReadAllText($module).Replace('commands.add_command(', 'qc_add_command(')
    $prefix = "local qc_command`nlocal function qc_add_command(name, help, handler)`n    qc_command = handler`n    commands.add_command(name, help, handler)`nend`n"
    [IO.File]::WriteAllText($module, $prefix + $text, $utf8)
    $manifestPath = Join-Path $run 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifest | Add-Member -NotePropertyName staged_fumarole_sha256 -NotePropertyValue (Get-FileHash -LiteralPath $module).Hash
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), $utf8)
    $inputSave = if ($save) { $save } else { Join-Path $run 'fixture.zip' }
    $arguments = @('--config',"$run/config.ini",'--mod-directory',"$run/mods",'--disable-audio')
    $saved = Join-Path $run 'saves/auric-pending.zip'
    if ($mode -eq 'save') {
        New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
        $options = Get-Content -LiteralPath 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/server-settings.example.json' -Raw | ConvertFrom-Json
        $options.name = 'Auric rebuild lifecycle QC'
        $options.visibility.public = $false; $options.visibility.lan = $false
        $options.require_user_verification = $false; $options.auto_pause = $false
        [IO.File]::WriteAllText("$run/server-settings.json", ($options | ConvertTo-Json -Depth 8), $utf8)
        $arguments += @('--start-server',$inputSave,'--server-settings',"$run/server-settings.json",'--port','34327')
    } else {
        $arguments += @('--benchmark',$inputSave,'--benchmark-ticks',"$benchmarkTicks",'--benchmark-runs','1')
    }
    Write-Output "Auric QC $mode : $run"
    $process = Start-Process -FilePath $exe -ArgumentList @($arguments | ForEach-Object {'"'+$_+'"'}) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/engine.txt" -RedirectStandardError "$run/stderr.txt"
    $process.Handle | Out-Null
    $ready = $false; $engineExit = 1; $deadline = (Get-Date).AddMinutes(5)
    try {
        while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
            if ((Test-Path -LiteralPath "$run/factorio-current.log") -and (Select-String -LiteralPath "$run/factorio-current.log" -Pattern 'Error while running event|Error Util.cpp|Hosting multiplayer game failed' -Quiet)) { throw "Engine error: $run/factorio-current.log" }
            if ($mode -eq 'save' -and (Test-Path -LiteralPath $saved)) {
                try { $archive = [IO.Compression.ZipFile]::OpenRead($saved); $archive.Dispose(); $ready = $true } catch {}
                if ($ready) { break }
            }
            Start-Sleep -Milliseconds 250
            $process.Refresh()
        }
        if ($mode -eq 'save') {
            if (-not $ready) { throw "Native saved fixture missing: $run" }
            $save = $saved
            $engineExit = 0
        } else {
            if (-not $process.HasExited) { throw "Engine timeout: $run" }
            $engineExit = $process.ExitCode
        }
    } finally {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
        # Remove only verified junction objects owned by this staging directory.
        $modsRoot = [IO.Path]::GetFullPath("$run/mods")
        foreach ($link in Get-ChildItem -LiteralPath $modsRoot -Directory) {
            if ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $expected = Join-Path $repo $link.Name
                if ($link.Parent.FullName -ne $modsRoot -or $link.LinkType -ne 'Junction' -or $link.Target -ne $expected) { throw 'Unexpected staging junction identity.' }
                [IO.Directory]::Delete($link.FullName)
            }
        }
    }
    if ($engineExit -ne 0) { throw "Engine exited $engineExit : $run/stderr.txt" }
    $reportPath = Join-Path $run 'script-output/auric-rebuild-qc.json'
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($mode -eq 'save') { $benchmarkTicks = [int][Math]::Max(1000, [Math]::Ceiling($report.pending_backfill/4)*30+120) }
    $expectedKind = if ($mode -eq 'save') {'save'} elseif ($mode -eq 'ordinary') {'ordinary-reload'} else {'configuration-reload'}
    $passed = $engineExit -eq 0 -and $report.all_pass -and $report.kind -eq $expectedKind
    $summary = @{run_id=$registration.id;workflow=$registration.workflow;engine_version=$registration.engine_version;repo_root=$registration.repo_root;payload_path=$registration.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status=if($passed){'ok'}else{'error'};result=$report}
    $completion = Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode $engineExit -Summary $summary
    $reports += @{mode=$mode;checks=$report.checks.Count;report=$reportPath;run_id=$registration.id;status=$summary.overall_status;housekeeping_status=$completion.status}
    if (-not $passed) { throw "Auric QC failed: $reportPath" }
}
} catch {
    if ($registration) {
        $failure = @{run_id=$registration.id;workflow=$registration.workflow;engine_version=$registration.engine_version;repo_root=$registration.repo_root;payload_path=$registration.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='error';result=@{error=$_.Exception.Message}}
        try { Complete-EsirArtifactRun -RepoRoot $repo -RunId $registration.id -ExitCode 1 -Summary $failure | Out-Null } catch { Write-Warning "Could not finalize failed QC evidence: $_" }
    }
    throw
} finally {
foreach ($registration in $registrations) { Set-EsirArtifactRunState -RepoRoot $repo -RunId $registration.id -Action close | Out-Null }
}
$reports | ConvertTo-Json -Depth 5
