# stop-overlay.ps1 - stop the overlay started by start-overlay.ps1 (kills the PID it
#                   recorded) and remove the pid file.
# ASCII-only source.
param(
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP 'screen-control'
$pidFile = Join-Path $dir 'overlay.pid'

if (-not (Test-Path $pidFile)) {
  if (-not $Quiet) { Write-Output 'no overlay pid file; nothing to stop' }
  return
}

$target = 0
try { $target = [int]((Get-Content $pidFile -Raw).Trim()) } catch { $target = 0 }

if ($target -le 0) {
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
  if (-not $Quiet) { Write-Output 'pid file was invalid; removed' }
  return
}

$proc = Get-Process -Id $target -ErrorAction SilentlyContinue
if ($proc) {
  Stop-Process -Id $target -Force
  Start-Sleep -Milliseconds 300
  $still = [bool](Get-Process -Id $target -ErrorAction SilentlyContinue)
  if (-not $Quiet) { Write-Output ("stopped pid={0} (still alive: {1})" -f $target, $still) }
} else {
  if (-not $Quiet) { Write-Output ("pid={0} was not running" -f $target) }
}

Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
