@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 exit /b 1
where flutter >nul 2>&1
if not errorlevel 1 (
  call flutter run -d web-server --web-hostname=localhost --web-port=5353 --dart-define=API_BASE_URL=http://localhost:5129
  exit /b
)
if exist "E:\flutter\bin\flutter.bat" (
  call "E:\flutter\bin\flutter.bat" run -d web-server --web-hostname=localhost --web-port=5353 --dart-define=API_BASE_URL=http://localhost:5129
  exit /b
)
echo Flutter SDK not found. Add Flutter bin to PATH and try again.
exit /b 1

