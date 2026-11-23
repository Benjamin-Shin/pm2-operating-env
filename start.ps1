# start.ps1 - OperatingEnv PM2 web server start
# 히스토리: 2025-03 - 최초 생성, UTF-8 출력
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$OpEnvRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $OpEnvRoot "env-config.ps1")
$cfg = Get-OpEnvSettings -OpEnvRoot $OpEnvRoot

if (-not (Test-Path (Join-Path $OpEnvRoot "shared\.env"))) {
    Write-Error "shared\.env 파일이 없습니다. shared\env.example을 복사하여 .env를 생성하세요."
}

if (-not (Test-Path (Join-Path $OpEnvRoot "Current"))) {
    Write-Error "Current junction이 없습니다. 먼저 switch-release.ps1로 릴리즈를 지정하세요."
}

$serverScript = Join-Path $OpEnvRoot "Current\$($cfg.AppEntry)"
if (-not (Test-Path $serverScript)) {
    Write-Error "Current\$($cfg.AppEntry) 가 없습니다. 빌드를 releases\<날짜>에 풀고 switch-release로 전환하세요."
}

Set-Location $OpEnvRoot
pm2 start ecosystem.config.js
Save-OpEnvPm2
Write-Host ""
Write-Host "Started ($($cfg.Pm2AppName)). Check: pm2 status / pm2 logs $($cfg.Pm2AppName)"
