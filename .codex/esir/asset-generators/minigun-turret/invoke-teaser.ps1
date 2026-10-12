param([int]$Size=960,[int]$Samples=128,[int]$TurnFrames=120,
    [string]$OutputPath='output/meshy/minigun-prototypes/prototype-2/discord-teaser-20261011')
$ErrorActionPreference='Stop'
$repo=(Get-Location).Path
$out=[IO.Path]::GetFullPath((Join-Path $repo $OutputPath))
$cache=Join-Path $out 'render-cache'
$blender='C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Wait for the active Factorio process before rendering'}
if(Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '--background|-b(?:\s|$)'}){throw 'A background Blender job is already active'}
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$recordPath=Join-Path $out 'managed-run.json'
if(Test-Path -LiteralPath $recordPath){throw 'This invocation owns a fresh run; use the retained renderer command for a verified resume'}
$record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-discord-teaser' -Scenario '960-turntable-spin' -EngineVersion 'Blender-5.1.1' -Classification render-intermediates -PayloadPath "$OutputPath/render-cache" -Reproduction "powershell -File .codex/esir/asset-generators/minigun-turret/invoke-teaser.ps1 -Size $Size -Samples $Samples -TurnFrames $TurnFrames -OutputPath $OutputPath" -RetainedPaths @("$OutputPath/minigun-360-spin-teaser.webp","$OutputPath/minigun-teaser-poster.png","$OutputPath/teaser-report.json")
$record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8
$argsList=@('--factory-startup','--background','--threads','8','--python-exit-code','1','--python',
    (Join-Path $PSScriptRoot 'render_teaser.py'),'--','--output',$cache,'--size',"$Size",'--samples',"$Samples",'--turn-frames',"$TurnFrames")
$quoted=@($argsList | ForEach-Object {'"'+$_+'"'}) -join ' '
$process=Start-Process -FilePath $blender -ArgumentList $quoted -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $out 'render.log') -RedirectStandardError (Join-Path $out 'render-error.log')
Write-Output "TEASER_RENDER_STARTED pid=$($process.Id) output=$out"
# Cache the native handle before waiting. Refresh can discard the completed
# process state on Windows PowerShell and leave ExitCode null after a good render.
$processHandle=$process.Handle
$process.WaitForExit();$code=$process.ExitCode
if($null -eq $code){throw 'Blender exit status is unavailable; inspect the retained render log and verified frame records'}
if($code -eq 0){
    & python -B (Join-Path $PSScriptRoot 'build_teaser.py') --input $cache --output $out --limit 10000000
    $code=$LASTEXITCODE
}
$summary=@{run_id=$record.id;workflow=$record.workflow;engine_version=$record.engine_version;
    repo_root=$record.repo_root;payload_path=$record.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');
    overall_status=$(if($code -eq 0){'ok'}else{'failed'});exit_code=$code;presentation_only=$true}
$completed=Complete-EsirArtifactRun -RepoRoot $repo -RunId $record.id -ExitCode $code -Summary $summary
if($code -ne 0 -or $completed.status -ne 'success'){throw "Teaser generation incomplete; retain $out and inspect the logs"}
Set-EsirArtifactRunState -RepoRoot $repo -RunId $record.id -Action close | Out-Null
Write-Output "TEASER_COMPLETE $out"
