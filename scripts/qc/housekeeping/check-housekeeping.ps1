[CmdletBinding()]
param([string]$RepoRoot)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
. (Join-Path $RepoRoot 'scripts/esir-housekeeping.ps1')
$fixtureParent = Join-Path $RepoRoot 'output'
$fixture = Join-Path $fixtureParent ('housekeeping-tests-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$checks = 0
$passed = $false
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Rejected([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert $rejected $Message
}
function New-TestRun([string]$Scenario = 'default', [string]$Engine = '2.0.77', [string]$Workflow = 'fixture') {
    $run = Register-EsirArtifactRun -RepoRoot $fixture -Workflow $Workflow -Scenario $Scenario -EngineVersion $Engine -Reproduction 'synthetic fixture'
    [IO.File]::WriteAllText((Join-Path $fixture ($run.payload_path + '/payload.txt')), 'disposable content')
    return $run
}
function New-TestSummary($Run) {
    return [ordered]@{ run_id = $Run.id; workflow = $Run.workflow; engine_version = $Run.engine_version; repo_root = $Run.repo_root; payload_path = $Run.payload_path; timestamp = [DateTime]::UtcNow.ToString('o'); overall_status = 'ok'; measurements = @{ count = 3 } }
}
function Finish-TestRun($Run, [int]$ExitCode = 0, [switch]$Open, [string]$DumpPath) {
    $done = Complete-EsirArtifactRun -RepoRoot $fixture -RunId $Run.id -ExitCode $ExitCode -Summary (New-TestSummary $Run) -DumpPath $DumpPath
    if (-not $Open) { [void](Set-EsirArtifactRunState $fixture $Run.id close) }
    return $done
}
try {
    & git -C $fixture init -q
    if ($LASTEXITCODE) { throw 'Cannot create isolated Git fixture.' }
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "/.factorio-qc/`n/output/`n/temp/`n")
    & git -C $fixture add .gitignore
    foreach ($name in @('models', 'exotic-space-industries-remembrance', 'exotic-space-industries-remembrance-graphics-1', 'exotic-space-industries-remembrance-soundtrack-1', 'another-mod')) {
        [void][IO.Directory]::CreateDirectory((Join-Path $fixture $name))
        [IO.File]::WriteAllText((Join-Path $fixture "$name/sentinel.txt"), 'untouched source')
        if ($name -eq 'another-mod') { [IO.File]::WriteAllText((Join-Path $fixture "$name/info.json"), '{}') }
    }
    foreach ($target in @('models/new', 'exotic-space-industries-remembrance/new', 'exotic-space-industries-remembrance-graphics-1/new', 'exotic-space-industries-remembrance-soundtrack-1/new', 'another-mod/new', '.git/new', '../escape', '.factorio-qc/../models/new', '.factorio-qc/fmqc/mods-live/new', '.factorio-qc/dependency-seed/new')) {
        Assert-Rejected { Register-EsirArtifactRun -RepoRoot $fixture -Workflow fixture -Reproduction test -PayloadPath $target } "Accepted forbidden target $target"
    }
    Assert-Rejected { Register-EsirArtifactRun -RepoRoot $fixture -Workflow fixture -Reproduction test -PayloadPath ($fixture + '-sibling/payload') } 'Sibling-prefix escape accepted'
    [void][IO.Directory]::CreateDirectory((Join-Path $fixture '.factorio-qc/legacy'))
    [IO.File]::WriteAllText((Join-Path $fixture '.factorio-qc/legacy/evidence'), 'historical')
    Assert-Rejected { Register-EsirArtifactRun -RepoRoot $fixture -Workflow fixture -Reproduction test -PayloadPath '.factorio-qc/legacy' } 'Legacy directory adopted automatically'

    $old = New-TestRun
    $oldDone = Finish-TestRun $old
    Assert ($oldDone.status -eq 'success') "Success failed: $($oldDone.housekeeping_error)"
    $second = New-TestRun; [void](Finish-TestRun $second)
    $third = New-TestRun; [void](Finish-TestRun $third)
    $report = Invoke-EsirHousekeeping $fixture
    Assert ((@($report.runs | Where-Object disposition -eq eligible)).Count -eq 1) 'Latest-two dry run is wrong'
    Assert (Test-Path -LiteralPath (Join-Path $fixture $old.payload_path)) 'Dry run deleted payload'
    $report = Invoke-EsirHousekeeping $fixture -Apply
    Assert ($report.deleted_file_count -eq 1) "Wrong deletion count: $($report | ConvertTo-Json -Depth 4 -Compress)"
    Assert (-not (Test-Path -LiteralPath (Join-Path $fixture $old.payload_path))) 'Oldest payload remains'
    Assert ((Read-EsirArtifactRun $fixture $old.id).summary.measurements.count -eq 3) 'Compact summary was lost'
    Assert (Test-Path -LiteralPath (Join-Path $fixture '.factorio-qc/legacy/evidence')) 'Unknown output was deleted'

    $long = New-TestRun -Scenario long-path
    $longDirectory = Join-Path (Join-Path $fixture $long.payload_path) ('nested-' + ('x' * 70))
    $longFile = Join-Path $longDirectory ('leaf-' + ('y' * 70) + '.txt')
    [void][IO.Directory]::CreateDirectory([EsirArtifactFile]::ExtendedPath($longDirectory))
    [IO.File]::WriteAllText([EsirArtifactFile]::ExtendedPath($longFile), 'long path scratch')
    Assert ($longFile.Length -gt 260) 'Long-path fixture did not exceed the legacy limit'
    $done = Finish-TestRun $long
    Assert ($done.status -eq 'success') "Long-path inventory failed: $($done.housekeeping_error)"
    1..2 | ForEach-Object { $extra = New-TestRun -Scenario long-path; [void](Finish-TestRun $extra) }
    [void](Invoke-EsirHousekeeping $fixture -Apply)
    Assert (-not [IO.Directory]::Exists((Join-Path $fixture $long.payload_path))) 'Long-path payload not retired'

    $active = New-TestRun; [void](Finish-TestRun $active -Open)
    $failed = New-TestRun; [void](Finish-TestRun $failed -ExitCode 1)
    $running = New-TestRun
    $unknown = New-TestRun -Engine unknown; [void](Finish-TestRun $unknown)
    $pinned = New-TestRun; [void](Finish-TestRun $pinned)
    [void](Set-EsirArtifactRunState $fixture $pinned.id pin comparison)
    $different = New-TestRun -Scenario another; [void](Finish-TestRun $different)
    $engine = New-TestRun -Engine 2.1.0; [void](Finish-TestRun $engine)
    1..3 | ForEach-Object { $extra = New-TestRun; [void](Finish-TestRun $extra) }
    [void](Invoke-EsirHousekeeping $fixture -Apply)
    foreach ($run in @($active, $failed, $running, $unknown, $pinned, $different, $engine)) {
        Assert (Test-Path -LiteralPath (Join-Path $fixture $run.payload_path)) "Protected run removed: $($run.id)"
    }
    Assert-Rejected { Set-EsirArtifactRunState $fixture $running.id close } 'Running work was closed'
    Assert-Rejected { Set-EsirArtifactRunState $fixture $running.id release resolved } 'Live owner was released'
    Assert-Rejected { Register-EsirArtifactRun -RepoRoot $fixture -Workflow fixture -Reproduction test -PayloadPath ($pinned.payload_path + '/nested') } 'Overlapping ownership accepted'

    $stale = New-TestRun
    $summary = New-TestSummary $stale; $summary.timestamp = '2000-01-01T00:00:00Z'
    $done = Complete-EsirArtifactRun $fixture $stale.id 0 $summary
    Assert ($done.status -eq 'failed') 'Stale result accepted'
    $mismatch = New-TestRun
    $summary = New-TestSummary $mismatch; $summary.run_id = 'wrong'
    Assert ((Complete-EsirArtifactRun $fixture $mismatch.id 0 $summary).status -eq 'failed') 'Foreign result accepted'

    foreach ($content in @('', '{}', '{"broken":', '{"trailing":1,}', '{"number":01}')) {
        $badDump = New-TestRun -Workflow qc-fast -Scenario bad-dump
        $dumpPath = Join-Path $fixture ($badDump.payload_path + '/data-raw-dump.json')
        [IO.File]::WriteAllText($dumpPath, $content)
        $done = Finish-TestRun $badDump -DumpPath $dumpPath
        Assert ($done.status -eq 'failed' -and -not $done.verified_dump) 'Invalid dump became retained final data'
    }
    $valid = New-TestRun -Workflow qc-fast -Scenario final-data
    $dumpPath = Join-Path $fixture ($valid.payload_path + '/data-raw-dump.json')
    [IO.File]::WriteAllText($dumpPath, '{"data":{"nested":[true,false,null,-1.2e+3,"a\\b",{}]}}')
    $done = Finish-TestRun $valid -DumpPath $dumpPath
    Assert ($done.status -eq 'success') "Valid dump failed: $($done.housekeeping_error)"
    Assert ((Get-EsirRetainedFinalData $fixture 2.0.77) -eq $dumpPath.Replace('/', '\')) 'Retained dump lookup failed'
    1..3 | ForEach-Object { $extra = New-TestRun; [void](Finish-TestRun $extra) }
    [void](Invoke-EsirHousekeeping $fixture -Apply)
    Assert (Test-Path -LiteralPath $dumpPath) 'Latest valid final data disappeared'

    foreach ($case in @('changed', 'added', 'tracked', 'locked', 'junction', 'catalog')) {
        $target = New-TestRun -Scenario $case
        [void](Finish-TestRun $target)
        1..2 | ForEach-Object { $extra = New-TestRun -Scenario $case; [void](Finish-TestRun $extra) }
        $payload = Join-Path $fixture $target.payload_path
        $file = Join-Path $payload 'payload.txt'
        $handle = $null
        switch ($case) {
            changed { [IO.File]::WriteAllText($file, 'new user work') }
            added { [IO.File]::WriteAllText((Join-Path $payload 'new.txt'), 'new user work') }
            tracked { & git -C $fixture add -f -- ($target.payload_path + '/payload.txt') }
            locked { $handle = [IO.File]::Open($file, 'Open', 'Read', 'None') }
            junction { New-Item -ItemType Junction -Path (Join-Path $payload 'source-link') -Target (Join-Path $fixture 'exotic-space-industries-remembrance') | Out-Null }
            catalog {
                [void][IO.Directory]::CreateDirectory((Join-Path $fixture '.codex/esir'))
                [IO.File]::WriteAllText((Join-Path $fixture '.codex/esir/save-catalog.json'), (@{ entries = @(@{ path = $target.payload_path + '/payload.txt' }) } | ConvertTo-Json -Depth 4))
            }
        }
        try {
            $report = Invoke-EsirHousekeeping $fixture -Apply
            Assert (Test-Path -LiteralPath $file) "$case payload deleted"
            Assert ((@($report.runs | Where-Object { $_.run_id -eq $target.id -and $_.disposition -eq 'protected-error' })).Count -eq 1) "$case not reported protected"
        } finally {
            if ($handle) { $handle.Dispose() }
            if ($case -eq 'junction') { [IO.Directory]::Delete((Join-Path $payload 'source-link')) }
        }
    }

    $linked = New-TestRun -Scenario hardlink
    $sourceFile = Join-Path $fixture 'exotic-space-industries-remembrance/sentinel.txt'
    $hashBefore = (Get-FileHash -LiteralPath $sourceFile).Hash
    $attributesBefore = (Get-Item -LiteralPath $sourceFile).Attributes
    New-Item -ItemType HardLink -Path (Join-Path $fixture ($linked.payload_path + '/shared.txt')) -Target $sourceFile | Out-Null
    [void](Finish-TestRun $linked)
    1..2 | ForEach-Object { $extra = New-TestRun -Scenario hardlink; [void](Finish-TestRun $extra) }
    [void](Invoke-EsirHousekeeping $fixture -Apply)
    Assert (-not (Test-Path -LiteralPath (Join-Path $fixture $linked.payload_path))) 'Disposable hardlink not removed'
    Assert ((Get-FileHash -LiteralPath $sourceFile).Hash -eq $hashBefore) 'Hardlink cleanup changed source'
    Assert ((Get-Item -LiteralPath $sourceFile).Attributes -eq $attributesBefore) 'Hardlink cleanup changed attributes'

    $inputRun = New-TestRun -Scenario input-protection; [void](Finish-TestRun $inputRun)
    1..2 | ForEach-Object { $extra = New-TestRun -Scenario input-protection; [void](Finish-TestRun $extra) }
    $consumer = Register-EsirArtifactRun -RepoRoot $fixture -Workflow render -EngineVersion none -Classification render-intermediates -Reproduction test -RetainedPaths @($inputRun.payload_path + '/payload.txt')
    $report = Invoke-EsirHousekeeping $fixture -Apply
    Assert ((@($report.runs | Where-Object { $_.run_id -eq $inputRun.id -and $_.disposition -eq 'retained-by-another-run' })).Count -eq 1) 'Another run lost its retained input'
    Assert (Test-Path -LiteralPath (Join-Path $fixture $inputRun.payload_path)) 'Retained input owner deleted'
    $claimed = Register-EsirArtifactRun -RepoRoot $fixture -Workflow render -Reproduction test -RetainedPaths @('.factorio-qc/future-durable/evidence.txt')
    Assert-Rejected { Register-EsirArtifactRun -RepoRoot $fixture -Workflow fixture -Reproduction test -PayloadPath '.factorio-qc/future-durable' } 'Absent retained evidence was claimed as disposable'

    # Registry serialization must fail safely instead of dropping a concurrent update.
    $lease = Enter-EsirHousekeepingLock $fixture
    try { Assert-Rejected { Set-EsirArtifactRunState $fixture $pinned.id unpin comparison } 'Concurrent registry writer bypassed lock' }
    finally { $lease.Dispose() }
    Assert (@((Read-EsirArtifactRun $fixture $pinned.id).pins).Count -eq 1) 'Concurrent lock conflict lost pin'

    $original = Register-EsirArtifactRun -RepoRoot $fixture -Workflow source-original -EngineVersion none -Classification protected-evidence -Reproduction 'Unique source before edit'
    [IO.File]::WriteAllText((Join-Path $fixture ($original.payload_path + '/original.png')), 'unique original')
    [void](Set-EsirArtifactRunState $fixture $original.id pin source)
    [void](Finish-TestRun $original)
    [void](Set-EsirArtifactRunState $fixture $original.id unpin source)
    1..2 | ForEach-Object { $extra = New-TestRun -Workflow source-original -Engine none; [void](Finish-TestRun $extra) }
    $report = Invoke-EsirHousekeeping $fixture -Apply
    Assert ((@($report.runs | Where-Object { $_.run_id -eq $original.id -and $_.disposition -eq 'durable-evidence' })).Count -eq 1) 'Unique source became disposable after unpinning'
    Assert (Test-Path -LiteralPath (Join-Path $fixture ($original.payload_path + '/original.png'))) 'Unique original disappeared'

    # Replacing a completed payload itself with a junction must never traverse its target.
    $alias = New-TestRun -Scenario ancestor-junction; [void](Finish-TestRun $alias)
    1..2 | ForEach-Object { $extra = New-TestRun -Scenario ancestor-junction; [void](Finish-TestRun $extra) }
    $aliasPath = Join-Path $fixture $alias.payload_path
    Remove-Item -LiteralPath (Join-Path $aliasPath 'payload.txt')
    [IO.Directory]::Delete($aliasPath)
    New-Item -ItemType Junction -Path $aliasPath -Target (Join-Path $fixture 'models') | Out-Null
    try {
        $report = Invoke-EsirHousekeeping $fixture -Apply
        Assert ((@($report.runs | Where-Object { $_.run_id -eq $alias.id -and $_.disposition -eq 'protected-error' })).Count -eq 1) 'Replaced ancestor junction followed'
    } finally { [IO.Directory]::Delete($aliasPath) }

    # Misleading registry paths must not grant access to protected source directories.
    $forged = New-TestRun -Scenario forged
    [void](Finish-TestRun $forged)
    1..2 | ForEach-Object { $extra = New-TestRun -Scenario forged; [void](Finish-TestRun $extra) }
    foreach ($protected in @('models', 'exotic-space-industries-remembrance', '.git')) {
        $record = Read-EsirArtifactRun $fixture $forged.id
        $record.payload_path = $protected
        Write-EsirArtifactJson $fixture (Get-EsirArtifactRecordPath $fixture $record.id) $record
        $report = Invoke-EsirHousekeeping $fixture -Apply
        Assert ((@($report.runs | Where-Object { $_.run_id -eq $forged.id -and $_.disposition -eq 'protected-error' })).Count -eq 1) 'Forged source ownership accepted'
    }
    foreach ($name in @('models', 'exotic-space-industries-remembrance', 'exotic-space-industries-remembrance-graphics-1', 'exotic-space-industries-remembrance-soundtrack-1', 'another-mod')) {
        Assert ([IO.File]::ReadAllText((Join-Path $fixture "$name/sentinel.txt")) -eq 'untouched source') "Source changed: $name"
    }
    $inventory = @(Get-EsirArtifactInventory $fixture -FullInventory)
    Assert (-not @($inventory | Where-Object { $_.path -match 'models|exotic-space|another-mod|^\.git$' }).Count) 'Inventory traversed source roots'
    $priorCodexHome = $env:CODEX_HOME
    [void][IO.Directory]::CreateDirectory((Join-Path $fixture 'models/sessions'))
    try {
        $env:CODEX_HOME = Join-Path $fixture 'models'
        $inventory = @(Get-EsirArtifactInventory $fixture -FullInventory -IncludeCodexHome)
        Assert (-not @($inventory | Where-Object { $_.path -match 'models' }).Count) 'External inventory override traversed models'
    } finally { $env:CODEX_HOME = $priorCodexHome }
    $passed = $true
    [ordered]@{ overall_status = 'ok'; checks = $checks; fixture_root = $fixture; real_backlog_modified = $false } | ConvertTo-Json
} finally {
    if ($passed) {
        # Only this newly created test repository is removed. A failure leaves evidence for diagnosis.
        $resolved = [IO.Path]::GetFullPath($fixture)
        if (-not $resolved.StartsWith(([IO.Path]::GetFullPath($fixtureParent).TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped output.' }
        if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Fixture still has a reparse point; refusing recursive cleanup.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
