@echo off
REM Current junction을 지정한 릴리즈 폴더로 전환 후 PM2 reload
REM 사용: switch-release.bat 20260805-110951
chcp 65001 >nul
cd /d "%~dp0"
if "%~1"=="" (
  echo 사용법: switch-release.bat ^<릴리즈폴더^>
  echo 예: switch-release.bat 20260805-110951
  echo releases 폴더 목록:
  dir /b /ad "%~dp0releases" 2>nul
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-release.ps1" %*
if errorlevel 1 pause
