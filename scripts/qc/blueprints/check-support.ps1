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
[ordered]@{ overall_status = 'ok'; checks = 5; header_roundtrip = $true; preflight_failure_propagation = $true; missing_tooling_fails = $true; fixture_root = $fixtureRoot } | ConvertTo-Json
