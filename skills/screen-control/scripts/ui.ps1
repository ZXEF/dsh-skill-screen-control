# ui.ps1 - screen capture + input automation (ASCII-only source; safe for Windows PowerShell 5.1)
#
# Examples:
#   & .\ui.ps1 -ScreenInfo
#   & .\ui.ps1 -Windows
#   & .\ui.ps1 -Active
#   & .\ui.ps1 -Activate 'Notepad'
#   & .\ui.ps1 -Shot -Out C:\tmp\s.png
#   & .\ui.ps1 -Move -X 100 -Y 200
#   & .\ui.ps1 -Click -X 100 -Y 200
#   & .\ui.ps1 -RightClick -X 100 -Y 200
#   & .\ui.ps1 -DoubleClick -X 100 -Y 200
#   & .\ui.ps1 -Drag -X 900 -Y 500 -X2 300 -Y2 500
#   & .\ui.ps1 -Wheel 120        (up)   /   & .\ui.ps1 -Wheel -120   (down)
#   & .\ui.ps1 -PressKey W
#   & .\ui.ps1 -Combo 'SHIFT,W'
#   & .\ui.ps1 -HoldKey W -HoldMs 1500
#   & .\ui.ps1 -Combo 'SHIFT,W' -HoldMs 3000
#   & .\ui.ps1 -Type 'hello'
#   & .\ui.ps1 -Paste 'any UTF-8 text (clipboard + Ctrl+V)'
param(
  [switch]$Shot,
  [string]$Out = '',
  [switch]$ScreenInfo,
  [switch]$Windows,
  [switch]$Active,
  [string]$Activate = '',
  [int]$X = -1, [int]$Y = -1, [int]$X2 = -1, [int]$Y2 = -1,
  [switch]$Move, [switch]$Click, [switch]$RightClick, [switch]$DoubleClick, [switch]$Drag,
  [int]$Wheel = 0,
  [string]$Modifier = '',
  [string]$Key = '',
  [string]$Combo = '',
  [string]$HoldKey = '',
  [int]$HoldMs = 1000,
  [string]$PressKey = '',
  [string]$Type = '',
  [string]$Paste = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ('UiNative' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class UiNative {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
}
"@
}

$LDOWN = 0x0002; $LUP = 0x0004; $RDOWN = 0x0008; $RUP = 0x0010
$MMOVE = 0x0001; $MWHEEL = 0x0800
$KEYUP = 0x0002

function Get-FgTitle {
  $h = [UiNative]::GetForegroundWindow()
  $sb = New-Object System.Text.StringBuilder 512
  [void][UiNative]::GetWindowText($h, $sb, $sb.Capacity)
  return [pscustomobject]@{ Handle = $h; Title = $sb.ToString() }
}

$keymap = @{
  'A'=0x41;'B'=0x42;'C'=0x43;'D'=0x44;'E'=0x45;'F'=0x46;'G'=0x47;'H'=0x48;
  'I'=0x49;'J'=0x4A;'K'=0x4B;'L'=0x4C;'M'=0x4D;'N'=0x4E;'O'=0x4F;'P'=0x50;
  'Q'=0x51;'R'=0x52;'S'=0x53;'T'=0x54;'U'=0x55;'V'=0x56;'W'=0x57;'X'=0x58;
  'Y'=0x59;'Z'=0x5A;
  '0'=0x30;'1'=0x31;'2'=0x32;'3'=0x33;'4'=0x34;'5'=0x35;'6'=0x36;'7'=0x37;'8'=0x38;'9'=0x39;
  'SPACE'=0x20;'TAB'=0x09;'ESC'=0x1B;'ENTER'=0x0D;'BACKSPACE'=0x08;'DELETE'=0x2E;
  'SHIFT'=0x10;'CTRL'=0x11;'ALT'=0x12;
  'LEFT'=0x25;'UP'=0x26;'RIGHT'=0x27;'DOWN'=0x28;
  'F1'=0x70;'F2'=0x71;'F3'=0x72;'F4'=0x73;'F5'=0x74;'F6'=0x75;
  'F7'=0x76;'F8'=0x77;'F9'=0x78;'F10'=0x79;'F11'=0x7A;'F12'=0x7B;
  'HOME'=0x24;'END'=0x23;'PAGEUP'=0x21;'PAGEDOWN'=0x22;'INSERT'=0x2D
}

function Get-Vk([string]$name) {
  $k = $name.Trim().ToUpper()
  if ($keymap.ContainsKey($k)) { return [int]$keymap[$k] }
  if ($k -match '^[A-Z0-9]$') { return [int][char]$k }
  throw "unknown key: $name"
}

# ---------- info ----------
if ($ScreenInfo) {
  foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    Write-Output ("{0} Bounds={1} Primary={2}" -f $s.DeviceName, $s.Bounds, $s.Primary)
  }
}

if ($Windows) {
  Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object @{n='Handle';e={$_.MainWindowHandle}}, Id, ProcessName, MainWindowTitle |
    Sort-Object ProcessName | Format-Table -AutoSize
}

if ($Active) {
  $fg = Get-FgTitle
  Write-Output ("foreground handle={0} title='{1}'" -f $fg.Handle, $fg.Title)
}

