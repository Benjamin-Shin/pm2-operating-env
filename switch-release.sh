#!/bin/bash
# switch-release.sh
# Current junction을 지정한 릴리즈 폴더로 전환 후 PM2 reload
# 사용법: ./switch-release.sh 20250306
# 히스토리: 2025-03 - 최초 생성 (OperatingEnv 배포 구조)
set -e

RELEASE_FOLDER="$1"
if [ -z "$RELEASE_FOLDER" ]; then
    echo "사용법: $0 <릴리즈폴더> (예: 20250306)"
    exit 1
fi

OP_ENV_ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env-config.sh
. "$OP_ENV_ROOT/env-config.sh"
op_env_load "$OP_ENV_ROOT"
RELEASES_DIR="$OP_ENV_ROOT/releases"
SHARED_DIR="$OP_ENV_ROOT/shared"
CURRENT_PATH="$OP_ENV_ROOT/Current"
TARGET_PATH="$RELEASES_DIR/$RELEASE_FOLDER"

if [ ! -d "$TARGET_PATH" ]; then
    echo "오류: 릴리즈 폴더가 없습니다: $TARGET_PATH"
    exit 1
fi

if [ ! -f "$TARGET_PATH/$OP_APP_ENTRY" ]; then
    echo "경고: $OP_APP_ENTRY 가 없습니다. 빌드를 해당 폴더에 풀었는지 확인하세요."
fi

# shared/runtime-config.json → 릴리즈 폴더로 복사
if [ -f "$SHARED_DIR/runtime-config.json" ]; then
    cp "$SHARED_DIR/runtime-config.json" "$TARGET_PATH/"
    echo "  runtime-config.json 복사 완료"
fi

# 기존 Current 제거 (symlink/junction)
if [ -e "$CURRENT_PATH" ]; then
    rm -f "$CURRENT_PATH"
    echo "  기존 Current 링크 제거"
fi

# symlink 생성 (Linux/macOS) - Windows Git Bash에서는 ln -s 사용
ln -s "$TARGET_PATH" "$CURRENT_PATH"
echo "  Current -> releases/$RELEASE_FOLDER 링크 생성"

# PM2 reload
if command -v pm2 &> /dev/null; then
    if pm2 list 2>/dev/null | grep -qF "$OP_PM2_APP_NAME"; then
        cd "$OP_ENV_ROOT"
        pm2 reload ecosystem.config.js
        echo "  PM2 reload 완료 ($OP_PM2_APP_NAME)"
        op_env_pm2_save "$OP_ENV_ROOT"
    else
        echo "  PM2 앱 '$OP_PM2_APP_NAME' 이 실행 중이 아닙니다. start.sh로 시작하세요."
    fi
else
    echo "  PM2가 설치되지 않았습니다."
fi

echo ""
echo "릴리즈 전환 완료: $RELEASE_FOLDER"
