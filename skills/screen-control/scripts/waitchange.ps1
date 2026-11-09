# waitchange.ps1 - wait until a screen region changes (loading finished, dialog appeared,
#                 customer walked in ...), then save a screenshot.
# ASCII-only source.
#
# Examples:
#   & .\waitchange.ps1 -TimeoutSec 20
#   & .\waitchange.ps1 -Region "300,300,1300,700" -TimeoutSec 15 -Out "$env:TEMP\sc\after.png"
#
# NOTE: if the thought-stream overlay is showing, exclude its area from Region,
#       otherwise the overlay's own text updates will count as "change".
param(
  [string]$Region = '',
  [int]$TimeoutSec = 20,
  [int]$IntervalMs = 400,
  [int]$Step = 4,
  [int]$PixelThreshold = 12,
  [double]$AreaThreshold = 0.002,
  [string]$Out = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$dir = Join-Path $env:TEMP 'screen-control'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if ($Out -eq '') { $Out = Join-Path $dir 'changed.png' }

function Get-ShotBitmap {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $g.Dispose()
  return $bmp
}

function Get-Frame($bmp) {
  $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $data.Stride * $bmp.Height
  $arr = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $arr, 0, $len)
  $bmp.UnlockBits($data)
  return @{ Bytes = $arr; Stride = $data.Stride; W = $bmp.Width; H = $bmp.Height }
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

$baseBmp = Get-ShotBitmap
$base = Get-Frame $baseBmp
$baseBmp.Dispose()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$changed = $false
$samples = 0
$diffCount = 0
$lastBmp = $null

while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  Start-Sleep -Milliseconds $IntervalMs
  $bmp = Get-ShotBitmap
  $cur = Get-Frame $bmp
  $samples = 0; $diffCount = 0
  for ($y = $ry; $y -lt ($ry + $rh); $y += $Step) {
    $rowBase = $y * $base.Stride
    for ($x = $rx; $x -lt ($rx + $rw); $x += $Step) {
      $idx = $rowBase + ($x * 4)
      $samples++
      if ([Math]::Abs($cur.Bytes[$idx]     - $base.Bytes[$idx])     -gt $PixelThreshold -or
          [Math]::Abs($cur.Bytes[$idx + 1] - $base.Bytes[$idx + 1]) -gt $PixelThreshold -or
          [Math]::Abs($cur.Bytes[$idx + 2] - $base.Bytes[$idx + 2]) -gt $PixelThreshold) {
        $diffCount++
      }
    }
  }
  $frac = 0.0
  if ($samples -gt 0) { $frac = $diffCount / $samples }
  if ($frac -gt $AreaThreshold) {
    $changed = $true
    $lastBmp = $bmp
    break
  }
  $bmp.Dispose()
}

if ($lastBmp -eq $null) { $lastBmp = Get-ShotBitmap }
$lastBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$lastBmp.Dispose()

Write-Output ("changed={0} elapsed={1:N1}s samples={2} diff={3} frac={4:P2} -> {5}" -f $changed, $sw.Elapsed.TotalSeconds, $samples, $diffCount, $frac, $Out)
if (-not $changed) { Write-Output 'note: nothing changed before timeout (static screen, or Region excludes the changing part)' }
