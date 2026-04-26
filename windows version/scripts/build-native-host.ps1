param(
  [string]$Runtime = "win-x64",
  [switch]$FrameworkDependent
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "resources\native-host\PiChatNativeHost.csproj"
$out = Join-Path $root "resources\native-host\publish\$Runtime"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  throw "dotnet SDK is required to build the native host. Install .NET 8 SDK."
}

$args = @("publish", $project, "-c", "Release", "-r", $Runtime, "-o", $out, "/p:PublishSingleFile=true", "/p:IncludeNativeLibrariesForSelfExtract=true")
if ($FrameworkDependent) {
  $args += "--self-contained=false"
} else {
  $args += "--self-contained=true"
}

dotnet @args
$exe = Join-Path $out "PiChatNativeHost.exe"
if (-not (Test-Path $exe)) { throw "Native host executable was not produced: $exe" }
Copy-Item $exe (Join-Path $root "resources\native-host\PiChatNativeHost.exe") -Force
Write-Host "Native host built: resources\native-host\PiChatNativeHost.exe"
