[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunName,
    [Parameter(Mandatory=$true)][string]$BaselineSource,
    [string]$SourceRoot, [switch]$Probe, [string]$Helper,
    [int]$Ticks=3600, [int]$Runs=6, [string]$SaveInput, [switch]$ForceConfig
)
$ErrorActionPreference='Stop'
if($ForceConfig -and (-not $Helper -or -not $SaveInput)){throw 'ForceConfig requires a helper and an existing fixture.'}
$repo=Split-Path -Parent $PSScriptRoot
if($RunName -notmatch '^[A-Za-z0-9_-]+$'){throw 'RunName must be a simple directory name.'}
$run=Join-Path $repo ".factorio-qc\cu\g\$RunName"
if(Test-Path -LiteralPath $run){throw 'Choose a fresh RunName to preserve evidence and avoid stale staged files.'}
$mods=Join-Path $run 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$source=if($SourceRoot){(Resolve-Path -LiteralPath $SourceRoot).Path}else{Join-Path $repo 'exotic-space-industries-remembrance'}
$baseline=(Resolve-Path -LiteralPath $BaselineSource).Path
$seed=Join-Path $repo '.factorio-qc\singularity-lance\dependency-seed'
if(-not(Test-Path -LiteralPath "$seed\mod-list.json")){$seed=Join-Path $repo '.factorio-qc\fmqc\mods-live'}
foreach($archive in Get-ChildItem -LiteralPath $seed -Filter '*.zip'){
    New-Item -ItemType HardLink -Path (Join-Path $mods $archive.Name) -Target $archive.FullName | Out-Null
}
foreach($pack in Get-ChildItem -LiteralPath $repo -Directory -Filter 'exotic-space-industries-remembrance-*'){
    New-Item -ItemType Junction -Path (Join-Path $mods $pack.Name) -Target $pack.FullName | Out-Null
}
$main=Join-Path $mods 'exotic-space-industries-remembrance'
New-Item -ItemType Directory -Path $main -Force | Out-Null
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $main -Recurse -Force
$utf8=New-Object Text.UTF8Encoding($false)
$list=Get-Content -LiteralPath "$seed\mod-list.json" -Raw | ConvertFrom-Json
foreach($mod in $list.mods){if($mod.name -match 'qc|benchmark' -or $mod.name -eq 'extinguisher'){$mod.enabled=$false}}
if($Helper){
    $helperPath=(Resolve-Path -LiteralPath $Helper).Path
    $info=Get-Content -LiteralPath "$helperPath\info.json" -Raw | ConvertFrom-Json
    Copy-Item -LiteralPath $helperPath -Destination (Join-Path $mods $info.name) -Recurse
    if($ForceConfig){
        # Replay both sources through the same configuration lifecycle.
        $version=[version]$info.version
        $info.version='{0}.{1}.{2}' -f $version.Major,$version.Minor,($version.Build+1)
        [IO.File]::WriteAllText((Join-Path $mods "$($info.name)\info.json"),($info | ConvertTo-Json -Depth 8),$utf8)
    }
    $list.mods=@($list.mods | Where-Object name -ne $info.name)+@([pscustomobject]@{name=$info.name;enabled=$true})
}
[IO.File]::WriteAllText("$mods\mod-list.json",($list | ConvertTo-Json -Depth 8),$utf8)
if($Probe){
    $exports=Get-Content -LiteralPath "$PSScriptRoot\qc\control-ups\exports.json" -Raw | ConvertFrom-Json
    New-Item -ItemType Directory -Path "$main\qc-before" -Force | Out-Null
    foreach($entry in $exports.PSObject.Properties){
        $name=$entry.Name
        foreach($side in @('before','after')){
            $path=if($side -eq 'before'){"$baseline\scripts\control\$name.lua"}else{"$main\scripts\control\$name.lua"}
            $text=Get-Content -LiteralPath $path -Raw -Encoding UTF8
            $symbol=if($name -eq 'singularity-lance'){'lance'}else{'model'}
            $text=[regex]::Replace($text,"return $symbol\s*$",($entry.Value+"`nreturn $symbol`n"))
            if($side -eq 'before'){
                # The reference copy must not register a duplicate cleanup command.
                $text=$text.Replace('if commands and commands.add_command then','if false then')
                $text=$text.Replace('commands.add_command(', '(function(...) end)(')
                $path="$main\qc-before\$name.lua"
            }
            [IO.File]::WriteAllText($path,$text,$utf8)
        }
    }
    Copy-Item -LiteralPath "$PSScriptRoot\qc\control-ups\suite.lua" -Destination "$main\qc-suite.lua"
    $names=($exports.PSObject.Properties.Name | ForEach-Object {"'$_'"}) -join ','
    $bridge=@"
do
    local before,after={},{}
    for _,name in ipairs({$names}) do
        before[name]=require('qc-before/'..name)
        after[name]=require('scripts/control/'..name)
    end
    local run=require('qc-suite')
    local previous=script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if event.tick==1 then run(before,after) end
    end)
