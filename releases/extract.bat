@echo off
REM Windows용 압축 해제 스크립트
REM 긴 경로명(255자 초과) 문제 해결

setlocal enabledelayedexpansion
chcp 65001 >nul

set "OPENV=%~dp0.."
call :read_env "%OPENV%\shared\.env" ARCHIVE_PREFIX
if not defined ARCHIVE_PREFIX set "ARCHIVE_PREFIX=standalone-deploy"

echo ==========================================
echo Extract Standalone Deployment Package
echo ==========================================
echo.

REM 압축 파일 확인
if "%~1"=="" (
    echo Usage: extract.bat ^<archive.7z or .tar.gz^>
    echo Example: extract.bat %ARCHIVE_PREFIX%-20240101-120000.7z
    echo.
    echo Archives in current directory:
    dir /b *.7z 2>NUL
    dir /b *.tar.gz 2>NUL
    if errorlevel 1 (
        echo No archive file found.
    )
    exit /b 1
)

set ARCHIVE_FILE=%~1
REM <ARCHIVE_PREFIX>-20240101-120000.7z -> 20240101-120000
set "NAME=%~n1"
if "%NAME:~-4%"==".tar" set "NAME=%NAME:~0,-4%"
call set "FOLDER=%%NAME:%ARCHIVE_PREFIX%-=%%"
if "%FOLDER%"=="%NAME%" goto :folder_from_stamp
goto :folder_ready
:folder_from_stamp
set "STAMP="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$n='%NAME%'; if ($n -match '(\d{8}-\d{6})') { $Matches[1] }"`) do set "STAMP=%%T"
if defined STAMP (
    set "FOLDER=!STAMP!"
) else (
    set "FOLDER=%ARCHIVE_PREFIX%"
)
:folder_ready
set EXTRACT_DIR=%~dp1%FOLDER%

REM Check archive exists
if not exist "%ARCHIVE_FILE%" (
    echo Error: Archive not found: %ARCHIVE_FILE%
    exit /b 1
)

echo Archive: %ARCHIVE_FILE%
echo Extract to: %EXTRACT_DIR%
echo.

REM Remove existing folder if confirmed
if exist "%EXTRACT_DIR%" (
    echo Warning: Target folder already exists: %EXTRACT_DIR%
    set /p CONFIRM="Delete and continue? (Y/N): "
    if /i not "!CONFIRM!"=="Y" (
        echo Cancelled.
        exit /b 0
    )
    echo Removing existing folder...
    rmdir /s /q "%EXTRACT_DIR%" 2>NUL
)

REM Create extract folder
mkdir "%EXTRACT_DIR%" 2>NUL
if errorlevel 1 (
    echo Error: Cannot create folder: %EXTRACT_DIR%
    exit /b 1
)

REM Prefer 7-Zip (better long-path handling)
where 7z >NUL 2>&1
if %errorlevel% equ 0 (
    echo Extracting with 7-Zip...
    7z x "%ARCHIVE_FILE%" -o"%EXTRACT_DIR%" -y
    if errorlevel 1 (
        echo Error: 7-Zip extraction failed
        exit /b 1
    )
    echo.
    echo ==========================================
    echo Extraction completed!
    echo ==========================================
    echo.
    echo Extracted folder: %EXTRACT_DIR%
    echo.
    echo Next steps:
    echo   1. switch-release.ps1 %FOLDER% (from OperatingEnv)
    echo   2. start.ps1 (from OperatingEnv)
    echo.
    exit /b 0
)

REM Fallback to tar if 7-Zip not found
where tar >NUL 2>&1
if %errorlevel% equ 0 (
    echo Extracting with tar...
    tar -xzf "%ARCHIVE_FILE%" -C "%EXTRACT_DIR%" --force-local
    if errorlevel 1 (
        echo Error: tar extraction failed
        exit /b 1
    )
    echo.
    echo ==========================================
    echo Extraction completed!
    echo ==========================================
    echo.
    echo Extracted folder: %EXTRACT_DIR%
    echo.
    echo Next steps:
    echo   1. switch-release.ps1 %FOLDER% (from OperatingEnv)
    echo   2. start.ps1 (from OperatingEnv)
    echo.
    exit /b 0
)

REM Neither 7-Zip nor tar found
echo Error: 7-Zip or tar is not installed.
echo.
echo How to resolve:
echo   1. Install 7-Zip (recommended): https://www.7-zip.org/
echo   2. Or use built-in tar on Windows 10+.
echo   3. Or use the PowerShell script (extract.ps1).
echo.
exit /b 1

:read_env
set "WANT=%~2"
if not exist "%~1" exit /b 0
if defined %WANT% exit /b 0
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~1") do (
    if /i "%%A"=="!WANT!" set "!WANT!=%%~B"
)
exit /b 0

