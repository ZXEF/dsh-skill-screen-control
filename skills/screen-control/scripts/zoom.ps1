# zoom.ps1 - crop a region and enlarge it (nearest or smooth) so a vision model can
#            read small text / identify small icons. Prints the origin so you can map
#            coordinates in the zoomed image back to screen coordinates.
# ASCII-only source.
#
# Examples:
#   & .\zoom.ps1 -X 660 -Y 450 -W 500 -H 280 -Scale 3
#   & .\zoom.ps1 -In C:\tmp\shot.png -X 1150 -Y 140 -W 500 -H 200 -Scale 3 -Out C:\tmp\z.png
param(
  [string]$In = '',
  [int]$X = 0,
  [int]$Y = 0,
  [int]$W = 400,
  [int]$H = 300,
  [int]$Scale = 3,
  [string]$Out = '',
  [switch]$Smooth
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$dir = Join-Path $env:TEMP 'screen-control'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

if ($In -eq '') {
  Add-Type -AssemblyName System.Windows.Forms
  $In = Join-Path $dir 'snap.png'
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp0 = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g0 = [System.Drawing.Graphics]::FromImage($bmp0)
  $g0.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $bmp0.Save($In, [System.Drawing.Imaging.ImageFormat]::Png)
  $g0.Dispose(); $bmp0.Dispose()
  Write-Output ("captured {0} {1}x{2}" -f $In, $b.Width, $b.Height)
}

if (-not (Test-Path $In)) { throw "source not found: $In" }
if ($Out -eq '') { $Out = Join-Path $dir 'zoom.png' }

$img = [System.Drawing.Image]::FromFile($In)
if ($X -lt 0) { $X = 0 }
if ($Y -lt 0) { $Y = 0 }
if ($X -ge $img.Width -or $Y -ge $img.Height) {
  $img.Dispose()
  throw "origin outside image: ($X,$Y) vs $($img.Width)x$($img.Height)"
}
if (($X + $W) -gt $img.Width)  { $W = $img.Width - $X }
if (($Y + $H) -gt $img.Height) { $H = $img.Height - $Y }

$crop = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), (New-Object System.Drawing.Rectangle $X, $Y, $W, $H), [System.Drawing.GraphicsUnit]::Pixel)

$ow = $W * $Scale
$oh = $H * $Scale
$big = New-Object System.Drawing.Bitmap $ow, $oh
$g2 = [System.Drawing.Graphics]::FromImage($big)
if ($Smooth) { $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic }
else         { $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor }
$g2.DrawImage($crop, 0, 0, $ow, $oh)
$big.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose(); $g2.Dispose(); $crop.Dispose(); $big.Dispose(); $img.Dispose()

Write-Output ("zoom: origin=({0},{1}) size={2}x{3} scale={4} -> {5}" -f $X, $Y, $W, $H, $Scale, $Out)
Write-Output ("mapping: screen_x = {0} + zoom_x/{1}, screen_y = {2} + zoom_y/{3}" -f $X, $Scale, $Y, $Scale)
