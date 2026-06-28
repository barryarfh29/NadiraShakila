# Builds the Windows release and packages it into an installer.
# Usage:  powershell -ExecutionPolicy Bypass -File build_installer.ps1

$ErrorActionPreference = "Stop"
$flutter = "D:\ai_desktop\flutter\bin\flutter.bat"
$iscc = @(
  "C:\Users\$env:USERNAME\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
  "C:\Program Files\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host "==> Building Windows release..." -ForegroundColor Cyan
& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }

if (-not $iscc) { throw "Inno Setup (ISCC.exe) not found. Install it: winget install JRSoftware.InnoSetup" }

Write-Host "==> Compiling installer..." -ForegroundColor Cyan
& $iscc "installer\ai_desktop.iss"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed" }

Write-Host "==> Done. Installer is in installer\output\" -ForegroundColor Green
