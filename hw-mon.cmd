@echo off
chcp 65001 >nul
where winget >nul 2>&1
if not %errorlevel%==0 goto run
where smartctl >nul 2>&1
if not errorlevel 1 goto run
echo Menginstall smartmontools (untuk POH SSD/HDD)...
winget install --id smartmontools.smartmontools --accept-package-agreements --accept-source-agreements >nul
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hw-mon.ps1"
pause
