#!/bin/bash
# ESO AddOn 자동 배포 스크립트
# 사용법: bash deploy.sh

SRC="$(dirname "$0")/ZZZ_AddOnInspector"
DEST="C:/Users/user/Documents/Elder Scrolls Online/live/AddOns/ZZZ_AddOnInspector"

if [ ! -d "$SRC" ]; then
    echo "[ERROR] 소스 폴더를 찾을 수 없음: $SRC"
    exit 1
fi

# 대상 폴더 생성 (없으면)
mkdir -p "$DEST"

# 파일 단위 복사 (rm -rf 대신 — 게임 실행 중 폴더 잠금 방지)
cp -f "$SRC"/* "$DEST"/

# 매니페스트 CRLF 변환 (ESO 요구사항)
if [ -f "$DEST/ZZZ_AddOnInspector.txt" ]; then
    sed -i 's/\r$//' "$DEST/ZZZ_AddOnInspector.txt"
    sed -i 's/$/\r/' "$DEST/ZZZ_AddOnInspector.txt"
    echo "[OK] 매니페스트 CRLF 변환 완료"
fi

echo "[OK] 배포 완료 → $DEST"
ls -la "$DEST"
echo ""
echo "게임 재시작 필요 (/reloadui는 코드 변경 반영 안 됨)"
