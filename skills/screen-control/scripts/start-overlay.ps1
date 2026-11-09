# start-overlay.ps1 - launch the click-through thought-stream overlay as a detached
#                    process and remember its PID, so stop-overlay.ps1 can close it.
# ASCII-only source; STATE text may be any language (written as UTF-8).
#
# Examples:
#   & .\start-overlay.ps1 -State "<status line shown as overlay header>"
#   & .\start-overlay.ps1 -State "RUNNING" -X 360 -Y 6 -W 780 -H 200 -TailLines 6
param(
  [string]$LogFile = '',
  [string]$StateFile = '',
  [string]$State = '',
  [int]$X = 400,
  [int]$Y = 6,
  [int]$W = 1080,
  [int]$H = 250,
  [int]$TailLines = 9
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP 'screen-control'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if ($LogFile -eq '')   { $LogFile   = Join-Path $dir 'thinking.log' }
if ($StateFile -eq '') { $StateFile = Join-Path $dir 'state.txt' }
if (-not (Test-Path $LogFile))   { Set-Content -Path $LogFile -Value '' -Encoding UTF8 }
if (-not (Test-Path $StateFile)) { Set-Content -Path $StateFile -Value 'RUNNING' -Encoding UTF8 }
if ($State -ne '') { Set-Content -Path $StateFile -Value $State -Encoding UTF8 }

$pidFile = Join-Path $dir 'overlay.pid'
if (Test-Path $pidFile) {
  $old = 0
  try { $old = [int]((Get-Content $pidFile -Raw).Trim()) } catch { $old = 0 }
  if ($old -gt 0 -and (Get-Process -Id $old -ErrorAction SilentlyContinue)) {
    Write-Output ("overlay already running pid={0}; stop it first" -f $old)
    return
  }
}

$script = Join-Path $PSScriptRoot 'overlay.ps1'
if (-not (Test-Path $script)) { throw "overlay.ps1 not found next to this script: $script" }

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"' +
           ' -LogFile "' + $LogFile + '"' +
           ' -StateFile "' + $StateFile + '"' +
           ' -X ' + $X + ' -Y ' + $Y + ' -W ' + $W + ' -H ' + $H +
           ' -TailLines ' + $TailLines

$proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 900
$alive = [bool](Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)
if (-not $alive) { throw 'overlay process exited immediately (check overlay.ps1 parameters)' }

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII
Write-Output ("overlay started pid={0} log={1} state={2}" -f $proc.Id, $LogFile, $StateFile)
