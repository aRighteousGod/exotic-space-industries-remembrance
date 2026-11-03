# Host-only preservation and native UTF-8 regression checks for Windows PowerShell and pwsh.
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$fixtureRoot = Join-Path $repo ('temp/encoding-tests-' + [guid]::NewGuid().ToString('N'))
$receiptRelative = 'scripts/qc/singularity-lance/angular-results.json'
$receipt = Join-Path $fixtureRoot $receiptRelative
$policyPath = Join-Path $fixtureRoot '.codex/esir/preserved-encoding.json'
$utf8 = [Text.UTF8Encoding]::new($false)
$checks = 0
function Assert-Check($Condition, $Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
try {
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $receipt), (Split-Path $policyPath)
    Copy-Item -LiteralPath (Join-Path $repo $receiptRelative) -Destination $receipt
    Copy-Item -LiteralPath (Join-Path $repo '.codex/esir/preserved-encoding.json') -Destination $policyPath
    $paths = [pscustomobject]@{repo_root=$fixtureRoot}
    $original = [IO.File]::ReadAllText($receipt, $utf8)
    $originalHash = (Get-FileHash -LiteralPath $receipt).Hash
    $result = Invoke-EsirEncodingPass -Paths $paths -Fix
    Assert-Check ($result.overall_status -eq 'ok' -and $result.preserved_files.Count -eq 1) 'Pinned receipt failed preservation'
    Assert-Check ((Get-FileHash -LiteralPath $receipt).Hash -eq $originalHash) 'Fix rewrote preserved evidence'
    foreach ($newline in @("`n", "`r`n")) {
        [IO.File]::WriteAllText($receipt, $original.Replace("`r`n", "`n").Replace("`n", $newline), $utf8)
        Assert-Check ((Invoke-EsirEncodingPass -Paths $paths).overall_status -eq 'ok') 'Checkout newline equivalence failed'
    }
    [IO.File]::WriteAllText($receipt, $original + ' ', $utf8)
    $changedHash = (Get-FileHash -LiteralPath $receipt).Hash
    Assert-Check ((Invoke-EsirEncodingPass -Paths $paths -Fix).overall_status -eq 'failed') 'Changed receipt accepted'
    Assert-Check ((Get-FileHash -LiteralPath $receipt).Hash -eq $changedHash) 'Fix rewrote a mismatched historical receipt'
    [IO.File]::WriteAllText($receipt, $original, $utf8)
    $policy = Read-EsirJson $policyPath
    $policy.entries[0].findings[0].count++
    Write-EsirJson -Path $policyPath -Data $policy
    Assert-Check ((Invoke-EsirEncodingPass -Paths $paths).overall_status -eq 'failed') 'Mismatched finding counts accepted'
    Copy-Item -LiteralPath (Join-Path $repo '.codex/esir/preserved-encoding.json') -Destination $policyPath -Force
    $corruptPath = Join-Path $fixtureRoot 'current-source.txt'
    [IO.File]::WriteAllText($corruptPath, ([string][char]0xE2 + [char]0x009D + [char]0x0152), $utf8)
    Assert-Check ((Invoke-EsirEncodingPass -Paths $paths).overall_status -eq 'failed') 'Unrelated corruption was exempted'
    Remove-Item -LiteralPath $corruptPath
    Remove-Item -LiteralPath $receipt
    Assert-Check ((Invoke-EsirEncodingPass -Paths $paths).overall_status -eq 'failed') 'Missing preserved receipt accepted'

    $probe = Join-Path $fixtureRoot 'utf8-probe.py'
    [IO.File]::WriteAllText($probe, @'
import sys
sys.stdout.buffer.write('Script @__probe__/control.lua:1: Error: \u274c\n'.encode('utf-8'))
sys.stdout.buffer.flush()
sys.stderr.buffer.write('Error while running native UTF-8 probe \u03a9\n'.encode('utf-8'))
sys.exit(7)
'@, $utf8)
    $log = Join-Path $fixtureRoot 'native.log'
    $consoleEncoding = [Console]::OutputEncoding.WebName
    $shellEncoding = $OutputEncoding.WebName
    $process = Invoke-NativeProcess -FilePath (Get-Command python).Source -Arguments @('-B', $probe) -OutputPath $log
    Assert-Check ($process.exit_code -eq 7) 'Native exit code changed'
    Assert-Check (($process.output -join "`n").Contains([string][char]0x274C)) 'Native stdout was decoded incorrectly'
    Assert-Check (($process.output -join "`n").Contains([string][char]0x03A9)) 'Native stderr was decoded incorrectly'
    Assert-Check ([Console]::OutputEncoding.WebName -eq $consoleEncoding -and $OutputEncoding.WebName -eq $shellEncoding) 'Caller encoding was not restored'
    $classification = Get-ClassifiedFactorioLog -LogPath $log -OutputLines $process.output
    Assert-Check ($classification.needs_review.Count -eq 1 -and $classification.fatal.Count -eq 1) 'Unicode log deduplication or fatal classification failed'
    Assert-Check ((Get-EsirEncodingHealth ([IO.File]::ReadAllText($log, $utf8))).score -eq 0) 'Native capture introduced mojibake'
    @{passed=$true;checks=$checks;powershell=$PSVersionTable.PSVersion.ToString();engine_launched=$false} | ConvertTo-Json -Compress
} finally {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $parent = [IO.Path]::GetFullPath((Join-Path $repo 'temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
