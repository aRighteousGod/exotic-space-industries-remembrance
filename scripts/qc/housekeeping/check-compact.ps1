# Compact lifecycle and mutable-fixture regression checks in a new isolated repo.
[CmdletBinding()]
param([string]$RepoRoot, [switch]$KeepFixture)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
$fixture = Join-Path $RepoRoot ('output/qc-compact-tests-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$checks = 0
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Summary($Run, [string]$Status = 'ok') {
    return @{run_id=$Run.id; workflow=$Run.workflow; engine_version=$Run.engine_version; repo_root=$Run.repo_root;
        payload_path=$Run.payload_path; timestamp=[DateTime]::UtcNow.ToString('o'); overall_status=$Status}
}
function New-CompactRun([string]$Workflow = 'qc-fast', [string]$Mode = 'read-only') {
    $run = Register-EsirArtifactRun -RepoRoot $fixture -Workflow $Workflow -EngineVersion 2.1.23 -Reproduction 'isolated compact lifecycle regression'
    $context = [pscustomobject]@{artifact_root=(Join-Path $fixture '.factorio-qc');run_mod_directory=''}
    $roots = Initialize-EsirManagedQcContext -RepoRoot $fixture -Context $context -RunId $run.id -SourceMode $Mode
    return @{run=$run;context=$context;roots=$roots}
}
try {
    & git -C $fixture init -q
    if ($LASTEXITCODE) { throw 'Isolated Git fixture initialization failed.' }
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "/.factorio-qc/`n/output/`n")
    $source = Join-Path $fixture 'source-fixture'
    [void][IO.Directory]::CreateDirectory($source)
    [IO.File]::WriteAllText((Join-Path $source 'info.json'), '{"name":"source-fixture","version":"1.0.0","factorio_version":"2.1"}')
    [IO.File]::WriteAllText((Join-Path $source 'control.lua'), '-- authoritative source')
    $originalHash = (Get-FileHash -LiteralPath (Join-Path $source 'control.lua')).Hash

    $active = New-CompactRun
    [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action stage -Data @{run_id=$active.run.id; sources=@(@{path=$source});packages=@()})
    $dump = Join-Path $active.roots.scratch_root 'data-raw-dump.json'
    [IO.File]::WriteAllText($dump, '{"item":{"fixture":{"name":"fixture"}}}')
    $done = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $active.run.id -ExitCode 0 -Summary (Summary $active.run) -DumpPath $dump
    Assert ($done.status -eq 'success') "Compact completion failed: $($done.housekeeping_error)"
    Assert (-not (Test-Path -LiteralPath $active.roots.mod_view_root)) 'Completed run retained its source junction view'
    Assert ((Get-EsirRetainedFinalData $fixture 2.1.23) -eq $dump) 'Active verified dump unavailable to its consumer'
    [void](Set-EsirArtifactRunState $fixture $active.run.id pin 'dump investigation')
    [void](Set-EsirArtifactRunState $fixture $active.run.id pin 'second consumer')
    $closed = Set-EsirArtifactRunState $fixture $active.run.id close
    Assert (Test-Path -LiteralPath $dump) 'Pin failed to preserve required raw evidence'
    Assert ((Get-EsirRetainedFinalData $fixture 2.1.23) -eq $dump) 'Pinned dump lookup failed'
    $closed = Set-EsirArtifactRunState $fixture $active.run.id unpin 'dump investigation'
    $lease = Invoke-EsirQcStorage -RepoRoot $fixture -Action inspect -Data @{run_id=$active.run.id}
    Assert (@($lease.pins).Count -eq 1 -and $lease.pins[0] -eq 'second consumer') 'Removing one pin altered another pin or re-added the removed label'
    Assert (Test-Path -LiteralPath $dump) 'Second consumer lost its evidence'
    $closed = Set-EsirArtifactRunState $fixture $active.run.id unpin 'second consumer'
    Assert ($closed.cleanup_status -eq 'compacted') "Compact close failed: $($closed.housekeeping_error)"
    Assert (-not (Test-Path -LiteralPath $dump)) 'Unpinned closed dump was retained'
    $rejected = $false
    try { Get-EsirRetainedFinalData $fixture 2.1.23 | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Final-data lookup returned retired output'
    Assert (Test-Path -LiteralPath (Join-Path $fixture ($closed.payload_path + '/evidence.zip'))) 'Compact evidence bundle missing'

    $failed = New-CompactRun -Workflow failure-fixture
    [IO.File]::WriteAllText((Join-Path $failed.roots.scratch_root 'factorio-current.log'), 'expected failure log')
    $done = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $failed.run.id -ExitCode 1 -Summary (Summary $failed.run failed)
    Assert ($done.status -eq 'failed' -and $done.cleanup_status -eq 'ready') 'Failure verdict or safe closeout readiness was lost'
    $done = Set-EsirArtifactRunState $fixture $failed.run.id close
    Assert ($done.status -eq 'failed' -and $done.cleanup_status -eq 'compacted') 'Failed run retained full scratch or lost its verdict'

    $retry = New-CompactRun -Workflow retry-fixture
    $cache = Join-Path $retry.roots.scratch_root 'cache.dat'
    [IO.File]::WriteAllText($cache, 'disposable cache')
    $null = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $retry.run.id -ExitCode 0 -Summary (Summary $retry.run)
    $cacheItem = Get-Item -LiteralPath $cache
    $cacheItem.IsReadOnly = $true
    $blocked = Set-EsirArtifactRunState $fixture $retry.run.id close
    Assert ($blocked.cleanup_status -eq 'protected-error' -and $blocked.closeout_retryable) 'Unsafe close was not protected and retryable'
    Assert (Test-Path -LiteralPath $cache) 'Protected close removed readonly scratch'
    $cacheItem.IsReadOnly = $false
    $done = Set-EsirArtifactRunState $fixture $retry.run.id close
    Assert ($done.cleanup_status -eq 'compacted' -and -not $done.housekeeping_error) 'Safe retry did not finish closeout'
    Assert (-not (Test-Path -LiteralPath $retry.roots.scratch_root)) 'Retried close retained scratch'

    $invalid = New-CompactRun
    $invalidDump = Join-Path $invalid.roots.scratch_root 'data-raw-dump.json'
    [IO.File]::WriteAllText($invalidDump, '{')
    $null = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $invalid.run.id -ExitCode 0 -Summary (Summary $invalid.run) -DumpPath $invalidDump
    [IO.File]::WriteAllText($invalidDump, '{"item":{}}')
    $blocked = Set-EsirArtifactRunState $fixture $invalid.run.id close
    Assert ($blocked.cleanup_status -eq 'protected-error' -and -not $blocked.closeout_retryable) 'Retry bypassed completion validation'
    Assert (Test-Path -LiteralPath $invalidDump) 'Unvalidated dump disappeared during close'
    # The intentionally invalid receipt stays protected. Dispose only this
    # synthetic test's owned storage after observing the refusal.
    $null = Invoke-EsirQcStorage -RepoRoot $fixture -Action close -Data @{run_id=$invalid.run.id;status='test-disposal'}

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = Join-Path $fixture 'dependency-fixture_1.0.0.zip'
    $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entry in @(@{name='info.json';text='{"name":"dependency-fixture","version":"1.0.0","factorio_version":"2.1"}'}, @{name='control.lua';text='-- canonical dependency control'})) {
            $stream = [IO.StreamWriter]::new($zip.CreateEntry(('dependency-fixture_1.0.0/' + $entry.name)).Open())
            try { $stream.Write($entry.text) } finally { $stream.Dispose() }
        }
    } finally { $zip.Dispose() }
    $archiveHash = (Get-FileHash -LiteralPath $archive).Hash
    $readOnly = Join-Path $fixture 'readonly-fixture'
    [void][IO.Directory]::CreateDirectory($readOnly)
    [IO.File]::WriteAllText((Join-Path $readOnly 'info.json'), '{"name":"readonly-fixture","version":"1.0.0","factorio_version":"2.1"}')
    [IO.File]::WriteAllText((Join-Path $readOnly 'control.lua'), '-- source that must never be isolated')
    $readOnlyHash = (Get-FileHash -LiteralPath (Join-Path $readOnly 'control.lua')).Hash
    foreach ($case in @(@{folder='machine-status-lights';script='isolate.py';helper='zzz-esir-machine-lights-qc'}, @{folder='entity-presentation';script='isolate-runtime.py';helper='zzz-esir-entity-presentation-qc'})) {
        $mutable = New-CompactRun -Workflow mutable-fixture -Mode private-mutable
        [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action stage -Data @{run_id=$mutable.run.id;sources=@(@{path=$source});packages=@(@{path=$archive})})
        $helper = Join-Path $mutable.roots.mod_view_root $case.helper
        [void][IO.Directory]::CreateDirectory($helper)
        [IO.File]::WriteAllText((Join-Path $helper 'info.json'), '{}')
        & python -B (Join-Path $RepoRoot ('scripts/qc/' + $case.folder + '/' + $case.script)) $mutable.roots.mod_view_root --repo $fixture --run-id $mutable.run.id | Out-Null
        if ($LASTEXITCODE) { throw "Mutable fixture isolation failed: $($case.folder)" }
        Assert ((Get-FileHash -LiteralPath (Join-Path $source 'control.lua')).Hash -eq $originalHash) 'Fixture modified authoritative source'
        Assert ((Get-FileHash -LiteralPath $archive).Hash -eq $archiveHash) 'Fixture modified a canonical archive through a hardlink'
        Assert ((Get-FileHash -LiteralPath (Join-Path $mutable.roots.mod_view_root 'dependency-fixture_1.0.0.zip')).Hash -ne $archiveHash) 'Fixture failed to create a distinct private archive variant'
        $done = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $mutable.run.id -ExitCode 0 -Summary (Summary $mutable.run)
        Assert ($done.status -eq 'success') "Private variant completion failed: $($done.housekeeping_error)"
        $done = Set-EsirArtifactRunState $fixture $mutable.run.id close
        Assert ($done.cleanup_status -eq 'compacted') "Private variant cleanup failed: $($done.housekeeping_error)"

        # A run-level private mode never makes an explicitly read-only source
        # junction writable. Both adapters must reject it before a source write.
        $rejectedRun = New-CompactRun -Workflow rejected-fixture -Mode private-mutable
        [void](Invoke-EsirQcStorage -RepoRoot $fixture -Action stage -Data @{
            run_id=$rejectedRun.run.id; sources=@(@{path=$source}, @{path=$readOnly;mode='read-only'}); packages=@()
        })
        $helper = Join-Path $rejectedRun.roots.mod_view_root $case.helper
        [void][IO.Directory]::CreateDirectory($helper)
        [IO.File]::WriteAllText((Join-Path $helper 'info.json'), '{}')
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $diagnostic = (& python -B (Join-Path $RepoRoot ('scripts/qc/' + $case.folder + '/' + $case.script)) $rejectedRun.roots.mod_view_root --repo $fixture --run-id $rejectedRun.run.id 2>&1 | Out-String)
            $isolationExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        Assert ($isolationExit -ne 0) 'Isolator accepted a read-only source junction'
        Assert ((Get-FileHash -LiteralPath (Join-Path $readOnly 'control.lua')).Hash -eq $readOnlyHash) 'Isolator changed read-only source through a junction'
        Assert ((Get-FileHash -LiteralPath (Join-Path $source 'control.lua')).Hash -eq $originalHash) 'Rejected isolation changed another authoritative source'
        [IO.File]::WriteAllText((Join-Path $rejectedRun.roots.evidence_root 'expected-rejection.txt'), $diagnostic)
        $null = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $rejectedRun.run.id -ExitCode 1 -Summary (Summary $rejectedRun.run failed)
        $done = Set-EsirArtifactRunState $fixture $rejectedRun.run.id close
        Assert ($done.cleanup_status -eq 'compacted') "Rejected fixture cleanup failed: $($done.housekeeping_error)"
    }
    $historical = Register-EsirArtifactRun -RepoRoot $fixture -Workflow historical-fixture -Reproduction 'synthetic historical path' -PayloadPath 'output/historical-fixture'
    $historicalPath = Join-Path $fixture $historical.payload_path
    $relocated = Join-Path $fixture 'output/relocated-fixture'
    [void][IO.Directory]::CreateDirectory($relocated)
    [IO.File]::WriteAllText((Join-Path $relocated 'retained.txt'), 'historical evidence')
    [IO.Directory]::Delete($historicalPath)
    $null = New-Item -ItemType Junction -Path $historicalPath -Target $relocated
    $afterHistorical = New-CompactRun -Workflow historical-boundary-fixture
    Assert ([bool]$afterHistorical.run.id) 'Unrelated historical junction blocked new ownership'
    $rejected = $false
    try { Register-EsirArtifactRun -RepoRoot $fixture -Workflow invalid -Reproduction 'must reject' -PayloadPath 'output/historical-fixture/nested' | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Registration traversed a historical junction'
    $rejected = $false
    try { Register-EsirArtifactRun -RepoRoot $fixture -Workflow invalid -Reproduction 'must reject target overlap' -PayloadPath 'output/relocated-fixture/nested' | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Registration overlapped a historical junction target'
    [IO.Directory]::Delete($historicalPath)
    Assert ((Get-Content -LiteralPath (Join-Path $relocated 'retained.txt') -Raw) -eq 'historical evidence') 'Historical junction teardown changed its target'
    $null = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $afterHistorical.run.id -ExitCode 0 -Summary (Summary $afterHistorical.run)
    $done = Set-EsirArtifactRunState $fixture $afterHistorical.run.id close
    Assert ($done.cleanup_status -eq 'compacted') 'New run after historical relocation did not close'

    $report = Invoke-EsirHousekeeping $fixture
    Assert (@($report.runs | Where-Object disposition -eq 'compact-evidence').Count -eq 8) 'Compact receipts entered legacy bulk retention'
    Assert (@($report.runs | Where-Object disposition -eq 'protected-error').Count -eq 1) 'Invalid completion lost its protected status'
    if (-not $KeepFixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $boundary = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'output')).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped output.' }
        if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Fixture contains unexpected links; retain for inspection.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    @{status='passed';checks=$checks;fixture=$fixture;removed=(-not $KeepFixture.IsPresent)} | ConvertTo-Json
} catch {
    Write-Warning "Compact lifecycle fixture retained for inspection: $fixture"
    throw
}
