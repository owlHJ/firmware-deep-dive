@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0format.ps1" %*
exit /b %ERRORLEVEL%

