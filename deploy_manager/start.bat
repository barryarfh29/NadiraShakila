@echo off
echo ========================================
echo   Deploy Manager - Starting Server
echo ========================================
echo.

echo Checking if node_modules exists...
if not exist "node_modules" (
    echo [WARNING] Dependencies not installed!
    echo Please run install.bat first.
    echo.
    pause
    exit /b 1
)

echo Starting server...
echo Press Ctrl+C to stop the server
echo.

node server.js

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Server failed to start!
    echo Please check the error messages above.
    echo.
    pause
)
