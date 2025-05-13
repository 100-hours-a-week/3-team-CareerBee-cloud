#!/bin/bash
set -euo pipefail
source ./app-variables.sh
# 키 캐시 삭제
ssh-keygen -R $SERVER_IP || true
# 로그
exec > >(gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' >> ../logs/upload.log) 2>&1

# 🔄 MySQL 데이터베이스 복원
echo "========================================="
echo "🔹 MySQL 백업 데이터 복원 중..."
echo "========================================="

# 백업 파일 GCS에서 다운로드
if sudo gsutil cp ${BUCKET}/mysql/careerbee_backup.sql ~/tmp/; then
    echo "✅ 백업 파일 다운로드 완료."

    # 복원 실행
    if sudo mysql -uroot -p${DB_PASSWORD} ${DB_NAME} < ~/tmp/careerbee_backup.sql; then
        echo "========================================="
        echo "✅ MySQL 데이터 복원 성공!"
        echo "========================================="

        # 복원된 테이블과 레코드 수 확인
        echo "📊 복원된 테이블 정보:"
        sudo mysql -uroot -p${DB_PASSWORD} -e "USE ${DB_NAME}; SHOW TABLES;" | tail -n +2 | while read table; do
            count=$(sudo mysql -uroot -p${DB_PASSWORD} -e "SELECT COUNT(*) FROM ${DB_NAME}.\`${table}\`;" | tail -n 1)
            echo " - ${table}: ${count} rows"
        done

    else
        echo "⚠️ MySQL 복원 실패"
    fi
else
    echo "⚠️ 백업 SQL 파일을 GCS에서 찾을 수 없습니다."
fi