end
"@
    [IO.File]::AppendAllText("$main\control.lua","`n$bridge",$utf8)
}
$hashes=@(Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    [ordered]@{path=$_.FullName.Substring($source.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$manifest=[ordered]@{source=$source;baseline=$baseline;probe=[bool]$Probe;helper=$Helper;force_config=[bool]$ForceConfig;save_input=$SaveInput;ticks=$Ticks;runs=$Runs;files=$hashes;
    dependencies=@(Get-ChildItem -LiteralPath $mods -File -Filter '*.zip' | ForEach-Object { @{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })}
[IO.File]::WriteAllText("$run\manifest.json",($manifest | ConvertTo-Json -Depth 8),$utf8)
$config=Join-Path $run 'config.ini'
[IO.File]::WriteAllText($config,"[path]`nread-data=__PATH__executable__/../../data`nwrite-data=$($run.Replace('\','/'))`n[other]`ncheck-updates=false`n",$utf8)
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
function Invoke-Engine([string[]]$Extra,[string]$Tag){
    $arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio')+$Extra
    $process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\$Tag-stdout.txt" -RedirectStandardError "$run\$Tag-stderr.txt"
    $process.Handle | Out-Null;$process.WaitForExit();$process.Refresh()
    Copy-Item -LiteralPath "$run\factorio-current.log" -Destination "$run\$Tag.log"
    if(($null -ne $process.ExitCode -and $process.ExitCode -ne 0) -or (Select-String -LiteralPath "$run\$Tag.log" -Pattern 'Error Util.cpp|Error while running event' -Quiet)){
        Get-Content -LiteralPath "$run\$Tag-stdout.txt" -Tail 25;throw "Factorio failed: $run\$Tag.log"
    }
}
$save=if($SaveInput){(Resolve-Path -LiteralPath $SaveInput).Path}else{Join-Path $run 'fixture.zip'}
if(-not $SaveInput){Invoke-Engine @('--create',('"'+$save+'"')) 'create'}
$manifest.fixture_path=$save
$manifest.fixture_sha256=(Get-FileHash -LiteralPath $save -Algorithm SHA256).Hash
$manifest.mod_list_sha256=(Get-FileHash -LiteralPath "$mods\mod-list.json" -Algorithm SHA256).Hash
$manifest.mod_settings_sha256=if(Test-Path -LiteralPath "$mods\mod-settings.dat"){(Get-FileHash -LiteralPath "$mods\mod-settings.dat" -Algorithm SHA256).Hash}else{$null}
if($Helper){
    $stagedHelper=Join-Path $mods $info.name
    $manifest.helper_version=$info.version
    $manifest.helper_files=@(Get-ChildItem -LiteralPath $stagedHelper -Recurse -File | ForEach-Object {
        @{path=$_.FullName.Substring($stagedHelper.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
}
[IO.File]::WriteAllText("$run\manifest.json",($manifest | ConvertTo-Json -Depth 8),$utf8)
Invoke-Engine @('--benchmark',('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs',"$Runs") 'benchmark'
if($Probe -and -not(Select-String -LiteralPath "$run\benchmark.log" -Pattern 'CONTROL_UPS ALL_COMPLETE' -Quiet)){throw 'Differential probes did not finish.'}
Write-Output $run
