@echo off
echo Stopping old AI Desktop instances...
taskkill /F /IM ai_desktop.exe 2>nul
timeout /t 2 /nobreak >nul

echo Cleaning lock files...
del /F /Q "%USERPROFILE%\Documents\*.lock" 2>nul

echo Starting new instance...
start "" "build\windows\x64\runner\Debug\ai_desktop.exe"

echo Done!
timeout /t 2 /nobreak >nul
exit