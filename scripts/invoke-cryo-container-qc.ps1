[CmdletBinding()]
param(
    [ValidateSet('Baseline','Roundtrip')][string]$Phase = 'Roundtrip',
    [ValidateSet(50,1000,2000)][int]$Capacity = 1000,
    [string]$SaveInput,
    [string]$SourceRoot,
    [switch]$Visual,
    [string]$ShortModPath
)
$ErrorActionPreference = 'Stop'
if ($Phase -eq 'Baseline' -and -not $SourceRoot) { throw 'Baseline requires -SourceRoot pointing to the pre-feature main mod.' }
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'esir-housekeeping.ps1')
$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$scenario = if ($Visual) { "Visual-$Capacity" } else { "$Phase-$Capacity" }
$record = Register-EsirArtifactRun -RepoRoot $repo -Workflow 'cryo-containers' -Scenario $scenario -EngineVersion '2.0.77' -Reproduction "powershell -File scripts/invoke-cryo-container-qc.ps1 -Phase $Phase -Capacity $Capacity -SaveInput '$SaveInput' -SourceRoot '$SourceRoot' -Visual:$Visual"
$run = Join-Path $repo $record.payload_path
$mods = Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$seed = Join-Path $repo '.factorio-qc\fmqc\mods-live'
if (-not (Test-Path -LiteralPath (Join-Path $seed 'mod-list.json'))) { throw 'Run ESIR qc-fast to populate the dependency seed.' }
foreach ($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip') {
    New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
}
foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
    New-Item -ItemType Junction -Path (Join-Path $mods $directory.Name) -Target $directory.FullName | Out-Null
}
$engineMods = $mods
if ($ShortModPath) {
    if (Test-Path -LiteralPath $ShortModPath) { throw 'ShortModPath must be a new junction path.' }
    $engineMods = (New-Item -ItemType Junction -Path $ShortModPath -Target $mods).FullName
}
$pack = Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $pack -Force | Out-Null
$source = if ($SourceRoot) { (Resolve-Path -LiteralPath $SourceRoot).Path } else { Join-Path $repo 'exotic-space-industries-remembrance' }
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $pack -Recurse -Force
$helper = Join-Path $mods 'zzz-esir-cryo-qc'
New-Item -ItemType Directory -Path $helper -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'qc\cryo-containers') -File | Copy-Item -Destination $helper -Force
$baseline = ($Phase -eq 'Baseline')
"return {baseline=$($baseline.ToString().ToLowerInvariant()),capacity=$Capacity,visual=$($Visual.IsPresent.ToString().ToLowerInvariant()),upgrade=$( [bool]$SaveInput -and -not $baseline | ForEach-Object { $_.ToString().ToLowerInvariant() })}" | Set-Content -LiteralPath (Join-Path $helper 'test-config.lua') -Encoding ASCII
if (-not $baseline) {
    $info = Get-Content -LiteralPath (Join-Path $helper 'info.json') -Raw | ConvertFrom-Json
    $info.version = '0.0.2'
    $info | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $helper 'info.json') -Encoding UTF8
}
$list = Get-Content -LiteralPath (Join-Path $seed 'mod-list.json') -Raw | ConvertFrom-Json
$list.mods = @($list.mods | Where-Object name -ne 'zzz-esir-cryo-qc')
foreach ($mod in $list.mods) { if ($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher') { $mod.enabled = $false } }
$list.mods += @{name='zzz-esir-cryo-qc';enabled=$true}
$list | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
"data.raw['int-setting']['ei-barrel-capacity'].default_value = $Capacity" | Set-Content -LiteralPath (Join-Path $helper 'settings-updates.lua') -Encoding ASCII
$config = Join-Path $run 'config.ini'
@('[path]','read-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data',"write-data=$run",'[other]','check-updates=false') | Set-Content -LiteralPath $config -Encoding UTF8
$fixture = Join-Path $run 'fixture.zip'
if ($SaveInput) { Copy-Item -LiteralPath $SaveInput -Destination $fixture }
else {
    & $factorio --create $fixture --config $config --mod-directory $engineMods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'create.txt') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "Fixture creation failed: $run\create.txt" }
}
if ($Visual) {
    $env:SteamAppId = '427520'
    $env:SteamGameId = '427520'
    $arguments = @('--benchmark-graphics', ('"'+$fixture+'"'), '--benchmark-ticks', '300', '--benchmark-runs', '1', '--config', ('"'+$config+'"'), '--mod-directory', ('"'+$engineMods+'"'), '--disable-audio', '--window-size', '1600x1000', '--disable-migration-window')
    $process = Start-Process -FilePath $factorio -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'visual.txt') -RedirectStandardError (Join-Path $run 'visual-error.txt')
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(180000)) { throw "Visual fixture timed out: $run" }
        $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "Visual fixture failed: $run\visual.txt" }
        foreach ($name in @('icons','crafting','factoriopedia-auric','factoriopedia-ammonia','research-aquilan')) {
            if (-not (Test-Path -LiteralPath (Join-Path $run "script-output\cryo-$name.png"))) { throw "Missing screenshot: $name" }
        }
    } finally { if (-not $process.HasExited) { Stop-Process -Id $process.Id } }
} elseif (-not $baseline) {
    & $factorio --benchmark $fixture --benchmark-ticks 600 --benchmark-runs 1 --config $config --mod-directory $engineMods --disable-audio 2>&1 | Out-File -FilePath (Join-Path $run 'benchmark.txt') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "Roundtrip fixture failed: $run\benchmark.txt" }
    if (-not (Test-Path -LiteralPath (Join-Path $run 'script-output\cryo-runtime.json'))) { throw "Missing runtime result: $run" }
}
# Remove only the staging junctions themselves before retention snapshots the payload.
if ($ShortModPath) { [IO.Directory]::Delete($engineMods) }
foreach ($directory in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*') {
    $link = Get-Item -LiteralPath (Join-Path $mods $directory.Name)
    if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $link.Target -ne $directory.FullName) {
        throw "Unexpected staging link: $($link.FullName)"
    }
    [IO.Directory]::Delete($link.FullName)
}
$result = @{overall_status='ok';phase=$Phase;capacity=$Capacity;fixture=$fixture}
$summary = @{run_id=$record.id;workflow=$record.workflow;engine_version=$record.engine_version;repo_root=$record.repo_root;payload_path=$record.payload_path;timestamp=[DateTime]::UtcNow.ToString('o');overall_status='ok';result=$result}
$completion = Complete-EsirArtifactRun -RepoRoot $repo -RunId $record.id -ExitCode 0 -Summary $summary
$summary.housekeeping = @{status=$completion.status;error=$completion.housekeeping_error}
$summary | ConvertTo-Json -Depth 6
