# Host-only integration: real save resolver/staging adapter, stubbed storage and engine discovery.
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $repo 'scripts/esir-dev-lib.ps1')
$fixtureRoot=Join-Path $repo ('temp/native-helpers-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'helper')
try {
    [IO.File]::WriteAllText((Join-Path $fixtureRoot 'native.zip'),'host-only placeholder')
    [IO.File]::WriteAllText((Join-Path $fixtureRoot 'other.zip'),'host-only placeholder')
    $catalogPath=Join-Path $fixtureRoot 'save-catalog.json'
    Write-EsirJson -Path $catalogPath -Data @{entries=@(@{id='native';path='native.zip';helper_mods=@(@{name='esir-qc-host-helper';asset_path='helper';auto_stage_for=@('runtime-benchmark');notes='host fixture'})})}
    $infoPath=Join-Path $fixtureRoot 'helper/info.json'
    Write-EsirJson -Path $infoPath -Data @{name='esir-qc-host-helper';version='0.0.1';factorio_version='2.1'}
    $paths=[pscustomobject]@{repo_root=$fixtureRoot;save_catalog_path=$catalogPath}
    function Select-EsirEngineSourceMods { param($Context) return [pscustomobject]@{included=@();excluded=@();engine_target='2.1'} }
    function Add-FactorioQCNote { param($Result,$Message) }
    function Invoke-EsirQcStorage {
        param($RepoRoot,$Action,$Data)
        if($Action -ne 'stage'){throw "Unexpected storage operation: $Action"}
        $script:captured=$Data
        return [pscustomobject]@{store_root=$fixtureRoot;mod_view_root=$fixtureRoot;scratch_root=$fixtureRoot;evidence_root=$fixtureRoot}
    }
    $checks=0
    foreach($task in @('qc-runtime','qc-preview','qc-full')) {
        foreach($byPath in @($false,$true)) {
            $args=@{Paths=$paths;TaskName=$task}
            if($byPath){$args.SavePath=Join-Path $fixtureRoot 'native.zip'}else{$args.SaveId='native'}
            $selection=Resolve-EsirSaveSelection @args
            if($selection.id -ne 'native'){throw 'Catalogue identity lost'}
            $summary=Get-EsirSaveHelperSummary -Paths $paths -SaveSelection $selection -TaskName $task -AllowAutoStage
            $context=[pscustomobject]@{repo_root=$fixtureRoot;qc_run_id='host-only';source_mode='read-only';is_esir=$false;run_mod_directory='';
                dependency_packages=@();qc_mod_list=@{mods=@(@{name='base';enabled=$true},@{name='esir-qc-host-helper';enabled=$false})}}
            Set-EsirRequiredSaveHelpers -Paths $paths -Context $context -HelperSummary $summary
            $script:captured=$null
            $null=Sync-FactorioRunMods -Context $context -Result @{}
            if(@($script:captured.sources).Count -ne 1 -or $script:captured.sources[0].mode -ne 'private-mutable'){throw 'Required helper was not privately staged'}
            $enabled=@($script:captured.mod_list.mods|Where-Object name -eq 'esir-qc-host-helper')
            if($enabled.Count -ne 1 -or $enabled[0].enabled -ne $true){throw 'Required helper was not enabled exactly once'}
            $checks++
        }
    }
    $unknown=Resolve-EsirSaveSelection -Paths $paths -TaskName qc-runtime -SavePath (Join-Path $fixtureRoot 'other.zip')
    if($null -ne (Get-EsirSaveHelperSummary -Paths $paths -SaveSelection $unknown -TaskName qc-runtime -AllowAutoStage)){throw 'Uncatalogued save gained a helper'}
    foreach($family in @('2.0','missing')) {
        if($family -eq 'missing'){Remove-Item -LiteralPath $infoPath}else{Write-EsirJson -Path $infoPath -Data @{name='esir-qc-host-helper';factorio_version=$family}}
        $script:captured=$null;$rejected=$false
        try {$null=Sync-FactorioRunMods -Context $context -Result @{}}catch{$rejected=$true}
        if(-not $rejected -or $null -ne $script:captured){throw 'Invalid helper reached storage staging'}
        $checks++
    }
    $catalog=Read-EsirJson (Join-Path $repo '.codex/esir/test-suites.json')
    $rows=@()
    foreach($suite in @($catalog.suites|Where-Object core -eq $true)) {
        foreach($profile in $suite.profiles) {
            $cases=@($suite.cases|Where-Object { $_.PSObject.Properties.Name -notcontains 'profiles' -or $profile.id -in $_.profiles })
            $rows+=@{suite=$suite.id;profile=$profile.id;overall_status='ok';phases=@($cases|ForEach-Object{@{phase=$_.id;passed=$true}})}
        }
    }
    $aggregate=[pscustomobject]@{results=@($rows|ForEach-Object{[pscustomobject]$_})}
    $realPaths=[pscustomobject]@{repo_root=$repo}
    Assert-EsirNativeCoreAggregate -Paths $realPaths -Aggregate $aggregate
    foreach($failure in @('missing-row','missing-phase','child-failure')) {
        $broken=$aggregate|ConvertTo-Json -Depth 10|ConvertFrom-Json
        if($failure -eq 'missing-row'){$broken.results=@($broken.results|Select-Object -Skip 1)}
        elseif($failure -eq 'missing-phase'){$broken.results[0].phases=@()}
        else{$broken.results[0].overall_status='failed'}
        $rejected=$false
        try{Assert-EsirNativeCoreAggregate -Paths $realPaths -Aggregate $broken}catch{$rejected=$true}
        if(-not $rejected){throw "Parent accepted $failure"};$checks++
    }
    @{passed=$true;checks=$checks+1;engine_launched=$false}|ConvertTo-Json -Compress
} finally {
    $resolved=[IO.Path]::GetFullPath($fixtureRoot)
    $expected=[IO.Path]::GetFullPath((Join-Path $repo 'temp'))+[IO.Path]::DirectorySeparatorChar
    if(-not $resolved.StartsWith($expected,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
