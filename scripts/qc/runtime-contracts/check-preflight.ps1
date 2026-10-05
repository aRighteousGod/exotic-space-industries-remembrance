[CmdletBinding()]
param([string]$RepoRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$errors = $null; $tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts/esir-dev-lib.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw 'Repository support library does not parse.' }
foreach ($name in @('New-EsirCheckResult', 'Get-EsirOverallStatus', 'Test-EsirRuntimeContractAdvice', 'Invoke-EsirPreflight')) {
    $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    if (-not $node) { throw "Missing actual preflight function: $name" }
    . ([scriptblock]::Create($node.Extent.Text))
}
# Isolate unrelated checks while exercising the real aggregator and subprocess.
function Get-EsirQcContext { return @{python_exe = $script:python} }
function Test-EsirConceptualBlueprints { return New-EsirCheckResult -Name 'fixture-blocker' -Status $script:normalStatus }
function Test-EsirReachableLuaFiles { return @{skipped=$false;failures=@()} }
function Test-PythonFiles { return @{skipped=$false;failures=@()} }
function Test-PowerShellFiles { return @() }
function Invoke-EsirEncodingPass { return @{overall_status='ok';findings=@()} }
function Get-EsirRequireFindings { return @() }
function Get-LocaleDuplicateFindings { return @() }
function Get-LocaleMissingFindings { return @() }
function Get-EsirAssetReferenceFindings { return @() }
function Get-EsirPackVersionFindings { return @() }
function Test-EsirHeaderPresence { return @() }
$root = Join-Path $repo ('.factorio-qc/runtime-standards-support-' + [Guid]::NewGuid().ToString('N'))
$audit = Join-Path $root '.codex/skills/esir-dev/scripts/runtime_contract_audit.py'
New-Item -ItemType Directory -Path (Split-Path $audit) -Force | Out-Null
$paths = @{repo_root=$root}
$script:python = (Get-Command python -ErrorAction Stop).Source
$pythonExe = $script:python
$script:normalStatus = 'ok'
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = 0
foreach ($scenario in @('clean','findings','missing-python','missing-script','exit-error','malformed','invalid-shape')) {
    $script:python = $pythonExe
    $body = switch ($scenario) {
        'findings' { 'print(''{"run_status":"ok","blocking":false,"findings":[{"rule":"fixture"}]}'')' }
        'exit-error' { 'raise SystemExit(2)' }
        'malformed' { 'print("not json")' }
        'invalid-shape' { 'print("{}")' }
        default { 'print(''{"run_status":"ok","blocking":false,"findings":[]}'')' }
    }
    [IO.File]::WriteAllText($audit, $body, $utf8)
    $scenarioPaths = $paths
    if ($scenario -eq 'missing-python') { $script:python = $null }
    if ($scenario -eq 'missing-script') { $scenarioPaths = @{repo_root=(Join-Path $root 'missing')} }
    foreach ($strict in @($false,$true)) {
        $result = Invoke-EsirPreflight -Paths $scenarioPaths -Strict:$strict
        if ($result.overall_status -ne 'ok') { throw "$scenario changed aggregate under Strict=$strict" }
        $expected = if ($scenario -in @('clean','findings')) { 'ok' } else { 'unavailable' }
        if ($result.advisory_checks[0].run_status -ne $expected -or $result.advisory_checks[0].blocking) { throw "$scenario was not reported correctly" }
        if (@($result.checks | Where-Object name -eq 'runtime-contracts').Count -ne 0) { throw 'Advisory entered blocking checks' }
        $checks++
    }
}
$script:python=$pythonExe
foreach ($normalStatus in @('failed','warning')) {
    $script:normalStatus=$normalStatus
    foreach ($strict in @($false,$true)) {
        $result = Invoke-EsirPreflight -Paths $paths -Strict:$strict
        $expected = if ($normalStatus -eq 'failed' -or $strict) { 'failed' } else { 'warning' }
        if ($result.overall_status -ne $expected) { throw 'Normal blocking/strict warning semantics changed' }
        $checks++
    }
}
[ordered]@{overall_status='ok';checks=$checks;advisory_nonblocking=$true;strict_preserved=$true;fixture_root=$root} | ConvertTo-Json
