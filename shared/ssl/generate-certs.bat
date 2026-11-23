@echo off
REM SSL 인증서 생성. 주체, SAN, 안내 URL은 shared\.env 의 SSL_* 를 사용한다.
REM 사용: generate-certs.bat
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-certs.ps1" %*
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
