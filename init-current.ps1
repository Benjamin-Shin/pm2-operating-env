# init-current.ps1 - 최초 Current junction 생성
# 사용법: .\init-current.ps1 [릴리즈폴더]
# 폴더를 생략하면 releases 안에서 이름이 가장 뒤인 폴더를 사용한다.
# 히스토리: 2025-03 - 최초 생성
# 히스토리: 2026-11 - 고정 릴리즈 폴더명 제거
param(
    [string]$ReleaseFolder = ""
)

$ErrorActionPreference = "Stop"
$OpEnvRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleasesDir = Join-Path $OpEnvRoot "releases"
$CurrentPath = Join-Path $OpEnvRoot "Current"

if ([string]::IsNullOrWhiteSpace($ReleaseFolder)) {
    $existing = @()
    if (Test-Path $ReleasesDir) {
        $existing = @(Get-ChildItem -LiteralPath $ReleasesDir -Directory | Sort-Object Name -Descending)
    }
    if ($existing.Count -gt 0) {
        $ReleaseFolder = $existing[0].Name
        Write-Host "릴리즈 폴더 미지정 → $ReleaseFolder"
    } else {
        Write-Error "릴리즈 폴더를 지정하세요. 예: .\init-current.ps1 20260805-110951"
    }
}

$TargetPath = Join-Path $ReleasesDir $ReleaseFolder

if (-not (Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Write-Host "  releases\$ReleaseFolder 폴더 생성"
}

if (Test-Path $CurrentPath) {
    Write-Host "Current가 이미 존재합니다. 전환하려면 switch-release.ps1 $ReleaseFolder 를 사용하세요."
    exit 0
}

cmd /c mklink /J $CurrentPath $TargetPath
Write-Host "Current junction 생성: Current -> releases\$ReleaseFolder"
Write-Host "빌드를 releases\$ReleaseFolder 에 풀고 start.ps1 로 시작하세요."
