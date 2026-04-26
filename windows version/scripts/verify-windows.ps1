$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js is not installed or not on PATH" }
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw "npm is not installed or not on PATH" }
  npm install
  npm run typecheck
  npm run build
  Write-Host "PiChat Windows verification passed."
} finally {
  Pop-Location
}
