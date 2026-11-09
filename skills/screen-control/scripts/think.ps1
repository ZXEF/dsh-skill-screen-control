# think.ps1 - append timestamped "look / think / act" lines to the thought-stream log,
#             and optionally update the overlay header state.
# ASCII-only source; the TEXT you pass may be any language (files are UTF-8).
#
# Examples:
#   & .\think.ps1 -State "<one-line status for the overlay header>"
#   & .\think.ps1 -Lines "<line1>","<line2>","<line3>"
# (pass any language in the TEXT arguments; only this file must stay ASCII)
param(
  [string]$LogFile = '',
  [string]$StateFile = '',
  [string]$State = '',
  [string[]]$Lines = @()
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP 'screen-control'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if ($LogFile -eq '')   { $LogFile   = Join-Path $dir 'thinking.log' }
if ($StateFile -eq '') { $StateFile = Join-Path $dir 'state.txt' }

if ($State -ne '') {
  Set-Content -Path $StateFile -Value $State -Encoding UTF8
  Write-Output ("state: {0}" -f $State)
}

if ($Lines.Count -gt 0) {
  $stamp = Get-Date -Format 'HH:mm'
  foreach ($l in $Lines) {
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f $stamp, $l) -Encoding UTF8
  }
  Write-Output ("logged {0} line(s) -> {1}" -f $Lines.Count, $LogFile)
}
