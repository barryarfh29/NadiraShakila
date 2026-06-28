@echo off
echo ========================================
echo  Rebuilding AI Desktop Assistant
echo ========================================
echo.
echo IMPORTANT: Make sure to close the app first!
echo Press Ctrl+C to cancel, or
pause
echo.

set FLUTTER_PATH=D:\ai_desktop\flutter\bin
set PATH=%FLUTTER_PATH%;%PATH%

echo [1/4] Waiting for files to unlock...
timeout /t 3 /nobreak >nul

echo [2/4] Cleaning previous build...
call flutter clean
if %errorlevel% neq 0 (
    echo Warning: Some files couldn't be deleted (app still running?)
    echo Continuing anyway...
)

echo.
echo [3/4] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo Error: Flutter pub get failed!
    pause
    exit /b 1
)

echo.
echo [4/4] Running application...
echo.
echo ========================================
echo  Application Starting...
echo ========================================
echo.
call flutter run -d windows

pause
