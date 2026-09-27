[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BaselineRun,
    [Parameter(Mandatory=$true)][string]$CandidateRun,
    [int]$Ticks=3600,[int]$MeasuredPairs=5
)
$ErrorActionPreference='Stop'
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$profiles=@{}
foreach($side in @('baseline','candidate')){
    $path=if($side -eq 'baseline'){$BaselineRun}else{$CandidateRun}
    $path=(Resolve-Path -LiteralPath $path).Path
    $manifest=Get-Content -LiteralPath "$path/manifest.json" -Raw | ConvertFrom-Json
    if($manifest.bridge -or $manifest.probe -or $manifest.helper){throw 'Timing lane must have no instrumentation or helper.'}
    $profiles[$side]=@{path=$path;manifest=$manifest}
}
foreach($field in @('fixture_sha256','mod_list_sha256','mod_settings_sha256')){
    if($profiles.baseline.manifest.$field -ne $profiles.candidate.manifest.$field){throw "Unmatched $field"}
}
if(Get-Process factorio -ErrorAction SilentlyContinue){throw 'Another Factorio process is running.'}
$results=@()
for($pair=0;$pair -le $MeasuredPairs;$pair++){
    $order=if($pair%2 -eq 0){@('baseline','candidate')}else{@('candidate','baseline')}
    foreach($side in $order){
        $profile=$profiles[$side];$path=$profile.path;$save=$profile.manifest.fixture_path
        if((Get-FileHash -LiteralPath $save).Hash -ne $profile.manifest.fixture_sha256){throw 'Input save changed.'}
        $tag="pair-$pair"
        if(Test-Path -LiteralPath "$path/$tag.log"){throw 'Existing timing evidence; choose fresh profiles.'}
        $arguments=@('--config',('"'+$path+'/config.ini"'),'--mod-directory',('"'+$path+'/mods"'),'--disable-audio','--benchmark',('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1')
        $process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$path/$tag-stdout.txt" -RedirectStandardError "$path/$tag-stderr.txt"
        $process.Handle|Out-Null;$process.WaitForExit();$process.Refresh()
        Copy-Item -LiteralPath "$path/factorio-current.log" -Destination "$path/$tag.log"
        $content=Get-Content -LiteralPath "$path/$tag-stdout.txt" -Raw
        if($process.ExitCode -ne 0 -or $content -match 'Error while running event|Error Util.cpp'){throw "Engine failed: $path/$tag.log"}
        $match=[regex]::Match($content,'Performed (\d+) updates in ([\d.]+) ms')
        if(-not $match.Success -or [int]$match.Groups[1].Value -ne $Ticks){throw "Missing timing: $path/$tag.log"}
        $ms=[double]::Parse($match.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture)/$Ticks
        $checksum=[regex]::Match($content,'(?m)^\s*checksum: (\d+)\s*$').Groups[1].Value
        $results+=@{pair=$pair;warmup=($pair -eq 0);side=$side;ms_per_tick=$ms;checksum=$checksum}
        $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$CandidateRun/alternating-results.json" -Encoding UTF8
        Write-Output "$tag $side $ms ms/tick checksum=$checksum"
    }
}
