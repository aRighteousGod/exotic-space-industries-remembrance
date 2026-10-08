[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BaselineRun,
    [Parameter(Mandatory=$true)][string]$CandidateRun,[ValidateRange(1,10)][int]$MeasuredPairs=3)
$ErrorActionPreference='Stop'
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$paths=@{before=(Resolve-Path -LiteralPath $BaselineRun).Path;after=(Resolve-Path -LiteralPath $CandidateRun).Path}
if((Get-FileHash -LiteralPath "$($paths.before)/fixture.zip").Hash -ne (Get-FileHash -LiteralPath "$($paths.after)/fixture.zip").Hash){throw 'Mismatched seed saves'}
foreach($relative in @('mods/mod-list.json','mods/zzz-esir-anisetron-qc/options.lua','mods/zzz-esir-anisetron-qc/control.lua','mods/zzz-esir-anisetron-qc/test-config.lua')){
    if((Get-FileHash -LiteralPath (Join-Path $paths.before $relative)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $paths.after $relative)).Hash){throw "Mismatched $relative"}
}
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Run only one Factorio process at a time'}
foreach($pair in 0..$MeasuredPairs){
    $sides=if($pair%2 -eq 0){@('before','after')}else{@('after','before')}
    foreach($side in $sides){
        $path=$paths[$side];$out=Join-Path $path "pair-$pair"
        if(Test-Path -LiteralPath $out){throw 'Existing evidence; choose fresh profile folders'}
        New-Item -ItemType Directory -Path "$out/script-output" -Force | Out-Null
        & $exe --benchmark "$path/fixture.zip" --benchmark-ticks 5401 --benchmark-runs 1 --config "$path/config.ini" --mod-directory "$path/mods" --disable-audio --disable-migration-window 2>&1 | Out-File -FilePath "$out/benchmark.txt" -Encoding utf8
        if($LASTEXITCODE -ne 0){throw "Benchmark failed: $out/benchmark.txt"}
        Copy-Item -LiteralPath "$path/script-output/anisetron-qc.json" -Destination "$out/script-output/anisetron-qc.json"
        Write-Output "Completed pair $pair $side (pair 0 is warmup)"
    }
    python -B "$PSScriptRoot/compare.py" "$($paths.before)/pair-$pair" "$($paths.after)/pair-$pair" --output "$($paths.after)/pair-$pair/parity.json" | Out-File -FilePath "$($paths.after)/pair-$pair/summary.txt" -Encoding utf8
    if($LASTEXITCODE -ne 0){throw "Parity failed for pair $pair"}
}
