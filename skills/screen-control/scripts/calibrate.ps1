# calibrate.ps1 - find the REAL on-screen position of a UI element instead of guessing.
# ASCII-only source.
#
# Mode HoverDiff : take two screenshots with the cursor parked at two positions; the diff
#                  bounding box is the hover-sensitive element (buttons with hover states).
# Mode BorderScan: scan a region for a color family (Cyan/Light/White/Green/Yellow/Red)
#                  and report the bounding box of matching pixels (outlined buttons).
#
# Examples:
#   # hover calibration: cursor at (1212,400) vs (1212,520), look for what changed
#   & .\calibrate.ps1 -Mode HoverDiff -X 1212 -Y 400 -Axis y -Delta 120 -Region "900,300,600,500"
#
#   # border scan for a cyan-outlined button
#   & .\calibrate.ps1 -Mode BorderScan -Region "650,880,650,160" -Color Cyan
param(
  [ValidateSet('HoverDiff', 'BorderScan')]
  [string]$Mode = 'HoverDiff',
  [int]$X = 0,
  [int]$Y = 0,
  [ValidateSet('x', 'y')]
  [string]$Axis = 'y',
  [int]$Delta = 120,
  [string]$Region = '',
  [ValidateSet('Cyan', 'Light', 'White', 'Green', 'Yellow', 'Red')]
  [string]$Color = 'Cyan',
  [int]$Step = 2,
  [int]$Threshold = 10,
  [int]$MinPixels = 60,
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ('CalNative' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CalNative {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
}
"@
}

$dir = Join-Path $env:TEMP 'screen-control'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if ($OutDir -eq '') { $OutDir = $dir }

function Get-Shot([string]$path) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  return $b
}

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$rx = 0; $ry = 0; $rw = $screen.Width; $rh = $screen.Height
if ($Region -ne '') {
  $p = $Region -split ','
  if ($p.Count -ne 4) { throw "Region must be 'x,y,w,h'" }
  $rx = [int]$p[0]; $ry = [int]$p[1]; $rw = [int]$p[2]; $rh = [int]$p[3]
  if ($rx -lt 0) { $rx = 0 }
  if ($ry -lt 0) { $ry = 0 }
  if (($rx + $rw) -gt $screen.Width)  { $rw = $screen.Width - $rx }
  if (($ry + $rh) -gt $screen.Height) { $rh = $screen.Height - $ry }
}

function Test-Color($p, [string]$fam) {
  switch ($fam) {
    'Cyan'   { return ($p.G -gt 140 -and $p.B -gt 140 -and $p.R -lt 190) }
    'Light'  { return ($p.R -gt 150 -and $p.G -gt 150 -and $p.B -gt 150) }
    'White'  { return ($p.R -gt 210 -and $p.G -gt 210 -and $p.B -gt 210) }
    'Green'  { return ($p.G -gt 140 -and $p.R -lt 140 -and $p.B -lt 160) }
    'Yellow' { return ($p.R -gt 170 -and $p.G -gt 150 -and $p.B -lt 130) }
    'Red'    { return ($p.R -gt 150 -and $p.G -lt 110 -and $p.B -lt 110) }
  }
  return $false
}

if ($Mode -eq 'HoverDiff') {
  $a = Join-Path $OutDir 'calib_a.png'
  $b = Join-Path $OutDir 'calib_b.png'
  [void][CalNative]::SetCursorPos($X, $Y)
  Start-Sleep -Milliseconds 650
  [void](Get-Shot $a)
  if ($Axis -eq 'y') { [void][CalNative]::SetCursorPos($X, $Y + $Delta) }
  else               { [void][CalNative]::SetCursorPos($X + $Delta, $Y) }
  Start-Sleep -Milliseconds 650
  [void](Get-Shot $b)

  $bmpA = [System.Drawing.Bitmap]::FromFile($a)
  $bmpB = [System.Drawing.Bitmap]::FromFile($b)
  $minx = [int]::MaxValue; $miny = [int]::MaxValue; $maxx = -1; $maxy = -1; $cnt = 0
  for ($y = $ry; $y -lt ($ry + $rh); $y += $Step) {
    for ($x = $rx; $x -lt ($rx + $rw); $x += $Step) {
      $pa = $bmpA.GetPixel($x, $y); $pb = $bmpB.GetPixel($x, $y)
      if ([Math]::Abs($pa.R - $pb.R) -gt $Threshold -or
          [Math]::Abs($pa.G - $pb.G) -gt $Threshold -or
          [Math]::Abs($pa.B - $pb.B) -gt $Threshold) {
        $cnt++
        if ($x -lt $minx) { $minx = $x }
        if ($x -gt $maxx) { $maxx = $x }
        if ($y -lt $miny) { $miny = $y }
        if ($y -gt $maxy) { $maxy = $y }
      }
    }
  }
  $bmpA.Dispose(); $bmpB.Dispose()
  Write-Output ("mode=HoverDiff diff_samples={0} (images: {1} | {2})" -f $cnt, $a, $b)
  if ($cnt -lt $MinPixels) { Write-Output 'result: no element detected (no hover state, or both positions are off the element)'; return }
  $cx = [int](($minx + $maxx) / 2); $cy = [int](($miny + $maxy) / 2)
  Write-Output ("result: bbox=({0},{1})-({2},{3}) size={4}x{5} center=({6},{7})" -f $minx, $miny, $maxx, $maxy, ($maxx - $minx), ($maxy - $miny), $cx, $cy)
  return
}

$shot = Join-Path $OutDir 'calib_scan.png'
[void](Get-Shot $shot)
$img = [System.Drawing.Bitmap]::FromFile($shot)
$minx = [int]::MaxValue; $miny = [int]::MaxValue; $maxx = -1; $maxy = -1; $cnt = 0
for ($y = $ry; $y -lt ($ry + $rh); $y++) {
  for ($x = $rx; $x -lt ($rx + $rw); $x++) {
    if (Test-Color ($img.GetPixel($x, $y)) $Color) {
      $cnt++
      if ($x -lt $minx) { $minx = $x }
      if ($x -gt $maxx) { $maxx = $x }
      if ($y -lt $miny) { $miny = $y }
      if ($y -gt $maxy) { $maxy = $y }
    }
  }
}
$img.Dispose()
Write-Output ("mode=BorderScan color={0} pixels={1} (image: {2})" -f $Color, $cnt, $shot)
if ($cnt -lt $MinPixels) { Write-Output 'result: nothing matched; try another color family or a bigger region'; return }
$cx = [int](($minx + $maxx) / 2); $cy = [int](($miny + $maxy) / 2)
Write-Output ("result: bbox=({0},{1})-({2},{3}) size={4}x{5} center=({6},{7})" -f $minx, $miny, $maxx, $maxy, ($maxx - $minx), ($maxy - $miny), $cx, $cy)

