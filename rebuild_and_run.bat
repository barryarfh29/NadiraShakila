@echo off
echo ========================================
echo  Rebuilding AI Desktop Assistant
echo ========================================
echo.

set FLUTTER_PATH=D:\ai_desktop\flutter\bin
set PATH=%FLUTTER_PATH%;%PATH%

echo [1/3] Cleaning previous build...
call flutter clean
if %errorlevel% neq 0 (
    echo Error: Flutter clean failed!
    pause
    exit /b 1
)

echo.
echo [2/3] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo Error: Flutter pub get failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Running application...
echo.
echo ========================================
echo  Application Starting...
echo ========================================
echo.
call flutter run -d windows > out.txt 2>&1

pause
