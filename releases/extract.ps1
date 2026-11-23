# Windows용 압축 해제 PowerShell 스크립트
# 긴 경로명(255자 초과) 문제 해결

param(
    [Parameter(Mandatory = $false)]
    [string]$ArchiveFile = ""
)

$OpEnvRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $OpEnvRoot "env-config.ps1")
$cfg = Get-OpEnvSettings -OpEnvRoot $OpEnvRoot
$archivePrefix = $cfg.ArchivePrefix

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Extract Standalone Deployment Package" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# 압축 파일 확인
if ([string]::IsNullOrEmpty($ArchiveFile)) {
    Write-Host "Usage: .\extract.ps1 -ArchiveFile <archive.7z or .tar.gz>" -ForegroundColor Yellow
    Write-Host "Example: .\extract.ps1 -ArchiveFile $archivePrefix-20240101-120000.7z" -ForegroundColor Yellow
    Write-Host ""
    
    # List archives in current directory (.7z preferred)
    $archiveFiles = Get-ChildItem -Filter "*.7z" -ErrorAction SilentlyContinue
    if (-not $archiveFiles) {
        $archiveFiles = Get-ChildItem -Filter "*.tar.gz" -ErrorAction SilentlyContinue
    }
    
    if ($archiveFiles) {
        Write-Host "Archives in current directory:" -ForegroundColor Cyan
        $archiveFiles | ForEach-Object { Write-Host "  - $($_.Name)" }
        Write-Host ""
        Write-Host "Using the first file automatically..." -ForegroundColor Yellow
        $ArchiveFile = $archiveFiles[0].FullName
    }
    else {
        Write-Host "Error: No archive file found." -ForegroundColor Red
        exit 1
    }
}

# Check archive exists
if (-not (Test-Path $ArchiveFile)) {
    Write-Host "Error: Archive not found: $ArchiveFile" -ForegroundColor Red
    exit 1
}

# <ARCHIVE_PREFIX>-20240101-120000.7z -> 20240101-120000
$archiveName = [System.IO.Path]::GetFileName($ArchiveFile)
$folderName = $archivePrefix
$escapedPrefix = [regex]::Escape($archivePrefix)
if ($archiveName -match "^$escapedPrefix-(.+)\.(7z|tar\.gz)$") {
    $folderName = $Matches[1]
} elseif ($archiveName -match '(\d{8}-\d{6})') {
    $folderName = $Matches[1]
}
$ExtractDir = Join-Path (Split-Path $ArchiveFile -Parent) $folderName

Write-Host "Archive: $ArchiveFile" -ForegroundColor Cyan
Write-Host "Extract to: $ExtractDir" -ForegroundColor Cyan
Write-Host ""

# Remove existing folder if confirmed
if (Test-Path $ExtractDir) {
    Write-Host "Warning: Target folder already exists: $ExtractDir" -ForegroundColor Yellow
    $confirm = Read-Host "Delete and continue? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Removing existing folder..." -ForegroundColor Yellow
    Remove-Item -Path $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Create extract folder
try {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}
catch {
    Write-Host "Error: Cannot create folder: $ExtractDir" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Check long path support
$longPathEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue).LongPathsEnabled

if (-not $longPathEnabled) {
    Write-Host "Warning: Windows long path support is disabled." -ForegroundColor Yellow
    Write-Host "Some files may fail to extract." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "How to enable long paths:" -ForegroundColor Cyan
    Write-Host "  1. Run PowerShell as Administrator" -ForegroundColor Cyan
    Write-Host "  2. Run:" -ForegroundColor Cyan
    Write-Host "     New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force" -ForegroundColor Cyan
    Write-Host "  3. Reboot" -ForegroundColor Cyan
    Write-Host ""
}

# Prefer 7-Zip (better long-path handling)
$7zipPath = Get-Command 7z -ErrorAction SilentlyContinue
if ($7zipPath) {
    Write-Host "Extracting with 7-Zip..." -ForegroundColor Green
    & 7z x "`"$ArchiveFile`" -o`"$ExtractDir`"" -y | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Extraction completed!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Extracted folder: $ExtractDir" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. switch-release.ps1 $folderName (from OperatingEnv)" -ForegroundColor Yellow
        Write-Host "  2. start.ps1 (from OperatingEnv)" -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
    else {
        Write-Host "Error: 7-Zip extraction failed" -ForegroundColor Red
        exit 1
    }
}

# Fallback to tar if 7-Zip not found
$tarPath = Get-Command tar -ErrorAction SilentlyContinue
if ($tarPath) {
    Write-Host "Extracting with tar..." -ForegroundColor Green
    
    # tar supports long paths, but --force-local helps on Windows
    $process = Start-Process -FilePath "tar" -ArgumentList @("-xzf", "`"$ArchiveFile`"", "-C", "`"$ExtractDir`"", "--force-local") -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Extraction completed!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Extracted folder: $ExtractDir" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. switch-release.ps1 $folderName (from OperatingEnv)" -ForegroundColor Yellow
        Write-Host "  2. start.ps1 (from OperatingEnv)" -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
    else {
        Write-Host "Error: tar extraction failed (Exit Code: $($process.ExitCode))" -ForegroundColor Red
        exit 1
    }
}

# Neither 7-Zip nor tar found
Write-Host "Error: 7-Zip or tar is not installed." -ForegroundColor Red
Write-Host ""
Write-Host "How to resolve:" -ForegroundColor Yellow
Write-Host "  1. Install 7-Zip (recommended): https://www.7-zip.org/" -ForegroundColor Yellow
Write-Host "  2. Or use built-in tar on Windows 10+." -ForegroundColor Yellow
Write-Host ""
exit 1

