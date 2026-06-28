@echo off
echo ========================================
echo   Deploy Manager - Installation
echo ========================================
echo.

echo Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed!
    echo Please download and install Node.js from: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo Node.js found!
node --version
echo.

echo Installing dependencies...
echo This may take a few minutes...
echo.

npm install

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   Installation Complete!
    echo ========================================
    echo.
    echo Next step: Run start.bat to launch the server
    echo.
) else (
    echo.
    echo [ERROR] Installation failed!
    echo Please check the error messages above.
    echo.
)

pause
