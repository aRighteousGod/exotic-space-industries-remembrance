# Scoped host checks and managed broad children. No context/engine discovery for planning or static checks.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('static','broad','register','finish')][string]$Action,
    [Parameter(Mandatory)][string]$Request)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$data = Read-EsirJson $Request
switch ($Action) {
    'static' {
        $paths = Get-EsirPaths -RepoRoot $repo
        $encoding = Invoke-EsirEncodingPass -Paths $paths -TargetPath @($data.paths)
        $errors = @()
        if ($encoding.overall_status -eq 'failed') { $errors += 'Scoped encoding validation failed.' }
        foreach ($relative in $data.paths) {
            $file = Join-Path $repo $relative
            if ([IO.Path]::GetExtension($file) -in @('.ps1','.psm1') -and (Test-Path -LiteralPath $file -PathType Leaf)) {
                $tokens = $null; $parseErrors = $null
                [void][Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$parseErrors)
                foreach ($errorItem in $parseErrors) { $errors += ($relative + ': ' + $errorItem.Message) }
            }
        }
        @{encoding=$encoding;errors=@($errors)} | ConvertTo-Json -Depth 20 -Compress
    }
    'broad' {
        $parameters = @{Paths=(Get-EsirPaths -RepoRoot $repo -EnsureWritableDirs);Mode=$data.mode;Strict=[bool]$data.strict}
        if ($data.engine) { $parameters.FactorioPath=$data.engine }
        if ($data.PSObject.Properties.Name -contains 'preview_scope') { $parameters.PreviewScope=$data.preview_scope }
        $result = Invoke-EsirQcMode @parameters
        if ($result.housekeeping.run_id) {
            $closed = Set-EsirArtifactRunState -RepoRoot $repo -RunId $result.housekeeping.run_id -Action close
            $result.housekeeping = $closed
            if ($closed.status -notin @('success') -or $closed.cleanup_status -eq 'protected-error') { $result.overall_status='failed' }
        } else { $result.overall_status='failed' }
        $result | ConvertTo-Json -Depth 60 -Compress
    }
    'register' {
        $run = Register-EsirArtifactRun -RepoRoot $repo -Workflow $data.task -EngineVersion '2.1.24' `
            -Scenario ($data.scope | ConvertTo-Json -Compress) -Reproduction ('invoke-esir-dev -Task '+$data.task+'; see plan.json for exact scope')
        $run | ConvertTo-Json -Depth 20 -Compress
    }
    'finish' {
        $run = Read-EsirArtifactRun $repo $data.run_id
        $summary = @{run_id=$run.id;workflow=$run.workflow;engine_version=$run.engine_version;repo_root=$repo;
            payload_path=$run.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status=$data.result.overall_status;result=$data.result}
        $code = if ($data.result.overall_status -eq 'failed') { 1 } else { 0 }
        $completed = Complete-EsirArtifactRun -RepoRoot $repo -RunId $run.id -ExitCode $code -Summary $summary
        $closed = Set-EsirArtifactRunState -RepoRoot $repo -RunId $run.id -Action close
        @{run_id=$closed.id;status=$closed.status;task_open=$closed.task_open;payload_path=$closed.payload_path;error=$closed.housekeeping_error} | ConvertTo-Json -Compress
    }
}
