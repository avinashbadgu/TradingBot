param([string]$Keys='', [int]$ClickX=-1, [int]$ClickY=-1, [switch]$DoubleClick)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class MT5UI {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
'@
[MT5UI]::SetProcessDPIAware() | Out-Null
$terminal=Get-Process terminal64 | Select-Object -First 1
if(-not $terminal -or $terminal.MainWindowHandle -eq 0){throw 'No visible MT5 window.'}
if($Keys -or $ClickX -ge 0){
 $shell=New-Object -ComObject WScript.Shell
 $shell.AppActivate($terminal.Id) | Out-Null
 [MT5UI]::SetForegroundWindow($terminal.MainWindowHandle) | Out-Null
 Start-Sleep -Milliseconds 200
 if([MT5UI]::GetForegroundWindow() -ne $terminal.MainWindowHandle){throw 'MT5 did not receive foreground focus; no input sent.'}
}
if($ClickX -ge 0) {
 [MT5UI]::SetCursorPos($ClickX,$ClickY) | Out-Null
 [MT5UI]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[MT5UI]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 if($DoubleClick){[MT5UI]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[MT5UI]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
}
if($Keys){[System.Windows.Forms.SendKeys]::SendWait($Keys)}
Start-Sleep -Milliseconds 500
$bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap=New-Object System.Drawing.Bitmap($bounds.Width,$bounds.Height)
$graphics=[System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
$bitmap.Save((Join-Path (Split-Path $PSScriptRoot -Parent) 'Backtests\desktop.png'))
$graphics.Dispose();$bitmap.Dispose()
