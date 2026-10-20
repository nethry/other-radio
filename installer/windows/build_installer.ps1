<#
Builds build\installer\OtherRadio-Setup-<version>.exe (Windows PowerShell 5.1).
Usage: & installer\windows\build_installer.ps1 [-SkipFlutterBuild]
Needs Flutter + Rust (see AGENTS.md), Inno Setup 6 (winget install JRSoftware.InnoSetup),
and Visual Studio / Build Tools with the C++ workload for the MSVC runtime DLLs.
#>
param([switch]$SkipFlutterBuild)
$ErrorActionPreference = 'Stop'
$Unit = (Resolve-Path "$PSScriptRoot\..\..").Path

# Terminals opened before a PATH change still carry the old value.
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'flutter not found on PATH' }

# pubspec "version: 0.1.0+1" -> installer version 0.1.0
$version = (Select-String -Path "$Unit\pubspec.yaml" -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value

$iscc = @(
  (Get-Command iscc -ErrorAction SilentlyContinue).Source,
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup not found: winget install --id JRSoftware.InnoSetup -e --scope user' }

$crt = foreach ($root in "$env:ProgramFiles\Microsoft Visual Studio", "${env:ProgramFiles(x86)}\Microsoft Visual Studio") {
  if (Test-Path $root) {
    Get-ChildItem $root -Recurse -Directory -Filter 'Microsoft.VC14*.CRT' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\Redist\\MSVC\\[^\\]+\\x64\\' -and $_.FullName -notmatch 'onecore' }
  }
}
$crt = $crt | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'MSVC redistributable CRT not found; install the VS "Desktop development with C++" workload' }

Push-Location $Unit
try {
  if (-not $SkipFlutterBuild) {
    flutter build windows --release
    if ($LASTEXITCODE) { throw 'flutter build windows --release failed' }
  }
  $bundle = "$Unit\build\windows\x64\runner\Release"
  foreach ($required in 'other_radio.exe', 'flutter_windows.dll', 'data\icudtl.dat', 'data\app.so', 'data\flutter_assets') {
    if (-not (Test-Path "$bundle\$required")) { throw "Incomplete Flutter bundle: $required" }
  }
  foreach ($required in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    if (-not (Test-Path "$($crt.FullName)\$required")) { throw "Missing MSVC runtime: $required" }
  }
  & $iscc /Qp "/DAppVersion=$version" "/DBundleDir=$bundle" `
    "/DCrtDir=$($crt.FullName)" "/DOutputDir=$Unit\build\installer" "$Unit\installer.iss"
  if ($LASTEXITCODE) { throw "ISCC failed ($LASTEXITCODE)" }
} finally { Pop-Location }

Get-Item "$Unit\build\installer\OtherRadio-Setup-$version.exe" | Select-Object FullName, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
