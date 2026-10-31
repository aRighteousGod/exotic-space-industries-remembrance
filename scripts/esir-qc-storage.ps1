# Shared managed-storage bridge. Python owns storage policy; callers own QC verdicts.
function Invoke-EsirQcStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Action,
        $Data = @{}
    )
    $scriptPath = Join-Path $PSScriptRoot 'esir_qc_storage.py'
    $request = $Data | ConvertTo-Json -Depth 64 -Compress
    $oldEncoding = $OutputEncoding
    try {
        $OutputEncoding = [Text.UTF8Encoding]::new($false)
        $response = $request | & python -X utf8 -B $scriptPath --repo $RepoRoot --action $Action
        if ($LASTEXITCODE -ne 0) { throw "Managed QC storage action '$Action' failed; inspect its protected-error diagnostic." }
        return ($response | Out-String | ConvertFrom-Json)
    } finally { $OutputEncoding = $oldEncoding }
}
