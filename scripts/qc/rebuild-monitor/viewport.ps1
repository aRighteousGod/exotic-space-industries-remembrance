# Resize only the client created by this fixture. Factorio restores saved geometry
# after --window-size, so the native client rectangle must be verified explicitly.
if(-not ('RebuildViewport' -as [type])){Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RebuildViewport {
    public delegate bool Callback(IntPtr hwnd,IntPtr arg);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left,top,right,bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(Callback callback,IntPtr arg);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int width,int height,uint flags);
    public static bool Resize(int processId){
        bool done=false;IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
        try {EnumWindows((hwnd,arg)=>{
            uint pid;GetWindowThreadProcessId(hwnd,out pid);if(pid!=processId)return true;
            Rect old;GetClientRect(hwnd,out old);if(old.right<400||old.bottom<300)return true;
            Rect outer;GetWindowRect(hwnd,out outer);
            done=SetWindowPos(hwnd,IntPtr.Zero,0,0,outer.right-outer.left-old.right+1280,outer.bottom-outer.top-old.bottom+720,0x0010|0x0004|0x0002);
            return false;
        },IntPtr.Zero);}finally{SetThreadDpiAwarenessContext(previous);}
        return done;
    }
}
'@}
