[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$RunName,
    [Parameter(Mandatory=$true)][string]$SaveInput,
    [ValidatePattern('^[1-9][0-9]{2,4}x[1-9][0-9]{2,4}$')][string]$Resolution='1280x720',
    [ValidateRange(0.25,5.0)][double]$Scale=1,
    [string]$GuiSource,[string]$CameraSource,[string]$LocaleSource,[string]$FixtureDirectory,
    [string]$RepoRoot
)
$ErrorActionPreference='Stop'
if(-not $RepoRoot){$RepoRoot=Split-Path -Parent $PSScriptRoot}
$repo=(Resolve-Path -LiteralPath $RepoRoot).Path
$pack=Join-Path $repo 'exotic-space-industries-remembrance'
if(-not $GuiSource){$GuiSource=Join-Path $pack 'scripts/control/admin/gui.lua'}
if(-not $CameraSource){$CameraSource=Join-Path $pack 'lib/camera-window.lua'}
if(-not $LocaleSource){$LocaleSource=Join-Path $pack 'locale/en/admin-tools.cfg'}
if(-not $FixtureDirectory){$FixtureDirectory=Join-Path $repo 'scripts/qc/admin-tools-responsive'}
$save=(Resolve-Path -LiteralPath $SaveInput).Path
$fixture=(Resolve-Path -LiteralPath $FixtureDirectory).Path
$run=Join-Path $repo ('.factorio-qc/admin-responsive-'+$RunName)
if(Test-Path -LiteralPath $run){throw 'Fresh run name required'}
$mods=Join-Path $run 'mods'
$helper=Join-Path $mods 'esir-admin-responsive-qc'
foreach($folder in @('lib','scripts/control/admin','prototypes','locale/en')){New-Item -ItemType Directory -Path (Join-Path $helper $folder) -Force | Out-Null}
Get-ChildItem -LiteralPath $fixture -File | Copy-Item -Destination $helper
Copy-Item -LiteralPath $GuiSource -Destination (Join-Path $helper 'scripts/control/admin/gui.lua')
Copy-Item -LiteralPath $CameraSource -Destination (Join-Path $helper 'lib/camera-window.lua')
foreach($libraryName in @('lib.lua','runtime-scheduler.lua','admin-tools-config.lua')){Copy-Item -LiteralPath (Join-Path $pack ('lib/'+$libraryName)) -Destination (Join-Path $helper 'lib')}
Copy-Item -LiteralPath (Join-Path $pack 'scripts/control/admin/common.lua') -Destination (Join-Path $helper 'scripts/control/admin')
Copy-Item -LiteralPath (Join-Path $pack 'prototypes/admin-tools.lua') -Destination (Join-Path $helper 'prototypes')
Copy-Item -LiteralPath $LocaleSource -Destination (Join-Path $helper 'locale/en/admin-tools.cfg')
$enc=[Text.UTF8Encoding]::new($false)
$list=@{mods=@(@{name='base';enabled=$true},@{name='space-age';enabled=$true},@{name='quality';enabled=$true},@{name='elevated-rails';enabled=$true},@{name='esir-admin-responsive-qc';enabled=$true})}
[IO.File]::WriteAllText((Join-Path $mods 'mod-list.json'),($list|ConvertTo-Json -Depth 4),$enc)
$config=Join-Path $run 'config.ini'
$scaleText=$Scale.ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)
[IO.File]::WriteAllText($config,"[path]`nread-data=__PATH__executable__/../../data`nwrite-data="+$run.Replace('\','/')+"`n[other]`ncheck-updates=false`n[interface]`nui-scale-mode=manual-pixels`ncustom-ui-scale=$scaleText`n[graphics]`nfull-screen=false`n",$enc)
$exe='C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'
$env:SteamAppId='427520';$env:SteamGameId='427520'
$factorioArguments=@('--config',('"'+$config+'"'),'--mod-directory',('"'+$mods+'"'),'--load-game',('"'+$save+'"'),'--disable-audio','--disable-migration-window','--window-size',$Resolution)
$manifest=@{save=$save;save_sha256=(Get-FileHash -LiteralPath $save).Hash;requested_resolution=$Resolution;requested_scale=$Scale;started=(Get-Date).ToString('o');
    staged_files=@(Get-ChildItem -LiteralPath $helper -Recurse -File | ForEach-Object {@{path=$_.FullName.Substring($helper.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}})}
[IO.File]::WriteAllText((Join-Path $run 'manifest.json'),($manifest|ConvertTo-Json -Depth 6),$enc)
if(-not ('ESIRResponsiveWindow' -as [type])){Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ESIRResponsiveWindow {
    public delegate bool WindowCallback(IntPtr hwnd, IntPtr arg);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left,top,right,bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(WindowCallback callback,IntPtr arg);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int width,int height,uint flags);
    public static bool Resize(int processId,int width,int height) {
        bool done=false;
        IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
        try {
        EnumWindows((hwnd,arg)=>{
            uint pid;GetWindowThreadProcessId(hwnd,out pid);
            if(pid!=processId)return true;
            Rect old;GetClientRect(hwnd,out old);
            if(old.right<400 || old.bottom<300)return true;
            Rect outer;GetWindowRect(hwnd,out outer);
            done=SetWindowPos(hwnd,IntPtr.Zero,0,0,outer.right-outer.left-old.right+width,outer.bottom-outer.top-old.bottom+height,0x0010|0x0004|0x0002);
            return false;
        },IntPtr.Zero);
        } finally {SetThreadDpiAwarenessContext(previous);}
        return done;
    }
}
'@
}
$dimensions=$Resolution.Split('x');$resized=$false
$process=Start-Process -FilePath $exe -ArgumentList $factorioArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'stdout.txt') -RedirectStandardError (Join-Path $run 'stderr.txt')
$process.Handle|Out-Null
$deadline=(Get-Date).AddMinutes(3)
$completed=$false
try{
    while(-not $process.HasExited -and (Get-Date) -lt $deadline){
        if(-not $resized){$resized=[ESIRResponsiveWindow]::Resize($process.Id,[int]$dimensions[0],[int]$dimensions[1])}
        $log=Join-Path $run 'factorio-current.log'
        if(Test-Path -LiteralPath $log){
            if(Select-String -LiteralPath $log -Pattern 'Error while running|Error Util.cpp' -Quiet){throw "Fixture error: $log"}
            if(Select-String -LiteralPath $log -Pattern 'RESPONSIVE_COMPLETE' -Quiet){$completed=$true;Start-Sleep -Milliseconds 800;break}
        }
        Start-Sleep -Milliseconds 250;$process.Refresh()
    }
}finally{if(-not $process.HasExited){Stop-Process -Id $process.Id;$process.WaitForExit()}}
if(-not $completed){throw "Fixture completion marker missing: $run"}
if(Select-String -LiteralPath (Join-Path $run 'stdout.txt') -Pattern 'Error while running|Error Util.cpp' -Quiet){throw "Engine error: $run/stdout.txt"}
$report=Get-Content -LiteralPath (Join-Path $run 'script-output/responsive.json') -Raw | ConvertFrom-Json
if($report.resolution.width -ne [int]$dimensions[0] -or $report.resolution.height -ne [int]$dimensions[1] -or [Math]::Abs($report.scale-$Scale) -gt 0.001){throw 'Actual native viewport/scale differs from the requested preset.'}
if(@($report.checks|Where-Object {-not $_.ok}).Count){throw 'Responsive fixture assertion failed.'}
$report|ConvertTo-Json -Depth 9