# ---------- activate ----------
if ($Activate -ne '') {
  $target = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$Activate*" } |
            Select-Object -First 1
  if (-not $target) { throw "no window matched '$Activate'" }
  $h = $target.MainWindowHandle
  $wsh = New-Object -ComObject WScript.Shell
  $ok = $false
  for ($i = 0; $i -lt 8; $i++) {
    if ([UiNative]::IsIconic($h)) { [void][UiNative]::ShowWindow($h, 9); Start-Sleep -Milliseconds 300 }
    try { [void]$wsh.AppActivate($target.Id) } catch {}
    Start-Sleep -Milliseconds 250
    if ([UiNative]::GetForegroundWindow() -eq $h) { $ok = $true; break }
    [UiNative]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [UiNative]::keybd_event(0x12, 0, $KEYUP, [UIntPtr]::Zero)
    [void][UiNative]::SetForegroundWindow($h)
    Start-Sleep -Milliseconds 200
    if ([UiNative]::GetForegroundWindow() -eq $h) { $ok = $true; break }
  }
  Write-Output ("activate '{0}' ok={1} title='{2}'" -f $Activate, $ok, $target.MainWindowTitle)
}

# ---------- shot ----------
if ($Shot) {
  if ($Out -eq '') { $Out = Join-Path $env:TEMP 'screen-control\shot.png' }
  $dir = Split-Path -Parent $Out
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output ("saved {0} {1}x{2}" -f $Out, $b.Width, $b.Height)
}

# ---------- pointer ----------
# hold modifier keys (Ctrl / Shift / Alt) down for the whole pointer action
$modVks = @()
if ($Modifier -ne '') {
  foreach ($m in ($Modifier -split ',')) {
    if ($m.Trim() -eq '') { continue }
    $mvk = Get-Vk $m
    $modVks += $mvk
    [UiNative]::keybd_event([byte]$mvk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
  }
  Write-Output ("modifier down: {0}" -f $Modifier)
}

if ($Move -and $X -ge 0 -and $Y -ge 0) {
  [void][UiNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 120
}

if ($Click -and $X -ge 0 -and $Y -ge 0) {
  [void][UiNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 80
  [UiNative]::mouse_event($LDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 50
  [UiNative]::mouse_event($LUP, 0, 0, 0, [UIntPtr]::Zero)
}

if ($RightClick -and $X -ge 0 -and $Y -ge 0) {
  [void][UiNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 80
  [UiNative]::mouse_event($RDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 50
  [UiNative]::mouse_event($RUP, 0, 0, 0, [UIntPtr]::Zero)
}

if ($DoubleClick -and $X -ge 0 -and $Y -ge 0) {
  [void][UiNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 80
  [UiNative]::mouse_event($LDOWN, 0, 0, 0, [UIntPtr]::Zero)
  [UiNative]::mouse_event($LUP, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 110
  [UiNative]::mouse_event($LDOWN, 0, 0, 0, [UIntPtr]::Zero)
  [UiNative]::mouse_event($LUP, 0, 0, 0, [UIntPtr]::Zero)
}

if ($Drag -and $X -ge 0 -and $Y -ge 0 -and $X2 -ge 0 -and $Y2 -ge 0) {
  [void][UiNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 120
  [UiNative]::mouse_event($LDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 120
  $steps = 24
  $dx = [int][Math]::Round(($X2 - $X) / $steps)
  $dy = [int][Math]::Round(($Y2 - $Y) / $steps)
  for ($i = 0; $i -lt $steps; $i++) {
    [UiNative]::mouse_event($MMOVE, $dx, $dy, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 15
  }
  [UiNative]::mouse_event($LUP, 0, 0, 0, [UIntPtr]::Zero)
  Write-Output ("dragged {0},{1} -> {2},{3}" -f $X, $Y, $X2, $Y2)
}

if ($Wheel -ne 0) {
  [UiNative]::mouse_event($MWHEEL, 0, 0, $Wheel, [UIntPtr]::Zero)
  Write-Output ("wheel {0}" -f $Wheel)
}

if ($modVks.Count -gt 0) {
  [array]::Reverse($modVks)
  foreach ($mvk in $modVks) {
    [UiNative]::keybd_event([byte]$mvk, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
  }
  Write-Output ("modifier up: {0}" -f $Modifier)
}

# ---------- keyboard ----------
if ($HoldKey -ne '') {
  $vk = Get-Vk $HoldKey
  [UiNative]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds $HoldMs
  [UiNative]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
  Write-Output ("held {0} for {1}ms" -f $HoldKey, $HoldMs)
}

if ($Combo -ne '') {
  $names = @($Combo -split ',' | Where-Object { $_.Trim() -ne '' })
  $vks = @($names | ForEach-Object { Get-Vk $_ })
  foreach ($vk in $vks) { [UiNative]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 30 }
  Start-Sleep -Milliseconds $HoldMs
  [array]::Reverse($vks)
  foreach ($vk in $vks) { [UiNative]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero); Start-Sleep -Milliseconds 30 }
  Write-Output ("combo {0} for {1}ms" -f $Combo, $HoldMs)
}

if ($PressKey -ne '') {
  $vk = Get-Vk $PressKey
  [UiNative]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [UiNative]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
  Write-Output ("pressed {0}" -f $PressKey)
}

if ($Key -ne '') {
  $wsh = New-Object -ComObject WScript.Shell
  $wsh.SendKeys($Key)
  Write-Output ("sendkeys {0}" -f $Key)
}

if ($Type -ne '') {
  $wsh = New-Object -ComObject WScript.Shell
  $wsh.SendKeys($Type)
  Write-Output ("typed {0}" -f $Type)
}

if ($Paste -ne '') {
  Set-Clipboard -Value $Paste
  Start-Sleep -Milliseconds 120
  [UiNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [UiNative]::keybd_event(0x56, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [UiNative]::keybd_event(0x56, 0, $KEYUP, [UIntPtr]::Zero)
  [UiNative]::keybd_event(0x11, 0, $KEYUP, [UIntPtr]::Zero)
  Write-Output ("pasted {0} chars" -f $Paste.Length)
}
