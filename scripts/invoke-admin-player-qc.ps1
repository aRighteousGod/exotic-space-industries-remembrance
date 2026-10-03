[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunName,
    [Parameter(Mandatory=$true)][string]$SaveInput,
    [ValidateSet('benchmark','client','server')][string]$Mode='benchmark',
    [ValidateSet('all','save-jail','save-god')][string]$Suite='all',
    [ValidateSet('online','elapsed')][string]$TimerMode='online',
    [string]$PlayerSource,
    [string]$FixtureDirectory,
    [string]$LibraryDirectory,
    [int]$Ticks=300,
    [int]$ServerPort=34327,
    [switch]$CaptureHud,
    [string]$RepoRoot=(Get-Location).Path
)
$ErrorActionPreference='Stop'
if($CaptureHud -and ($Mode -ne 'client' -or $Suite -ne 'save-jail')){throw 'CaptureHud requires Mode=client and Suite=save-jail.'}
$repo=(Resolve-Path -LiteralPath $RepoRoot).Path
if($RunName -notmatch '^[A-Za-z0-9_-]+$'){throw 'RunName must be a simple directory name.'}
if(-not $PlayerSource){$PlayerSource=Join-Path $repo 'exotic-space-industries-remembrance/scripts/control/admin/players.lua'}
if(-not $FixtureDirectory){$FixtureDirectory=Join-Path $repo 'scripts/qc/admin-tools-player/player-fixture'}
if(-not $LibraryDirectory){$LibraryDirectory=Join-Path $repo 'exotic-space-industries-remembrance/lib'}
$source=(Resolve-Path -LiteralPath $PlayerSource).Path
$fixture=(Resolve-Path -LiteralPath $FixtureDirectory).Path
$save=(Resolve-Path -LiteralPath $SaveInput).Path
$run=Join-Path $repo ".factorio-qc/admin-players/$RunName"
if(Test-Path -LiteralPath $run){throw 'Use a fresh RunName to preserve existing evidence.'}
$mods=Join-Path $run 'mods'
$helper=Join-Path $mods 'esir-admin-player-qc'
$library=Join-Path $helper 'lib'
New-Item -ItemType Directory -Path $library -Force | Out-Null
Get-ChildItem -LiteralPath $fixture | Copy-Item -Destination $helper -Recurse -Force
Copy-Item -LiteralPath $source -Destination (Join-Path $helper 'players.lua')
foreach($name in @('lib.lua','runtime-scheduler.lua','camera-window.lua')){
    Copy-Item -LiteralPath (Join-Path $LibraryDirectory $name) -Destination $library
}
$utf8=New-Object Text.UTF8Encoding($false)
$list=@{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$true},@{name='quality';enabled=$true},@{name='elevated-rails';enabled=$true},@{name='esir-admin-player-qc';enabled=$true})}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($list|ConvertTo-Json -Depth 5),$utf8)
[IO.File]::WriteAllText((Join-Path $helper 'fixture-config.lua'),("return {suite='$Suite',timer_mode='$TimerMode',capture_hud="+$CaptureHud.IsPresent.ToString().ToLowerInvariant()+"}")+[Environment]::NewLine,$utf8)
$config=Join-Path $run 'config.ini'
$configText="[path]"+[Environment]::NewLine+"read-data=__PATH__executable__/../../data"+[Environment]::NewLine+"write-data="+$run.Replace('\','/')+[Environment]::NewLine+"[other]"+[Environment]::NewLine+"check-updates=false"+[Environment]::NewLine
if($CaptureHud){$configText+="[interface]`nui-scale-mode=manual-pixels`ncustom-ui-scale=1.5`n[graphics]`nfull-screen=false`n"}
[IO.File]::WriteAllText($config,$configText,$utf8)
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$arguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--disable-audio','--disable-migration-window')
if($Mode -eq 'benchmark'){
    $arguments+=@('--benchmark',('"'+$save+'"'),'--benchmark-ticks',"$Ticks",'--benchmark-runs','1')
}elseif($Mode -eq 'client'){
    New-Item -ItemType Directory -Path (Join-Path $run 'saves') -Force | Out-Null
    $env:SteamAppId='427520';$env:SteamGameId='427520'
    $arguments+=@('--load-game',('"'+$save+'"'),'--window-size','1280x720')
}else{
    $options=Get-Content -LiteralPath 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\server-settings.example.json' -Raw | ConvertFrom-Json
    $options.name='Private admin player fixture'
    $options.visibility.public=$false
    $options.visibility.lan=$false
    $options.require_user_verification=$false
    $options.auto_pause=$false
    $serverSettings=Join-Path $run 'server-settings.json'
    [IO.File]::WriteAllText($serverSettings,($options|ConvertTo-Json -Depth 8),$utf8)
    $arguments+=@('--start-server',('"'+$save+'"'),'--server-settings',('"'+$serverSettings+'"'),'--port',"$ServerPort")
}
$manifest=@{source=$source;source_sha256=(Get-FileHash -LiteralPath (Join-Path $helper 'players.lua')).Hash;save=$save;save_sha256=(Get-FileHash -LiteralPath $save).Hash;mode=$Mode;suite=$Suite;timer=$TimerMode;ticks=$Ticks;started=(Get-Date).ToString('o');
    staged_files=@(Get-ChildItem -LiteralPath $helper -Recurse -File | ForEach-Object {@{path=$_.FullName.Substring($helper.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}})}
[IO.File]::WriteAllText((Join-Path $run 'manifest.json'),($manifest|ConvertTo-Json -Depth 7),$utf8)
if($CaptureHud -and -not ('ESIRJailHudWindow' -as [type])){
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ESIRJailHudWindow {
    public delegate bool WindowCallback(IntPtr hwnd,IntPtr arg);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left,top,right,bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(WindowCallback callback,IntPtr arg);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int width,int height,uint flags);
    public static bool Resize(int processId) {
        bool done=false;
        IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
        try { EnumWindows((hwnd,arg)=>{
            uint pid;GetWindowThreadProcessId(hwnd,out pid);
            if(pid!=processId)return true;
            Rect old;GetClientRect(hwnd,out old);
            if(old.right<400 || old.bottom<300)return true;
            Rect outer;GetWindowRect(hwnd,out outer);
            done=SetWindowPos(hwnd,IntPtr.Zero,0,0,outer.right-outer.left-old.right+1280,outer.bottom-outer.top-old.bottom+720,0x0010|0x0004|0x0002);
            return false;
        },IntPtr.Zero); } finally {SetThreadDpiAwarenessContext(previous);}
        return done;
    }
}
'@
}
$hudResized=$false
$process=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'stdout.txt') -RedirectStandardError (Join-Path $run 'stderr.txt')
$process.Handle|Out-Null
$deadline=(Get-Date).AddMinutes(5)
$log=Join-Path $run 'factorio-current.log'
$completed=$false
$saveCreated=$false
Add-Type -AssemblyName System.IO.Compression.FileSystem
try{
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if($CaptureHud -and -not $hudResized){$hudResized=[ESIRJailHudWindow]::Resize($process.Id)}
        if(Test-Path -LiteralPath $log){
            if(Select-String -LiteralPath $log -Pattern 'Error while running event|Error Util.cpp|Error AtlasBuilder|Hosting multiplayer game failed' -Quiet){throw "Engine fixture failed: $log"}
            if(Select-String -LiteralPath $log -Pattern 'ADMIN_PLAYER_QC ALL_COMPLETE' -Quiet){$completed=$true;if($Mode -ne 'benchmark'){break}}
            if($Mode -eq 'client' -and $Suite -ne 'all'){
                $saveName=if($Suite -eq 'save-god'){'_autosave-admin-player-god.zip'}else{'_autosave-admin-player-jail.zip'}
                $saved=Join-Path $run ('saves/'+$saveName)
                if(Test-Path -LiteralPath $saved){
                    try{$zip=[IO.Compression.ZipFile]::OpenRead($saved);$zip.Dispose();$saveCreated=$true;break}catch{}
                }
            }
        }
        Start-Sleep -Milliseconds 250
        $process.Refresh()
    }
    if(Test-Path -LiteralPath $log){if(Select-String -LiteralPath $log -Pattern 'ADMIN_PLAYER_QC ALL_COMPLETE' -Quiet){$completed=$true}}
    if(Select-String -LiteralPath (Join-Path $run 'stdout.txt') -Pattern 'Error while running event|ADMIN_PLAYER_QC FAILED' -Quiet){throw "Engine assertion failed: $run/stdout.txt"}
    if($Mode -eq 'client' -and $Suite -ne 'all'){
        if(-not $saveCreated){throw "Genuine client autosave missing: $run"}
    }elseif(-not $completed){throw "Completion marker missing: $run"}
    if($CaptureHud){
        $hud=Get-Content -LiteralPath (Join-Path $run 'script-output/jail-hud.json') -Raw | ConvertFrom-Json
        if($hud.resolution.width -ne 1280 -or $hud.resolution.height -ne 720 -or [Math]::Abs($hud.scale-1.5) -gt 0.001){throw 'Jail HUD native viewport differs from 1280x720/1.5.'}
        if(-not(Test-Path -LiteralPath (Join-Path $run 'script-output/jail-hud.png'))){throw 'Jail HUD screenshot missing.'}
    }
    if($Mode -eq 'benchmark' -and $process.HasExited -and $process.ExitCode -ne 0){throw "Engine exit $($process.ExitCode): $run"}
}finally{
    if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}
    if(Test-Path -LiteralPath $log){Copy-Item -LiteralPath $log -Destination (Join-Path $run 'result.log')}
}
Write-Output $run
