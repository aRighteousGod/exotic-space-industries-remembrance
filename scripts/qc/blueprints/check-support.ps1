[CmdletBinding()]
param([string]$RepoRoot)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$repo = (Resolve-Path $RepoRoot).Path
. (Join-Path $repo 'scripts\esir-dev-lib.ps1')
$fixtureRoot = Join-Path $repo ('output\blueprint-support-' + [Guid]::NewGuid().ToString('N').Substring(0, 10))
New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null

# Import the actual header functions without executing the manifest/header sync.
$parseErrors = $null
$parseTokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts\sync-esir-headers.ps1'), [ref]$parseTokens, [ref]$parseErrors)
foreach ($functionName in @('ConvertTo-HeaderList', 'Remove-ExistingHeader', 'Set-HeaderContent')) {
    $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $functionName }, $true)
    . ([scriptblock]::Create($node.Extent.Text))
}
$lua = Join-Path $fixtureRoot 'example.lua'
$marker = '-- blueprint: .codex/esir/blueprints/example.md#contract'
$reference = '-- blueprint-ref: .codex/esir/blueprints/example.md#lifecycle'
$body = "$marker`n$reference`n-- Preserve this invariant commentary.`nreturn {value = 1}`n"
[IO.File]::WriteAllText($lua, $body, [Text.UTF8Encoding]::new($false))
$metadata = @{ owns = 'fixture'; loaded_by = 'control.lua'; cadence = 'event'; forwarded_events = @(); storage_roots = @(); gui_ids = @(); remote_interfaces = @(); rebuild_on = @() }
Set-HeaderContent -FilePath $lua -Prefix '--' -Metadata $metadata
Set-HeaderContent -FilePath $lua -Prefix '--' -Metadata $metadata
$actual = [IO.File]::ReadAllText($lua)
if ((Remove-ExistingHeader -Content $actual -Prefix '--') -ne $body) { throw 'Header regeneration did not preserve commentary and code exactly.' }
if ([regex]::Matches($actual, [regex]::Escape($marker)).Count -ne 1) { throw 'Header regeneration duplicated the primary marker.' }

$python = (Get-Command python -ErrorAction Stop).Source
$auditRelative = '.codex\skills\esir-conceptual-blueprints\scripts\blueprint_audit.py'
$fixtureAudit = Join-Path $fixtureRoot $auditRelative
New-Item -ItemType Directory -Force -Path (Split-Path $fixtureAudit) | Out-Null
Copy-Item -LiteralPath (Join-Path $repo $auditRelative) -Destination $fixtureAudit
$paths = @{ repo_root = $fixtureRoot }
$context = @{ python_exe = $python }
$failed = Test-EsirConceptualBlueprints -Paths $paths -Context $context
if ($failed.status -ne 'failed' -or (Get-EsirOverallStatus -Checks @($failed)) -ne 'failed') { throw 'Structural failure did not fail the preflight aggregate.' }
$missingPython = Test-EsirConceptualBlueprints -Paths $paths -Context @{ python_exe = $null }
if ($missingPython.status -ne 'failed') { throw 'Missing Python passed a required coverage check.' }
$missingScript = Test-EsirConceptualBlueprints -Paths @{ repo_root = (Join-Path $fixtureRoot 'missing') } -Context $context
if ($missingScript.status -ne 'failed') { throw 'Missing audit script passed a required coverage check.' }

# Use real source discovery in an isolated pack; installed Factorio/mod selection
# is irrelevant to header coverage. Keep this context override local to the fixture.
& {
    function Get-EsirQcContext {
        param($Paths)
        return @{ source_mods = @(@{ directory = Join-Path $Paths.repo_root 'exotic-space-industries-remembrance' }) }
    }
    $headerPaths = Get-EsirPaths -RepoRoot $fixtureRoot
    $pack = Join-Path $fixtureRoot 'exotic-space-industries-remembrance'
    $runtimeModule = Join-Path $pack 'scripts\control\new-module.lua'
    $prototypeModule = Join-Path $pack 'prototypes\new-module.lua'
    foreach ($path in @($runtimeModule, $prototypeModule, $headerPaths.runtime_manifest_path)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $pack 'control.lua'), 'local module = require("scripts/control/new-module")' + "`nreturn module`n")
    [IO.File]::WriteAllText((Join-Path $pack 'data.lua'), 'require("prototypes/new-module")' + "`n")
    foreach ($path in @($runtimeModule, $prototypeModule)) { [IO.File]::WriteAllText($path, $body) }

    $withoutCaches = @(Get-EsirHeaderTargets -Paths $headerPaths)
    if ($runtimeModule -notin $withoutCaches -or $prototypeModule -notin $withoutCaches) {
        throw 'Absent manifests hid current runtime or prototype headers.'
    }
    $staleEntry = @{ path = 'exotic-space-industries-remembrance\scripts\control\removed.lua' }
    [IO.File]::WriteAllText($headerPaths.runtime_manifest_path, (@{ entries = @($staleEntry) } | ConvertTo-Json -Depth 4))
    [IO.File]::WriteAllText($headerPaths.prototype_index_path, (@{ direct_requires = @() } | ConvertTo-Json))
    $withStaleCaches = @(Get-EsirHeaderTargets -Paths $headerPaths)
    if (@(Compare-Object $withoutCaches $withStaleCaches).Count -ne 0) {
        throw 'Stale manifests changed live header coverage.'
    }
    $missingHeaders = @(Test-EsirHeaderPresence -Paths $headerPaths)
    if ($missingHeaders.Count -ne 2 -or @($missingHeaders | Where-Object { $_.missing.Count -ne 8 }).Count) {
        throw 'New source modules did not report all missing header fields.'
    }
    foreach ($path in @($runtimeModule, $prototypeModule)) {
        Set-HeaderContent -FilePath $path -Prefix '--' -Metadata $metadata
    }
    if (@(Test-EsirHeaderPresence -Paths $headerPaths).Count -ne 0) {
        throw 'Complete source headers did not clear the live audit.'
    }
}
[ordered]@{ overall_status = 'ok'; checks = 9; header_roundtrip = $true; live_header_discovery = $true; stale_or_absent_manifests_ignored = $true; preflight_failure_propagation = $true; missing_tooling_fails = $true; fixture_root = $fixtureRoot } | ConvertTo-Json
