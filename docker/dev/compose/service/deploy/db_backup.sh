#!/bin/bash
set -e

echo "[db_backup.sh] 백업 스크립트 실행 시작"

TIMESTAMP=$(date +v%Y%m%d%H%M%S)
BACKUP_FILE="backup-${TIMESTAMP}.sql"

# 1. 백업 덤프 생성
mysqldump -h 192.168.210.10 -u "${DB_USERNAME}" -p"${DB_PASSWORD}" ${DB_NAME} > "$BACKUP_FILE"

# 2. S3 업로드
aws s3 cp "$BACKUP_FILE" s3://s3-careerbee-dev-infra/db/"$BACKUP_FILE"

# 3. 로컬 백업 파일 삭제 (선택)
rm -f "$BACKUP_FILE"

echo "✅ 백업 완료 → s3://s3-careerbee-dev-infra/db/$BACKUP_FILE"