# ============================================================
#  auto_deploy.ps1
#  Mirip Easypanel "redeploy on push" tapi untuk desktop app.
#  
#  Cara pakai:
#    powershell -ExecutionPolicy Bypass -File .\auto_deploy.ps1
#
#  Script ini akan:
#   - Watch folder lib/ untuk perubahan file .dart
#   - Kalau ada perubahan, tunggu 3 detik (debounce)
#   - Auto rebuild & restart app
#   - Seperti Easypanel: code berubah → rebuild → deploy
# ============================================================

$ErrorActionPreference = "Stop"
$flutter = "D:\ai_desktop\flutter\bin\flutter.bat"
$projectRoot = $PSScriptRoot
$watchPath = Join-Path $projectRoot "lib"
$installDir = "$env:LOCALAPPDATA\Programs\AI Desktop"
$debounceMs = 3000

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AI Desktop - Auto Deploy (Easypanel)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Watching: $watchPath" -ForegroundColor Gray
Write-Host "Install:  $installDir" -ForegroundColor Gray
Write-Host ""
Write-Host "Save any .dart file to trigger rebuild..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

# Track last build time to debounce
$script:lastBuild = [DateTime]::MinValue
$script:building = $false

function Start-Deploy {
    if ($script:building) { return }
    
    $now = [DateTime]::Now
    $diff = ($now - $script:lastBuild).TotalMilliseconds
    if ($diff -lt $debounceMs) { return }
    
    $script:building = $true
    $script:lastBuild = $now
    
    Write-Host ""
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Change detected! Deploying..." -ForegroundColor Cyan
    
    # Step 1: Kill running app
    $proc = Get-Process ai_desktop -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "  [1/3] Stopping running app..." -ForegroundColor Yellow
        Stop-Process -Name ai_desktop -Force
        Start-Sleep -Seconds 1
    } else {
        Write-Host "  [1/3] App not running, skip." -ForegroundColor Gray
    }
    
    # Step 2: Build
    Write-Host "  [2/3] Building release..." -ForegroundColor Yellow
    $buildStart = Get-Date
    & $flutter build windows --release 2>&1 | Out-Null
    $buildTime = ((Get-Date) - $buildStart).TotalSeconds
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!] Build FAILED. Waiting for next change..." -ForegroundColor Red
        $script:building = $false
        return
    }
    Write-Host "  [2/3] Build OK ($([math]::Round($buildTime, 1))s)" -ForegroundColor Green
    
    # Step 3: Deploy (copy to install dir) & restart
    if (Test-Path $installDir) {
        Write-Host "  [3/3] Deploying to install folder..." -ForegroundColor Yellow
        Copy-Item "$projectRoot\build\windows\x64\runner\Release\*" -Destination $installDir -Recurse -Force
        Start-Process "$installDir\ai_desktop.exe"
        Write-Host "  [3/3] Deployed & launched!" -ForegroundColor Green
    } else {
        Write-Host "  [3/3] Running from build folder..." -ForegroundColor Yellow
        Start-Process "$projectRoot\build\windows\x64\runner\Release\ai_desktop.exe"
        Write-Host "  [3/3] Launched!" -ForegroundColor Green
    }
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Ready. Waiting for changes..." -ForegroundColor Gray
    $script:building = $false
}

# Create file system watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchPath
$watcher.Filter = "*.dart"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Register events
$action = { Start-Deploy }
Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

# Do initial build
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Initial build..." -ForegroundColor Cyan
Start-Deploy

# Keep script alive
try {
    while ($true) { Start-Sleep -Seconds 1 }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Write-Host "`nAuto-deploy stopped." -ForegroundColor Yellow
}
