@echo off
:: hw-mon online runner - auto admin elevate + zero install
net session >nul 2>&1
if %errorlevel%==0 goto run

echo Meminta hak administrator (UAC)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:run
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/agusedyc/hw-mon/main/hw-mon.ps1)"
pause
