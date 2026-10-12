[CmdletBinding()]
param(
    [ValidateSet('DryRun','Stage','Run','Verify')][string]$Task='DryRun',
    [string]$RepoRoot=(Get-Location).Path,
    [string]$FullRoot,
    [string]$ApprovalReport,
    [string]$ApprovalSha256,
    [string]$ImageReview,
    [string]$ImageReviewSha256,
    [string]$Blender='C:\Program Files\Blender Foundation\Blender 5.1\blender.exe',
    [ValidateRange(1,32)][int]$ChunkSize=8,
    [ValidateRange(0,256)][int]$MaxChunks=0,
    [ValidateRange(8,1024)][int]$MinimumFreeGiB=8
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath($RepoRoot).TrimEnd('\','/')
if(-not (Test-Path -LiteralPath (Join-Path $repo '.codex/esir/asset-generators/minigun-turret/render_separated.py'))){throw 'RepoRoot is not this ESIR checkout'}
. (Join-Path $repo 'scripts/esir-housekeeping.ps1')
$validator=Join-Path $PSScriptRoot 'validate_full_render.py'
$renderer=Join-Path $repo '.codex/esir/asset-generators/minigun-turret/render_separated.py'
$launcher=$PSCommandPath
$parent=Resolve-EsirArtifactPath $repo 'output/meshy/minigun-prototypes/prototype-2/handoff-256'
if($FullRoot){
    $full=Resolve-EsirArtifactPath $repo $FullRoot
} elseif($Task -in @('Run','Verify')) {
    throw 'Run/Verify require the exact previously staged -FullRoot'
} else {
    $full=Join-Path $parent ('separated-v2-full-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6))
}
if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'separated-v2-full-*'){throw 'FullRoot must be a dedicated separated-v2-full-* directory directly under handoff-256'}
$manifestPath=Join-Path $full 'full-render-stage.json'
$state=$null
if(Test-Path -LiteralPath $full){
    if(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Existing output has no owned full-render manifest; refusing adoption'}
    $state=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if($state.schema -ne 'esir.minigun.full-render-stage.v1' -or $state.repo -ne $repo -or $state.full_root -ne $full){throw 'Staged root identity mismatch'}
    $owned=Read-EsirArtifactRun $repo $state.record.id
    if((Resolve-EsirArtifactPath $repo $owned.payload_path) -ne $full -or $owned.classification -ne 'protected-evidence'){throw 'Registered output ownership differs'}
    if((Get-FileHash -LiteralPath $validator).Hash -ne $state.validator_sha256 -or (Get-FileHash -LiteralPath $launcher).Hash -ne $state.launcher_sha256){throw 'Launcher/validator changed since Stage; preserve this run and review the changed tool before resuming'}
    foreach($entry in @(@('ApprovalReport','approval_report'),@('ApprovalSha256','approval_sha256'),@('ImageReview','image_review'),@('ImageReviewSha256','image_review_sha256'))){
        $provided=Get-Variable -Name $entry[0] -ValueOnly
        $saved=$state.($entry[1])
        if($provided -and $provided -ne $saved){throw "Resume changes the approved input: $($entry[0])"}
        Set-Variable -Name $entry[0] -Value $saved
    }
    if($Blender -ne $state.blender){throw 'Resume must use the staged Blender path'}
    if($PSBoundParameters.ContainsKey('ChunkSize') -and $ChunkSize -ne $state.chunk_size){throw 'Resume cannot change the staged chunk size'}
    $ChunkSize=$state.chunk_size
}

function Invoke-Validation([string]$Mode,[string]$Directions='',[switch]$AllowMissing) {
    $arguments=@('-B',$validator,$Mode,'--repo',$repo)
    if($FullRoot -or $state -or $Mode -eq 'seed'){$arguments+=@('--full-root',$full)}
    if($ApprovalReport){$arguments+=@('--approval',$ApprovalReport,'--approval-sha256',$ApprovalSha256)}
    if($ImageReview){$arguments+=@('--review',$ImageReview,'--review-sha256',$ImageReviewSha256)}
    if($AllowMissing){$arguments+='--allow-missing-approval'}
    if($Directions){$arguments+=@('--directions',$Directions)}
    $lines=@(& python @arguments)
    if($LASTEXITCODE -ne 0){throw 'Render/input/calibration validation failed; no journal repair was attempted'}
    return (($lines -join [Environment]::NewLine) | ConvertFrom-Json)
}

function Write-State {
    $temporary=$manifestPath+'.tmp'
    [IO.File]::WriteAllText($temporary,($state | ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $manifestPath -Force
}

function Check-FreeSpace([long]$RemainingBytes=0) {
    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
    $minimum=[long]$MinimumFreeGiB*1GB+$RemainingBytes
    if($drive.AvailableFreeSpace -lt $minimum){throw "Free-space guard: need $minimum bytes, available $($drive.AvailableFreeSpace); existing output retained"}
}

function Assert-EnginesIdle {
    if(Get-Process -Name factorio -ErrorAction SilentlyContinue){throw 'Factorio is active; the renderer must remain serial with native QC'}
    $jobs=@(Get-CimInstance Win32_Process -Filter "Name='blender.exe'" | Where-Object {$_.CommandLine -match '(?:--background|(?:^|\s)-b(?:\s|$))'})
    if($jobs.Count){throw 'A background Blender process is active; no second renderer will be started'}
}

function Append-Event($Value) {
    [IO.File]::AppendAllText((Join-Path $full 'orchestration-events.jsonl'),(($Value | ConvertTo-Json -Compress -Depth 10)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
}

if($Task -eq 'DryRun') {
    $audit=Invoke-Validation 'validate' -AllowMissing
    $audit | Add-Member -NotePropertyName proposed_full_root -NotePropertyValue $full
    $audit | Add-Member -NotePropertyName mutates_or_launches_engines -NotePropertyValue $false
    $audit | ConvertTo-Json -Depth 20
    return
}
$audit=Invoke-Validation 'validate'
if($Task -eq 'Verify') {
    $audit | ConvertTo-Json -Depth 20
    return
}
if(-not $state){
    if($Task -ne 'Stage'){throw 'Run requires a previously staged, registered output'}
    Check-FreeSpace $audit.estimated_remaining_bytes_with_margin
    $blenderPath=[IO.Path]::GetFullPath($Blender)
    if(-not (Test-Path -LiteralPath $blenderPath -PathType Leaf)){throw 'Configured Blender executable is missing'}
    $record=Register-EsirArtifactRun -RepoRoot $repo -Workflow 'minigun-full-separated-render' -Scenario 'prototype2-256-directions-28-poses-256-samples' -EngineVersion 'Blender-5.1.1' -Classification protected-evidence -PayloadPath (Get-EsirArtifactRelativePath $repo $full) -Reproduction 'Use full-render-stage.json approved hashes and invoke-full-render.ps1 -Task Run -FullRoot <registered root>'
    $state=[pscustomobject]@{
        schema='esir.minigun.full-render-stage.v1';repo=$repo;full_root=$full;record=$record;
        approval_report=(Resolve-EsirArtifactPath $repo $ApprovalReport);approval_sha256=$ApprovalSha256;
        image_review=(Resolve-EsirArtifactPath $repo $ImageReview);image_review_sha256=$ImageReviewSha256;
        launcher_sha256=(Get-FileHash -LiteralPath $launcher).Hash;validator_sha256=(Get-FileHash -LiteralPath $validator).Hash;
        blender=$blenderPath;blender_sha256=(Get-FileHash -LiteralPath $blenderPath).Hash;
        configuration_hash=$audit.approved_configuration_hash;chunk_size=$ChunkSize;status='staging';
        engine_started=$false;attempts=0;completed_chunks=0;last_error=$null;last_validation=$audit;
        staged_at=[DateTime]::UtcNow.ToString('o');rendering_completed_at=$null;production_approved=$false
    }
    Write-State
}
$lock=$null
try {
    $lock=[IO.File]::Open((Join-Path $full '.full-render.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if($Task -eq 'Stage'){
        if($state.status -notin @('staging','staged')){throw 'Rendered output must resume through Run, never Stage'}
        $state.last_validation=Invoke-Validation 'seed'
        $state.status='staged';Write-State
        Append-Event @{event='seed-verified';at=[DateTime]::UtcNow.ToString('o');passes=$state.last_validation.full.unique_passes;icons=$state.last_validation.reusable_icons.Count}
        Write-Output "STAGED ONLY; no engine started. FullRoot: $full"
        Write-Output '466 pilot PNG passes, original configuration/journal and existing icon files copied and hash-verified.'
        return
    }
    if($state.status -eq 'staging'){throw 'Seed copy is incomplete; resume Stage before Run'}
    if((Get-FileHash -LiteralPath $state.blender).Hash -ne $state.blender_sha256){throw 'Blender executable changed since Stage'}
    $audit=Invoke-Validation 'validate'
    $completedThisInvocation=0
    while(-not $audit.complete){
        if($MaxChunks -gt 0 -and $completedThisInvocation -ge $MaxChunks){
            $state.status='paused-between-chunks';$state.last_validation=$audit;Write-State
            Write-Output "CHUNK LIMIT reached; verified output retained. Resume with -Task Run -FullRoot `"$full`""
            return
        }
        Assert-EnginesIdle
        Check-FreeSpace $audit.estimated_remaining_bytes_with_margin
        # Hash approval/source inputs again immediately before each process launch.
        $audit=Invoke-Validation 'validate'
        $directions=@($audit.remaining_directions | Select-Object -First $ChunkSize)
        $csv=$directions -join ','
        $state.attempts++;$attempt=$state.attempts
        $tag=('attempt-{0:D3}-d{1:D3}-{2}' -f $attempt,[int]$directions[0],[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
        $logRoot=Join-Path $full 'logs';$null=New-Item -ItemType Directory -Force -Path $logRoot
        $arguments=@('--factory-startup','--background','--threads','8','--python-exit-code','1','--python',$renderer,'--',
            '--output',$full,'--directions',$csv,'--families','upper,full','--poses','all','--samples','256')
        if(@($arguments | Where-Object {$_ -match '["\r\n]'}).Count){throw 'Unsupported character in native process argument'}
        $quoted=($arguments | ForEach-Object {'"'+$_+'"'}) -join ' '
        $state.status='rendering';$state.engine_started=$true;Write-State
        $beforeJournal=Get-Content -LiteralPath (Join-Path $full 'render-records.jsonl') -Raw
        Append-Event @{event='chunk-start';at=[DateTime]::UtcNow.ToString('o');attempt=$attempt;directions=$directions;arguments=$arguments}
        $process=Start-Process -FilePath $state.blender -ArgumentList $quoted -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot ($tag+'.log')) -RedirectStandardError (Join-Path $logRoot ($tag+'-error.log'))
        # Keep the native handle alive. Do not Refresh(): on Windows PowerShell it
        # can discard the completed exit status and turn a successful exit into null.
        $nativeHandle=$process.Handle
        Write-Output "FULL_RENDER_CHUNK_STARTED attempt=$attempt pid=$($process.Id) directions=$csv"
        $process.WaitForExit();$code=$process.ExitCode
        $afterJournal=Get-Content -LiteralPath (Join-Path $full 'render-records.jsonl') -Raw
        if(-not $afterJournal.StartsWith($beforeJournal,[StringComparison]::Ordinal)){throw 'Renderer rewrote the existing journal prefix; refusing to continue'}
        Append-Event @{event='chunk-exit';at=[DateTime]::UtcNow.ToString('o');attempt=$attempt;exit_code=$code;directions=$directions}
        $process.Dispose()
        if($null -eq $code -or $code -ne 0){throw 'Blender failed or returned no exit status; preserve logs/journal and resume only after validation'}
        $audit=Invoke-Validation 'chunk' $csv
        $state.completed_chunks++;$completedThisInvocation++
        $state.status='chunk-verified';$state.last_validation=$audit;Write-State
        Write-Output "FULL_RENDER_CHUNK_VERIFIED attempt=$attempt unique_passes=$($audit.full.unique_passes) remaining=$($audit.remaining_passes)"
    }
    $audit=Invoke-Validation 'validate'
    if(-not $audit.complete -or $audit.full.unique_passes -ne 14850){throw 'Final all-pass audit is incomplete'}
    $state.status='rendered-verified';$state.last_validation=$audit;$state.rendering_completed_at=[DateTime]::UtcNow.ToString('o');Write-State
    $current=Read-EsirArtifactRun $repo $state.record.id
    if($current.status -eq 'running'){
        $summary=@{run_id=$current.id;workflow=$current.workflow;engine_version=$current.engine_version;repo_root=$current.repo_root;
            payload_path=$current.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';
            scope='rendered-hashed-only; compilation/native-promotion-gates remain';production_approved=$false;result=$audit}
        $done=Complete-EsirArtifactRun -RepoRoot $repo -RunId $current.id -ExitCode 0 -Summary $summary
        if($done.status -ne 'success'){throw 'Render verified, but artifact registry completion needs review'}
    }
    Write-Output "FULL_RENDER_COMPLETE 14850 verified passes; existing icons reused; production approval remains false. $full"
} catch {
    if($state -and $lock){$state.status='interrupted-or-failed';$state.last_error=$_.Exception.Message;Write-State}
    throw
} finally {
    if($lock){$lock.Dispose()}
}
