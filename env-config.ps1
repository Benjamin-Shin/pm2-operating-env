# env-config.ps1
# OperatingEnv 스크립트 공통 설정.
# 우선순위: 프로세스 환경변수 > shared\.env > 기본값
# 사용: . (Join-Path $OpEnvRoot "env-config.ps1")
#       $cfg = Get-OpEnvSettings -OpEnvRoot $OpEnvRoot

function Read-DotEnvFile {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        $t = $_.Trim().TrimStart([char]0xFEFF)
        if (-not $t -or $t.StartsWith("#")) { return }
        $eq = $t.IndexOf("=")
        if ($eq -lt 1) { return }
        $key = $t.Substring(0, $eq).Trim()
        $val = $t.Substring($eq + 1).Trim()
        if ($val.Length -ge 2) {
            $q = $val[0]
            if (($q -eq '"' -or $q -eq "'") -and $val.EndsWith([string]$q)) {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }
        $map[$key] = $val
    }
    return $map
}

function Get-OpEnvValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$Default = ""
    )

    $proc = [Environment]::GetEnvironmentVariable($Key)
    if (-not [string]::IsNullOrWhiteSpace($proc)) {
        return $proc.Trim()
    }
    if ($Map -and $Map.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$Map[$Key])) {
        return [string]$Map[$Key]
    }
    return $Default
}

function Get-OpEnvPm2Name {
    param([hashtable]$Map)

    $named = Get-OpEnvValue $Map "PM2_APP_NAME" ""
    if (-not [string]::IsNullOrWhiteSpace($named)) {
        return $named
    }
    return "web-server"
}

function Get-OpEnvSettings {
    param([Parameter(Mandatory = $true)][string]$OpEnvRoot)

    $envFile = Join-Path $OpEnvRoot "shared\.env"
    $map = Read-DotEnvFile $envFile

    [pscustomobject]@{
        EnvMap        = $map
        EnvFile       = $envFile
        Pm2AppName    = Get-OpEnvPm2Name $map
        AppEntry      = Get-OpEnvValue $map "APP_ENTRY" "standalone-server.mjs"
        AppServerJs   = Get-OpEnvValue $map "APP_SERVER_JS" "server.js"
        ArchivePrefix = Get-OpEnvValue $map "ARCHIVE_PREFIX" "standalone-deploy"
        AppPort       = Get-OpEnvValue $map "APP_PORT" ""
    }
}

function Save-OpEnvPm2 {
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
        Write-Host "  PM2 save를 건너뜁니다. node 또는 pm2가 없습니다."
        return
    }

    $script = Join-Path $PSScriptRoot "pm2-save-if-needed.js"
    & node $script
    if ($LASTEXITCODE -ne 0) {
        Write-Error "pm2 save 실패 (exit $LASTEXITCODE)"
    }
}
