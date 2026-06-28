# ============================================================
#  update_logo.ps1
#  Jalankan script ini SETIAP KALI selesai mengganti
#  file assets\logo.png dengan gambar baru.
#
#  Cara pakai (dari folder d:\ai_desktop):
#     powershell -ExecutionPolicy Bypass -File .\update_logo.ps1
#
#  Script ini akan:
#   1. Regenerasi icon Windows (.ico) dari logo baru
#   2. Memaksa rekompilasi resource Windows
#   3. Build ulang aplikasi (release)
#   4. Menyalin hasil ke folder instalasi
#   5. Refresh cache icon Windows
# ============================================================

$ErrorActionPreference = "Stop"
$flutter = "D:\ai_desktop\flutter\bin\flutter.bat"
$dart    = "D:\ai_desktop\flutter\bin\dart.bat"
$root    = $PSScriptRoot
$installDir = "$env:LOCALAPPDATA\Programs\AI Desktop"

Write-Host "==> [1/5] Regenerasi icon Windows dari assets\logo.png ..." -ForegroundColor Cyan
& $dart run flutter_launcher_icons

Write-Host "==> [2/5] Memaksa rekompilasi resource Windows ..." -ForegroundColor Cyan
$rc = Join-Path $root "windows\runner\Runner.rc"
if (Test-Path $rc) { (Get-Item $rc).LastWriteTime = Get-Date }

Write-Host "==> [3/5] Build ulang aplikasi (release) ..." -ForegroundColor Cyan
Get-Process ai_desktop -ErrorAction SilentlyContinue | Stop-Process -Force
& $flutter build windows --release

Write-Host "==> [4/5] Menyalin ke folder instalasi ..." -ForegroundColor Cyan
if (Test-Path $installDir) {
    Copy-Item "$root\build\windows\x64\runner\Release\*" -Destination $installDir -Recurse -Force
    Write-Host "    Disalin ke: $installDir"
} else {
    Write-Host "    (Folder instalasi belum ada, lewati. Install dulu via installer.)" -ForegroundColor Yellow
}

Write-Host "==> [5/5] Refresh cache icon Windows ..." -ForegroundColor Cyan
ie4uinit.exe -show

Write-Host ""
Write-Host "SELESAI! Logo baru sudah terpasang." -ForegroundColor Green
Write-Host "Jika icon di taskbar/desktop masih lama, klik shortcut-nya sekali" -ForegroundColor Green
Write-Host "atau jalankan: Stop-Process -Name explorer -Force  (Explorer akan restart sendiri)" -ForegroundColor Green
