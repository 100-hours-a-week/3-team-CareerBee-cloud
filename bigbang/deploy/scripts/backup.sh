#!/bin/bash
set -euo pipefail
source ./app-variables.sh
exec > >(gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' >> ../logs/backup.log) 2>&1

echo "🔧 백업 시작..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
# 1️⃣ 서버 내부 백업 작업
echo "🔹 원격 서버 백업 생성 중..."
ssh -i ${SSH_KEY} ubuntu@$SERVER_IP <<EOF
  set -euo pipefail
  mkdir -p ~/tmp

  echo "  📦 MySQL 덤프 생성 중..."
  if ! mysqldump -u root -p"${DB_PASSWORD}" "${DB_NAME}" | gsutil cp - "$BUCKET/mysql/careerbee_backup_${TIMESTAMP}.sql"; then
    echo "❌ MySQL 백업 실패"
    exit 1
  fi

  echo "  🔐 SSL 인증서 백업 중..."
  sudo tar czf ~/tmp/cert-backup.tar.gz /etc/letsencrypt/live/${DOMAIN} /etc/letsencrypt/archive/${DOMAIN} /etc/letsencrypt/renewal/${DOMAIN}.conf /etc/letsencrypt/options-ssl-nginx.conf /etc/letsencrypt/ssl-dhparams.pem|| echo "⚠️ 인증서 압축 실패, 파일이 없을 수 있음"
  gsutil cp ~/tmp/cert-backup.tar.gz $BUCKET/ssl/cert-backup_${TIMESTAMP}.tar.gz
  rm -f ~/tmp/cert-backup.tar.gz

  echo "✅ 서버 백업 파일 생성 완료"
  
  echo "🔹 GCS 업로드 결과 확인 중..."
  gsutil ls "${BUCKET}/mysql/" | grep "careerbee_backup_${TIMESTAMP}.sql" >/dev/null \
    && echo "✅ MySQL 백업 GCS 업로드 완료" || echo "❌ MySQL 백업 GCS 업로드 실패"
  gsutil ls "${BUCKET}/ssl/" | grep "cert-backup_${TIMESTAMP}.tar.gz" >/dev/null \
    && echo "✅ 인증서 GCS 업로드 완료" || echo "❌ 인증서 GCS 업로드 실패"

  echo "🎉 백업 스크립트 완료!"
EOF