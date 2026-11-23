#!/bin/bash
# env-config.sh
# OperatingEnv 스크립트 공통 설정.
# 우선순위: 프로세스 환경변수 > shared/.env > 기본값
# 사용: . "$OP_ENV_ROOT/env-config.sh"
#       op_env_load "$OP_ENV_ROOT"

op_env_get() {
    local key="$1"
    local def="${2:-}"
    local from_proc=""
    local line keypart val

    from_proc="$(printenv "$key" 2>/dev/null || true)"
    if [ -n "$from_proc" ]; then
        printf '%s' "$from_proc"
        return 0
    fi

    if [ -n "${OP_ENV_FILE:-}" ] && [ -f "$OP_ENV_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            line="${line%$'\r'}"
            line="${line#$'\xef\xbb\xbf'}"
            case "$line" in
                ''|\#*) continue ;;
            esac
            keypart="${line%%=*}"
            keypart="${keypart%"${keypart##*[![:space:]]}"}"
            if [ "$keypart" != "$key" ]; then
                continue
            fi
            val="${line#*=}"
            val="${val#"${val%%[![:space:]]*}"}"
            val="${val%"${val##*[![:space:]]}"}"
            val="${val%$'\r'}"
            case "$val" in
                \"*\") val="${val#\"}"; val="${val%\"}" ;;
                \'*\') val="${val#\'}"; val="${val%\'}" ;;
            esac
            printf '%s' "$val"
            return 0
        done < "$OP_ENV_FILE"
    fi

    printf '%s' "$def"
    return 0
}

op_env_load() {
    local root="$1"

    OP_ENV_FILE="$root/shared/.env"
    OP_PM2_APP_NAME="$(op_env_get PM2_APP_NAME "")"
    if [ -z "$OP_PM2_APP_NAME" ]; then
        OP_PM2_APP_NAME="web-server"
    fi
    OP_APP_ENTRY="$(op_env_get APP_ENTRY "standalone-server.mjs")"
    OP_APP_SERVER_JS="$(op_env_get APP_SERVER_JS "server.js")"
    OP_ARCHIVE_PREFIX="$(op_env_get ARCHIVE_PREFIX "standalone-deploy")"
    OP_APP_PORT="$(op_env_get APP_PORT "")"
    return 0
}

op_env_pm2_save() {
    local root="$1"
    if ! command -v node >/dev/null 2>&1 || ! command -v pm2 >/dev/null 2>&1; then
        echo "  PM2 save를 건너뜁니다. node 또는 pm2가 없습니다."
        return 0
    fi
    node "$root/pm2-save-if-needed.js"
}
