#!/bin/bash
set -e

echo "[db_restore.sh] 복원 스크립트 실행 시작"

LATEST_BACKUP=$(aws s3 ls s3-careerbee-dev-infra/db/ | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
  echo "❌ 최신 백업 파일을 찾을 수 없습니다."
  exit 1
fi

echo "🗂️ 최신 백업 파일: $LATEST_BACKUP"

aws s3 cp s3://s3-careerbee-dev-infra/db/$LATEST_BACKUP $LATEST_BACKUP # /home/ubuntu/webhook

mysql -h 192.168.210.10 -u "${DB_USERNAME}" -p"${DB_PASSWORD}" ${DB_NAME} < "$LATEST_BACKUP"

echo "✅ 복원 완료"