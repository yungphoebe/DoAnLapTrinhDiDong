@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 exit /b 1
dotnet run --project backend/AiGym.Api --launch-profile http
exit /b %errorlevel%

