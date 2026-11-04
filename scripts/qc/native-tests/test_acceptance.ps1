$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$checks=0
function Check($Value,$Name) { if(-not $Value){throw $Name};$script:checks++ }
function Reject($Action,$Name) { $rejected=$false;try{& $Action}catch{$rejected=$true};Check $rejected $Name }
$policy=Get-EsirGaiaResourcePolicy $repo
$lines=@($policy.resources|ForEach-Object {"${_}: totalEntityCount=1, totalRichness=5"})
$measurements=Read-EsirResourceQuantities -Lines ($lines+$lines) -Targets $policy.resources
Check ($measurements.Count -eq 6) 'Deduplicated complete resource quantities'
Reject {Read-EsirResourceQuantities -Lines ($lines+($lines[0].Replace('Count=1','Count=2'))) -Targets $policy.resources} 'Conflicting quantities rejected'
$runs=@($policy.seeds|ForEach-Object {[pscustomobject]@{id="gaia-seed-$_";seed=$_;preview_size=4096;status='ok';resources=@($policy.resources|ForEach-Object {@{name=$_}})}})
$controls=@($policy.resources|ForEach-Object {[pscustomobject]@{id="gaia-control-$_";disabled_resource=$_;seed=1000;preview_size=2048;status='ok';resources=@($policy.resources|ForEach-Object {@{name=$_}})}})
Assert-EsirGaiaPreviewMatrix -Runs $runs -ControlProbes $controls -Seeds $policy.seeds -Targets $policy.resources -Size 4096
$checks++
Reject {Assert-EsirGaiaPreviewMatrix -Runs @($runs|Select-Object -Skip 1) -ControlProbes $controls -Seeds $policy.seeds -Targets $policy.resources -Size 4096} 'Omitted seed rejected'
Reject {Assert-EsirGaiaPreviewMatrix -Runs $runs -ControlProbes @($controls[0],$controls[0],$controls[2],$controls[3],$controls[4],$controls[5]) -Seeds $policy.seeds -Targets $policy.resources -Size 4096} 'Duplicate control rejected'
$aggregate=@{task='qc-test';overall_status='ok';source_fingerprint=@{sha256='host'};source_errors=@();results=@(@{suite='gaia-resources';profile='default';overall_status='ok';phases=@(@{phase='candidate';passed=$true;assertions=1})})}|ConvertTo-Json -Depth 8|ConvertFrom-Json
Assert-EsirGaiaAggregate -Aggregate $aggregate -SourceHash host
$checks++
foreach($defect in @('child-failure','missing-phase','empty-assertions','wrong-source')) {
    $broken=$aggregate|ConvertTo-Json -Depth 8|ConvertFrom-Json
    switch($defect) {
        'child-failure' {$broken.results[0].overall_status='failed'}
        'missing-phase' {$broken.results[0].phases=@()}
        'empty-assertions' {$broken.results[0].phases[0].assertions=0}
        'wrong-source' {$broken.source_fingerprint.sha256='different'}
    }
    Reject {Assert-EsirGaiaAggregate -Aggregate $broken -SourceHash host} $defect
}
$context=[pscustomobject]@{preview_companion={param($Context,$Seed,$Planet,$Save,$Strict) @{seed=$Seed;planet=$Planet;save=$Save;strict=[bool]$Strict}}}
$hook=Invoke-FactorioPreviewQC -Context $context -Seed 42 -Planet nauvis -Save host.zip -Strict
Check ($hook.seed -eq 42 -and $hook.planet -eq 'nauvis' -and $hook.save -eq 'host.zip' -and $hook.strict) 'Repository preview hook preserves arguments'
Check ((Resolve-EsirPreviewScope -Mode preview) -eq 'gaia-acceptance') 'Bare preview retains Gaia acceptance'
Check ((Resolve-EsirPreviewScope -Mode preview -Planet nauvis) -eq 'requested') 'Explicit non-Gaia preview stays requested'
Check ((Resolve-EsirPreviewScope -Mode preview -Seed 0) -eq 'requested') 'Seed zero is explicit'
Check ((Resolve-EsirPreviewScope -Mode full -PreviewScope requested -Planet nauvis) -eq 'gaia-acceptance') 'Full cannot weaken fixed acceptance'
Check ((Resolve-EsirPreviewScope -Mode preview -PreviewScope gaia-acceptance -Planet nauvis) -eq 'gaia-acceptance') 'Explicit acceptance wins'
# Exercise the companion with isolated process/row boundaries; no engine launch.
function Get-EsirCommonTestInputs { param($Paths) @{sha256='scope-test'} }
function Sync-FactorioRunMods { param($Context,$Result) }
function Get-PreviewTargets { param($Context,$Planet) @('iron-ore') }
$script:previewRows=@();$script:nativeChildren=0;$script:failPreview=$false;$script:failChild=$false
function Invoke-EsirResourcePreviewRow {
    param($Context,$Id,$Planet,$Seed,$Size,$Targets,[switch]$RequirePresence)
    $script:previewRows+=@{id=$Id;planet=$Planet;seed=$Seed;size=$Size;require_presence=[bool]$RequirePresence}
    @{status=$(if($script:failPreview){'failed'}else{'ok'});errors=@($(if($script:failPreview){'controlled preview failure'}));warnings=@();preview='fixture.png'}
}
function Invoke-NativeProcess {
    param($FilePath,$Arguments)
    $script:nativeChildren++
    $child=@{task='qc-test';overall_status='ok';source_fingerprint=@{sha256='scope-test'};source_errors=@();results=@(@{suite='gaia-resources';profile='default';overall_status='ok';phases=@(@{phase='candidate';passed=$true;assertions=1})})}
    if($script:failChild){$child.results=@()}
    @{exit_code=0;output=@($child|ConvertTo-Json -Depth 10 -Compress)}
}
$context=[pscustomobject]@{repo_root=$repo;python_exe='unused';factorio_exe='unused';preview_scope='requested'}
$requested=Invoke-EsirGaiaPreviewCompanion -Context $context -Planet nauvis -Seed 42 -Strict
Check ($requested.status -eq 'ok' -and $script:nativeChildren -eq 0 -and $script:previewRows.Count -eq 1 -and $script:previewRows[0].planet -eq 'nauvis') 'Requested preview has no Gaia/native child'
$context.preview_scope='gaia-acceptance';$script:previewRows=@()
$accepted=Invoke-EsirGaiaPreviewCompanion -Context $context -Strict
Check ($accepted.status -eq 'ok' -and $script:nativeChildren -eq 1 -and $script:previewRows.Count -eq 1 -and $script:previewRows[0].size -eq 4096 -and $script:previewRows[0].require_presence) 'Fixed Gaia preview and native exactly once'
$script:failChild=$true
$badChild=Invoke-EsirGaiaPreviewCompanion -Context $context -Strict
Check ($badChild.status -eq 'failed') 'Incomplete child cannot pass preview'
$script:failChild=$false;$script:failPreview=$true;$context.preview_scope='requested'
$badPreview=Invoke-EsirGaiaPreviewCompanion -Context $context -Planet nauvis -Strict
Check ($badPreview.status -eq 'failed') 'Requested preview failure propagates'
@{passed=$true;checks=$checks;engine_launched=$false}|ConvertTo-Json -Compress
