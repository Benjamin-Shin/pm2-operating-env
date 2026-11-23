# switch-release.ps1
# Current junction을 지정한 릴리즈 폴더로 전환 후 PM2 reload
# 사용법: .\switch-release.ps1 20250306
# 히스토리: 2025-03 - 최초 생성 (OperatingEnv 배포 구조)
# 히스토리: 2025-03 - UTF-8 출력 (한글 깨짐 방지)
param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseFolder
)

# UTF-8 출력 (한글 깨짐 방지)
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq "ConsoleHost") { chcp 65001 | Out-Null }

$ErrorActionPreference = "Stop"
$OpEnvRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $OpEnvRoot "env-config.ps1")
$cfg = Get-OpEnvSettings -OpEnvRoot $OpEnvRoot
$ReleasesDir = Join-Path $OpEnvRoot "releases"
$SharedDir = Join-Path $OpEnvRoot "shared"
$CurrentPath = Join-Path $OpEnvRoot "Current"
$TargetPath = Join-Path $ReleasesDir $ReleaseFolder

if (-not (Test-Path $TargetPath)) {
    Write-Error "Release folder not found: $TargetPath"
}

# APP_ENTRY 존재 확인 (기본 standalone-server.mjs)
$serverScript = Join-Path $TargetPath $cfg.AppEntry
if (-not (Test-Path $serverScript)) {
    Write-Warning "$($cfg.AppEntry) not found. Extract build to this folder: $TargetPath"
}

# shared/runtime-config.json → 릴리즈 폴더로 복사
$runtimeConfig = Join-Path $SharedDir "runtime-config.json"
if (Test-Path $runtimeConfig) {
    Copy-Item $runtimeConfig (Join-Path $TargetPath "runtime-config.json") -Force
    Write-Host "  runtime-config.json copied"
}

# 기존 Current junction 제거
if (Test-Path $CurrentPath) {
    if ((Get-Item $CurrentPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        cmd /c rmdir $CurrentPath
        Write-Host "  Old Current junction removed"
    } else {
        Write-Error "Current is not a junction. Check manually."
    }
}

# 새 junction 생성
cmd /c mklink /J $CurrentPath $TargetPath
Write-Host "  Current -> releases\$ReleaseFolder junction created"

# PM2 reload (실행 중이면) - jlist 대신 list 사용 (jlist는 username/USERNAME 중복키로 ConvertFrom-Json 실패)
$pm2ListOutput = pm2 list 2>&1 | Out-String
$hasApp = $pm2ListOutput -match [regex]::Escape($cfg.Pm2AppName)
if ($LASTEXITCODE -eq 0 -and $hasApp) {
    Set-Location $OpEnvRoot
    pm2 reload ecosystem.config.js
    Write-Host "  PM2 reload done ($($cfg.Pm2AppName))"
    Save-OpEnvPm2
} else {
    Write-Host "  PM2 app '$($cfg.Pm2AppName)' is not running. Run start.ps1 to start."
}

Write-Host ""
Write-Host "Release switched: $ReleaseFolder"
