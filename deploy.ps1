# deploy.ps1 - 빌드 압축 해제 후 릴리즈 전환
# 사용법: .\deploy.ps1 -A "path\to\app-standalone-20260805-110951.7z"
# 앱 엔트리/압축 접두사는 shared\.env 의 APP_ENTRY, APP_SERVER_JS, ARCHIVE_PREFIX
# 히스토리: 2026-08 - 타임스탬프 루트, nested 보정, 엔트리 검증, UTF-8 BOM
# 히스토리: 2026-11 - 앱 이름/엔트리/압축 접두사를 환경변수로 분리
param(
    [Parameter(Mandatory=$true)]
    [Alias("A")]
    [string]$ArchivePath,
    [string]$ReleaseFolder = ""
)

$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq "ConsoleHost") { chcp 65001 | Out-Null }

$ErrorActionPreference = "Stop"
$OpEnvRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $OpEnvRoot "env-config.ps1")
$cfg = Get-OpEnvSettings -OpEnvRoot $OpEnvRoot
$ReleasesDir = Join-Path $OpEnvRoot "releases"

if (-not (Test-Path $ArchivePath)) {
    Write-Error "압축 파일을 찾을 수 없습니다: $ArchivePath"
}

$ArchivePath = (Resolve-Path $ArchivePath).Path
$archiveName = [System.IO.Path]::GetFileName($ArchivePath)

if ([string]::IsNullOrWhiteSpace($ReleaseFolder)) {
    if ($archiveName -match '(\d{8}-\d{6})') {
        $ReleaseFolder = $Matches[1]
    } else {
        $ReleaseFolder = Get-Date -Format "yyyyMMdd-HHmmss"
        Write-Warning "파일명에서 타임스탬프를 못 찾아 ReleaseFolder=$ReleaseFolder 사용"
    }
}

$TargetPath = Join-Path $ReleasesDir $ReleaseFolder
if (-not (Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
}
if (Test-Path $TargetPath) {
    Remove-Item -Path $TargetPath -Recurse -Force
}

$7zipPath = Get-Command 7z -ErrorAction SilentlyContinue
if ($7zipPath) {
    Write-Host "7-Zip으로 압축 해제 중... → $ReleasesDir"
    & 7z x $ArchivePath "-o$ReleasesDir" -y
    if ($LASTEXITCODE -ne 0) {
        Write-Error "7-Zip 압축 해제 실패 (Exit Code: $LASTEXITCODE)"
    }
} else {
    Write-Error "7-Zip이 필요합니다. 설치: https://www.7-zip.org/"
}

# 압축 루트가 ARCHIVE_PREFIX 폴더인 경우 (구형 패키지)
$legacyRoot = Join-Path $ReleasesDir $cfg.ArchivePrefix
if (-not (Test-Path $TargetPath) -and (Test-Path $legacyRoot)) {
    Move-Item $legacyRoot $TargetPath -Force
    Write-Host "  $($cfg.ArchivePrefix) → $ReleaseFolder 로 이름 변경"
}

if (-not (Test-Path $TargetPath)) {
    $hasServer = Test-Path (Join-Path $ReleasesDir $cfg.AppServerJs)
    $hasStandalone = Test-Path (Join-Path $ReleasesDir $cfg.AppEntry)
    if ($hasServer -or $hasStandalone) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        Get-ChildItem -Path $ReleasesDir -Force | Where-Object {
            $_.Name -ne $ReleaseFolder -and $_.Name -ne '.gitkeep'
        } | ForEach-Object {
            Move-Item $_.FullName (Join-Path $TargetPath $_.Name) -Force
        }
        Write-Host "  플랫 압축 감지 → $ReleaseFolder 로 정리"
    }
}

if (-not (Test-Path $TargetPath)) {
    Write-Error "압축 해제 후 릴리즈 폴더가 없습니다: $TargetPath"
}

# nested: ReleaseFolder/<ARCHIVE_PREFIX> 또는 ReleaseFolder/ReleaseFolder
$nestedCandidates = @(
    (Join-Path $TargetPath $cfg.ArchivePrefix),
    (Join-Path $TargetPath $ReleaseFolder)
)
foreach ($nested in $nestedCandidates) {
    $nestedEntry = Join-Path $nested $cfg.AppEntry
    $nestedServer = Join-Path $nested $cfg.AppServerJs
    if ((Test-Path $nestedEntry) -or (Test-Path $nestedServer)) {
        Write-Host "  nested 폴더 보정: $nested"
        $tmp = Join-Path $ReleasesDir ("_flatten_" + $ReleaseFolder)
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Move-Item $nested $tmp -Force
        Remove-Item $TargetPath -Recurse -Force
        Move-Item $tmp $TargetPath -Force
        break
    }
}

$entry = Join-Path $TargetPath $cfg.AppEntry
$serverJs = Join-Path $TargetPath $cfg.AppServerJs
if (-not (Test-Path $entry)) {
    Write-Error "$($cfg.AppEntry) 가 없습니다: $entry"
}
if ($cfg.AppServerJs -and -not (Test-Path $serverJs)) {
    Write-Warning "$($cfg.AppServerJs) 가 없습니다: $serverJs"
}

Write-Host "압축 해제 완료: $TargetPath"
Write-Host "  $($cfg.AppEntry) OK"

& (Join-Path $OpEnvRoot "switch-release.ps1") $ReleaseFolder
