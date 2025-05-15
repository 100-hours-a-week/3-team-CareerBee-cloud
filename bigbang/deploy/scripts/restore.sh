#!/bin/bash
set -euo pipefail
source ./app-variables.sh
# 키 캐시 삭제
ssh-keygen -R $SERVER_IP || true
# 로그 설정
exec > >(gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' >> ../logs/restore.log) 2>&1

echo "🔁 복원 스크립트 시작..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

ssh -i ${SSH_KEY} ubuntu@$SERVER_IP <<EOF
  set -euo pipefail
  mkdir -p ~/tmp

  echo "========================================="
  echo "🔹 MySQL 복원 시작"
  echo "========================================="

  LATEST_SQL_FILE=\$(gsutil ls ${BUCKET_BACKUP}/mysql/ | sort | tail -n 1 || true)

  if [ -z "\${LATEST_SQL_FILE:-}" ]; then
    echo "❌ MySQL 백업 파일이 존재하지 않습니다. 복원을 건너뜁니다."
  else
    echo "📥 SQL 백업 다운로드: \$LATEST_SQL_FILE"
    gsutil cp "\$LATEST_SQL_FILE" ~/tmp/restore.sql

    echo "🛠️ MySQL 복원 실행 중..."
    if sudo mysql -uroot -p"${DB_PASSWORD}" "${DB_NAME}" < ~/tmp/restore.sql; then
      echo "✅ MySQL 복원 완료"

      echo "📊 복원된 테이블 정보:"
      sudo mysql -uroot -p"${DB_PASSWORD}" -e "USE ${DB_NAME}; SHOW TABLES;" | tail -n +2 | while read table; do
        count=\$(sudo mysql -uroot -p"${DB_PASSWORD}" -e "SELECT COUNT(*) FROM ${DB_NAME}.\\\\`\${table}\\\\\`;" | tail -n 1)
        echo " - \${table}: \${count} rows"
      done
    else
      echo "❌ MySQL 복원 실패"
    fi
  fi

  echo "========================================="
  echo "🔹 SSL 인증서 복원 시작"
  echo "========================================="

  LATEST_CERT_FILE=\$(gsutil ls ${BUCKET_BACKUP}/ssl/cert-backup_*.tar.gz | sort | tail -n 1 || true)

  if [ -z "\${LATEST_CERT_FILE:-}" ]; then
    echo "⚠️ 인증서 백업 파일이 존재하지 않습니다. 복원을 건너뜁니다."
  else
    echo "📥 인증서 다운로드: \$LATEST_CERT_FILE"
    gsutil cp "\$LATEST_CERT_FILE" ~/tmp/cert-backup.tar.gz

    echo "📦 인증서 압축 해제 중..."
    sudo tar xzf ~/tmp/cert-backup.tar.gz -C /

    echo "🔐 퍼미션 설정..."
    sudo chown -R root:root /etc/letsencrypt
    sudo find /etc/letsencrypt -type d -exec chmod 755 {} \;
    sudo find /etc/letsencrypt -type f -exec chmod 644 {} \;

    echo "🔁 nginx 재시작..."
    sudo systemctl restart nginx && echo "✅ nginx 재시작 완료" || echo "⚠️ nginx 재시작 실패"
  fi

  echo "🎉 복원 스크립트 완료!"
EOF