[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [ValidateSet('en','de','fr','ja','pl','ru','zh-CN','zh-TW')][string[]]$Locales=@('en','de','fr','ja','pl','ru','zh-CN','zh-TW')
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$run=(Resolve-Path -LiteralPath $RunDirectory).Path
$managed=[IO.Path]::GetFullPath((Join-Path $repo '.factorio-qc/managed'))+[IO.Path]::DirectorySeparatorChar
if(-not $run.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)){throw 'Capture requires an owned managed QC run'}
$saved=Join-Path $run 'saves/_autosave-induction-circuit.zip'
if(-not(Test-Path -LiteralPath $saved)){throw 'Run native SaveReload acceptance first'}
$mods=Join-Path $run 'mods';$main=Join-Path $mods 'exotic-space-industries-remembrance'
$nativeRun=& python -B -c 'import ctypes,sys; b=ctypes.create_unicode_buffer(4096); n=ctypes.windll.kernel32.GetShortPathNameW(sys.argv[1],b,len(b)); assert n; print(b.value)' $run
if($LASTEXITCODE -ne 0){throw 'Could not resolve native QC path'}
$utf8=[Text.UTF8Encoding]::new($false)
$controlPath=Join-Path $main 'control.lua'
$control=[IO.File]::ReadAllText($controlPath)
$marker='-- INDUCTION_CIRCUIT_CAPTURE_BRIDGE'
if($control.Contains($marker)){throw 'Use a run without an existing capture bridge'}
$bridge=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'qc/induction-circuit/capture.lua'))
[IO.File]::AppendAllText($controlPath,"`n$marker`n$bridge",$utf8)
$baseConfig=[IO.File]::ReadAllText("$run/config.ini")
$exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
$env:SteamAppId='427520';$env:SteamGameId='427520'
$receipts=@()
try{
    foreach($locale in $Locales){
        foreach($scale in @(1.0,1.25)){
            if(Get-Process factorio -ErrorAction SilentlyContinue){
                Write-Output 'Waiting for Factorio to close before the next capture.'
                while(Get-Process factorio -ErrorAction SilentlyContinue){Start-Sleep -Milliseconds 500}
            }
            $tag=$locale+'-'+[int]($scale*100)+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
            $number=$scale.ToString([Globalization.CultureInfo]::InvariantCulture)
            [IO.File]::WriteAllText((Join-Path $main 'matrix-capture-config.lua'),('return {locale="'+$locale+'",scale='+$number+',tag="'+$tag+'"}'),$utf8)
            $config=$baseConfig.Replace('[graphics]',"[graphics]`ncache-sprite-atlas=true")+"`n[general]`nlocale=$locale`n[interface]`nui-scale-mode=manual-pixels`ncustom-ui-scale=$number`n"
            [IO.File]::WriteAllText("$run/config.ini",$config,$utf8)
            $arguments=@('--config',('"'+$nativeRun+'/config.ini"'),'--mod-directory',('"'+$nativeRun+'/mods"'),'--disable-audio','--disable-migration-window',
                '--benchmark-graphics',('"'+$saved+'"'),'--benchmark-ticks','120','--benchmark-runs','1',
                '--window-size','1280x900','--graphics-quality','medium','--video-memory-usage','low','--max-texture-size','8192')
            $client=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run/capture-$tag-stdout.txt" -RedirectStandardError "$run/capture-$tag-stderr.txt"
            $client.Handle|Out-Null;$deadline=[DateTime]::UtcNow.AddMinutes(5)
            $out=Join-Path $run 'script-output/matrix-captures'
            try{
                while(-not $client.HasExited -and [DateTime]::UtcNow -lt $deadline){
                    Start-Sleep -Milliseconds 500;$client.Refresh()
                    if((Test-Path -LiteralPath "$out/$tag.json") -and (Test-Path -LiteralPath "$out/$tag-panel.png") -and (Test-Path -LiteralPath "$out/$tag-tooltips.png")){break}
                    if(Test-Path -LiteralPath "$run/capture-$tag-stdout.txt"){
                        if(Select-String -LiteralPath "$run/capture-$tag-stdout.txt" -Pattern 'Error while running|Error Util.cpp' -Quiet){throw "Capture failed: $tag"}
                    }
                }
                if(-not(Test-Path -LiteralPath "$out/$tag-tooltips.png")){throw "Capture incomplete: $tag"}
                # The finite graphics benchmark closes normally after rendering its frames.
                # Give screenshot compression and the renderer time to finish before cleanup.
                $client.WaitForExit(30000)|Out-Null
            }finally{if(-not $client.HasExited){$client.Kill()};$client.WaitForExit()}
            Copy-Item -LiteralPath "$run/factorio-current.log" -Destination "$run/capture-$tag.log"
            $receipts+=Get-Content -LiteralPath "$out/$tag.json" -Raw -Encoding UTF8|ConvertFrom-Json
            Write-Output "CAPTURE_READY $tag"
        }
    }
}finally{
    [IO.File]::WriteAllText("$run/config.ini",$baseConfig,$utf8)
    [IO.File]::WriteAllText($controlPath,$control,$utf8)
}
[IO.File]::WriteAllText("$run/capture-receipts.json",($receipts|ConvertTo-Json -Depth 8),$utf8)
Write-Output "CAPTURES_COMPLETE $run"
