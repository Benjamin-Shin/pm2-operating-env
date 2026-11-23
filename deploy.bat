@echo off
REM 빌드 압축 해제 후 릴리즈 전환
REM 사용: deploy.bat "D:\path\to\app-standalone-20260805-110951.7z"
REM       deploy.bat -A "D:\path\to\app-standalone-20260805-110951.7z"
REM       deploy.bat "D:\path\to\file.7z" 20260805-110951
chcp 65001 >nul
cd /d "%~dp0"
if "%~1"=="" (
  echo 사용법: deploy.bat ^<7z 경로^> [릴리즈폴더]
  echo 예: deploy.bat "D:\builds\app-standalone-20260805-110951.7z"
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
if errorlevel 1 pause
