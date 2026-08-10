@echo off
chcp 65001 >nul

:: auto elevate
net session >nul 2>&1
if %errorlevel%==0 goto run
echo Meminta hak administrator (UAC)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:run
where winget >nul 2>&1
if not %errorlevel%==0 goto exec
where smartctl >nul 2>&1
if not errorlevel 1 goto exec
echo Menginstall smartmontools (untuk POH SSD/HDD)...
winget install --id smartmontools.smartmontools --accept-package-agreements --accept-source-agreements >nul

:exec
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hw-mon.ps1"
pause
