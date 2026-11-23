#!/bin/bash
# start.sh - OperatingEnv에서 PM2로 웹서버 시작
# 히스토리: 2025-03 - 최초 생성
set -e
OP_ENV_ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env-config.sh
. "$OP_ENV_ROOT/env-config.sh"
op_env_load "$OP_ENV_ROOT"

if [ ! -f "$OP_ENV_ROOT/shared/.env" ]; then
    echo "오류: shared/.env 파일이 없습니다. shared/env.example을 복사하여 .env를 생성하세요."
    exit 1
fi

if [ ! -e "$OP_ENV_ROOT/Current" ]; then
    echo "오류: Current 링크가 없습니다. 먼저 switch-release.sh로 릴리즈를 지정하세요."
    exit 1
fi

if [ ! -f "$OP_ENV_ROOT/Current/$OP_APP_ENTRY" ]; then
    echo "오류: Current/$OP_APP_ENTRY 가 없습니다. 빌드를 releases/<날짜>에 풀고 switch-release로 전환하세요."
    exit 1
fi

cd "$OP_ENV_ROOT"
pm2 start ecosystem.config.js
op_env_pm2_save "$OP_ENV_ROOT"
echo ""
echo "웹서버가 시작되었습니다 ($OP_PM2_APP_NAME). pm2 status / pm2 logs $OP_PM2_APP_NAME 로 확인하세요."
