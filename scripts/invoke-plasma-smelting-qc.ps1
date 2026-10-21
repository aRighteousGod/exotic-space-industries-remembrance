[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunId,
    [ValidateSet('Prepare','Baseline','Candidate','Save','Reload')][string]$Phase = 'Candidate'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$record = Read-EsirArtifactRun $repo $RunId
if ($record.workflow -ne 'plasma-smelting') { throw 'Wrong artifact owner.' }
$run = Assert-EsirArtifactTarget $repo $record.payload_path
$mods = Join-Path $run 'mods'
$alias = Join-Path $repo ('.factorio-qc/ps-' + $RunId.Substring(0,8))
if ($Phase -eq 'Prepare') {
    python (Join-Path $PSScriptRoot 'qc/plasma-smelting/run.py') $repo $run $mods $Phase
    if ($LASTEXITCODE -ne 0) { throw 'Fixture preparation failed.' }
    return
}
if (Test-Path -LiteralPath $alias) { throw "Short mod path already exists: $alias" }
New-Item -ItemType Junction -Path $alias -Target $mods | Out-Null
try {
    python (Join-Path $PSScriptRoot 'qc/plasma-smelting/run.py') $repo $run $alias $Phase
    if ($LASTEXITCODE -ne 0) { throw "Fixture failed: $Phase" }
} finally {
    $link = Get-Item -LiteralPath $alias
    if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $link.Target -ne $mods) { throw 'Unexpected short path target.' }
    [IO.Directory]::Delete($alias)
}
