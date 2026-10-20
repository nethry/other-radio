<#
Drives the OtherRadio Windows desktop app for agents (Windows PowerShell 5.1).
Usage: & .claude\skills\run-other-radio\driver.ps1 <command> [args]

  build                 flutter build windows --debug (finds the SDK and Rust)
  test                  dart format + flutter analyze + flutter test
  launch                (re)start the debug exe, pin the window to 1600x900 at 0,0
  shot <name>           screenshot the app window -> build\run-shots\<name>.png
  click <x> <y>         left-click at window-relative pixel (same coords as shots)
  media [status] [sec]  print Windows media sessions (SMTC); with a status
                        (Playing/Paused/Stopped) wait until OtherRadio reports it
  flyout <name>         open Quick Settings (Win+A), screenshot the whole screen
                        (shows the system media card + thumbnail), close it
  stop                  kill the app
#>
param([Parameter(Position = 0)][string]$Command, [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest)
$ErrorActionPreference = 'Stop'
$Unit = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Exe = "$Unit\build\windows\x64\runner\Debug\other_radio.exe"
$Shots = "$Unit\build\run-shots"

Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class OtherRadioWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
}
"@
# Without this, a scaled display (e.g. 125%) gives virtualized coords and clipped shots.
[void][OtherRadioWin]::SetProcessDPIAware()

function Use-Toolchain {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $root = $env:FLUTTER_ROOT
    $ide = "$Unit\.idea\libraries\Dart_SDK.xml"
    if (-not $root -and (Test-Path $ide)) {
      # The IDE config records the SDK even when it is not on PATH.
      $m = [regex]::Match((Get-Content $ide -Raw), 'file://([^"]+?)[/\\]bin[/\\]cache[/\\]dart-sdk')
      if ($m.Success) { $root = $m.Groups[1].Value }
    }
    if (-not $root -or -not (Test-Path "$root\bin\flutter.bat")) { throw 'Flutter SDK not found: put flutter on PATH or set FLUTTER_ROOT' }
    $env:Path = "$root\bin;$env:Path"
  }
  if (Test-Path "$env:USERPROFILE\.cargo\bin") { $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path" }
}

function Get-AppWindow {
  $p = Get-Process other_radio -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { throw 'OtherRadio is not running (driver.ps1 launch)' }
  $p.MainWindowHandle
}

function Get-Rect($h) { $r = New-Object OtherRadioWin+RECT; [void][OtherRadioWin]::GetWindowRect($h, [ref]$r); $r }

function Save-Window([string]$name) {
  $h = Get-AppWindow; $r = Get-Rect $h
  New-Item -ItemType Directory -Force $Shots | Out-Null
  $out = "$Shots\$name.png"
  $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  # Flag 2 = PW_RENDERFULLCONTENT; without it the Flutter (GPU) surface is black.
  $dc = $g.GetHdc(); [void][OtherRadioWin]::PrintWindow($h, $dc, 2); $g.ReleaseHdc($dc)
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  "window $($r.R - $r.L)x$($r.B - $r.T) -> $out"
}

function Get-MediaSessions {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
  $await = { param($op, [Type]$t) $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
  $mgrT = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
  $propsT = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
  $mgr = & $await ($mgrT::RequestAsync()) $mgrT
  foreach ($s in $mgr.GetSessions()) {
    $p = & $await ($s.TryGetMediaPropertiesAsync()) $propsT
    [pscustomobject]@{
      App = $s.SourceAppUserModelId; Status = "$($s.GetPlaybackInfo().PlaybackStatus)"
      Title = $p.Title; Artist = $p.Artist; Album = $p.AlbumTitle; Thumbnail = [bool]$p.Thumbnail
    }
  }
}

switch ($Command) {
  'build' { Use-Toolchain; Push-Location $Unit; try { flutter build windows --debug } finally { Pop-Location } }
  'test' {
    Use-Toolchain; Push-Location $Unit
    try { dart format lib test tool; flutter analyze; if ($LASTEXITCODE) { throw 'analyze failed' }; flutter test } finally { Pop-Location }
  }
  'launch' {
    if (-not (Test-Path $Exe)) { throw "No build at $Exe (driver.ps1 build)" }
    Get-Process other_radio -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Process $Exe -WorkingDirectory (Split-Path $Exe)
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Get-Process other_radio -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) {
      if ((Get-Date) -gt $deadline) { throw 'window did not appear within 30 s' }
      Start-Sleep -Milliseconds 300
    }
    $h = Get-AppWindow
    # Restore (in case Windows remembers maximized) and pin size so coordinates are stable.
    [void][OtherRadioWin]::ShowWindow($h, 9); [void][OtherRadioWin]::MoveWindow($h, 0, 0, 1600, 900, $true)
    Start-Sleep -Seconds 6  # catalogue shows from cache, then refreshes over the network
    "launched pid $((Get-Process other_radio).Id), window 1600x900"
  }
  'shot' { Save-Window ($(if ($Rest) { $Rest[0] } else { 'shot' })) }
  'click' {
    $h = Get-AppWindow; $r = Get-Rect $h; $w = [OtherRadioWin]
    # Foreground lock blocks SetForegroundWindow from a background shell, so raise
    # the window via a brief TOPMOST toggle (3 = SWP_NOMOVE|SWP_NOSIZE).
    [void]$w::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 3)
    [void]$w::SetWindowPos($h, [IntPtr](-2), 0, 0, 0, 0, 3)
    $w::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); $w::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void]$w::SetForegroundWindow($h); Start-Sleep -Milliseconds 300
    $pt = New-Object OtherRadioWin+POINT; $pt.X = $r.L + [int]$Rest[0]; $pt.Y = $r.T + [int]$Rest[1]
    # Never click into whatever else is on screen (2 = GA_ROOT).
    if ($w::GetAncestor($w::WindowFromPoint($pt), 2) -ne $h) { throw "another window covers $($Rest[0]),$($Rest[1]); not clicking" }
    [void]$w::SetCursorPos($pt.X, $pt.Y)
    $w::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); $w::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 800
    "clicked $($Rest[0]),$($Rest[1])"
  }
  'media' {
    $want = if ($Rest) { $Rest[0] } else { $null }
    $deadline = (Get-Date).AddSeconds($(if ($Rest.Count -gt 1) { [int]$Rest[1] } else { 20 }))
    do {
      $sessions = @(Get-MediaSessions)
      $ours = $sessions | Where-Object { $_.App -like '*other_radio*' }
      if (-not $want -or ($ours -and $ours.Status -eq $want)) { $sessions | Format-List; return }
      Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    $sessions | Format-List; throw "OtherRadio media status did not become $want"
  }
  'flyout' {
    $k = [OtherRadioWin]
    $k::keybd_event(0x5B, 0, 0, [UIntPtr]::Zero); $k::keybd_event(0x41, 0, 0, [UIntPtr]::Zero)
    $k::keybd_event(0x41, 0, 2, [UIntPtr]::Zero); $k::keybd_event(0x5B, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Seconds 3
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    New-Item -ItemType Directory -Force $Shots | Out-Null
    $out = "$Shots\$($(if ($Rest) { $Rest[0] } else { 'flyout' })).png"
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    $k::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero); $k::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)
    "screen $($b.Width)x$($b.Height) -> $out"
  }
  'stop' { Get-Process other_radio -ErrorAction SilentlyContinue | Stop-Process -Force; 'stopped' }
  default { Get-Content $PSCommandPath -TotalCount 16 | Select-Object -Skip 1 }
}
