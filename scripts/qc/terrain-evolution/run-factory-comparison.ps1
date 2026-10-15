[CmdletBinding()]
param([int]$Ticks=3600,[int]$Runs=6,[switch]$ReuseBaseline,[string]$BeforeRoot,[string]$AfterRoot,[string]$ResultPath,[switch]$Checkpoint)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$base=Join-Path $repo '.factorio-qc/terrain-evolution'
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Close other Factorio fixtures before timing.'}
$rows=@()
foreach($label in @('factory-before','factory-after')){
    $run=if($label -eq 'factory-before' -and $BeforeRoot){[IO.Path]::GetFullPath($BeforeRoot)}elseif($label -eq 'factory-after' -and $AfterRoot){[IO.Path]::GetFullPath($AfterRoot)}else{Join-Path $base $label}
    $save=if($Checkpoint){Join-Path $run 'saves/terrain-lifecycle-checkpoint.zip'}else{Join-Path $run 'fixture.zip'}
    if(-not ($ReuseBaseline -and $label -eq 'factory-before')){
        & $exe --benchmark $save --benchmark-ticks $Ticks --benchmark-runs $Runs --config ($run+'/config.ini') --mod-directory ($run+'/mods') --disable-audio --disable-migration-window 2>&1 | Out-File ($run+'/timing.txt') -Encoding UTF8
        if($LASTEXITCODE -ne 0){throw "Benchmark failed: $run/timing.txt"}
    }
    $log=Get-Content ($run+'/timing.txt') -Raw -Encoding UTF8
    $values=@([regex]::Matches($log,'Performed \d+ updates in ([\d.]+) ms')|ForEach-Object {[double]$_.Groups[1].Value/$Ticks})
    if($values.Count -ne $Runs){throw "Expected $Runs timing samples for $label"}
    # Ignore the separately named prototype checksum; replay checksums occupy an indented line.
    $replays=@([regex]::Matches($log,'(?m)^\s+checksum: (\d+)')|ForEach-Object {$_.Groups[1].Value})
    $checksums=@($replays|Select-Object -Unique)
    if($replays.Count -ne $Runs -or $checksums.Count -ne 1){throw "Incomplete or nondeterministic benchmark replay for $label"}
    $measured=@($values|Select-Object -Skip 1|Sort-Object)
    $median=$measured[[int][math]::Floor($measured.Count/2)]
    $rows+=@{source=$label;mean_ms_per_tick=$values;median_ms_per_tick=$median;replay_checksum=$checksums[0]}
}
$regression=100*($rows[1].median_ms_per_tick/$rows[0].median_ms_per_tick-1)
$result=@{ticks=$Ticks;runs=$Runs;warmup_runs=1;regression_percent=$regression;pass=$regression -le 2;sources=$rows}
$destination=if($ResultPath){$ResultPath}else{$base+'/factory-comparison.json'}
$result|ConvertTo-Json -Depth 6 | Set-Content $destination -Encoding UTF8
$result|ConvertTo-Json -Depth 6
if(-not $result.pass){throw 'Terrain Evolution factory regression exceeded the 2% release gate.'}
