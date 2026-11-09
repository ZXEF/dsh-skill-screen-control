# overlay.ps1 - always-on-top, click-through "thought stream" overlay (ASCII-only source)
#
# Shows a fixed header line (from StateFile) plus the last N lines of LogFile.
# Both files are read as UTF-8, so Chinese text is safe in the DATA files.
#
# Usage (run in background):
#   & .\overlay.ps1 -LogFile "$env:TEMP\screen-control\thinking.log" `
#                   -StateFile "$env:TEMP\screen-control\state.txt"
param(
  [string]$LogFile = '',
  [string]$StateFile = '',
  [int]$X = 400,
  [int]$Y = 6,
  [int]$W = 1080,
  [int]$H = 250,
  [int]$TailLines = 9
)

if ($LogFile -eq '')   { $LogFile   = Join-Path $env:TEMP 'screen-control\thinking.log' }
if ($StateFile -eq '') { $StateFile = Join-Path $env:TEMP 'screen-control\state.txt' }
$dir = Split-Path -Parent $LogFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('OvlNative' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class OvlNative {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}
"@
}

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Bounds = New-Object System.Drawing.Rectangle $X, $Y, $W, $H
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 8, 10, 18)
$form.Opacity = 0.86

$lbl = New-Object System.Windows.Forms.Label
$lbl.Dock = [System.Windows.Forms.DockStyle]::Fill
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(255, 176, 240, 208)
$lbl.BackColor = [System.Drawing.Color]::Transparent
$lbl.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
$lbl.TextAlign = [System.Drawing.ContentAlignment]::TopLeft
$lbl.Padding = New-Object System.Windows.Forms.Padding(14, 9, 14, 8)
$lbl.Text = 'Init...'
$form.Controls.Add($lbl)

# WS_EX_TRANSPARENT -> clicks pass through to the window below
$form.Add_Shown({
  $hwnd = $form.Handle
  $ex = [OvlNative]::GetWindowLong($hwnd, -20)
  [void][OvlNative]::SetWindowLong($hwnd, -20, $ex -bor 0x20)
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 450
$timer.Add_Tick({
  try {
    $state = ''
    if (Test-Path $StateFile) {
      $state = ([System.IO.File]::ReadAllText($StateFile, [System.Text.Encoding]::UTF8)).Trim()
    }
    $lines = @()
    if (Test-Path $LogFile) {
      $lines = @(Get-Content -Path $LogFile -Encoding UTF8 -Tail $TailLines)
    }
    $txt = $state + [Environment]::NewLine + ($lines -join [Environment]::NewLine)
    if ($txt -ne $lbl.Text) { $lbl.Text = $txt }
  } catch {}
})
$timer.Start()

[System.Windows.Forms.Application]::Run($form)
