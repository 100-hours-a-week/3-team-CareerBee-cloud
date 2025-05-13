#!/bin/bash
source ./app-variables.sh
# 로그
exec > >(gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' >> ../logs/setup.log) 2>&1
# 키 캐시 삭제
ssh-keygen -R $SERVER_IP

echo "========================================="
echo "🔧 GCE 초기 환경 설정 시작..."
echo "========================================="

ssh -i $SSH_KEY ubuntu@$SERVER_IP <<EOF
# 1. 시스템 업데이트
sudo apt update -y && sudo apt upgrade -y

# 2. 필수 패키지
sudo apt install -y curl git unzip build-essential ca-certificates gnupg lsb-release software-properties-common

# GPU 드라이버 설치
sudo apt-get install -y nvidia-driver-570

# 2-1. GCP Ops Agent 설치 (메모리/디스크 모니터링 활성화)
echo "========================================="
echo "🔹 GCP Ops Agent 설치 중..."
echo "========================================="

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

sudo systemctl enable google-cloud-ops-agent
sudo systemctl restart google-cloud-ops-agent

echo "========================================="
echo "✅ GCP Ops Agent 설치 완료. 메모리 및 디스크 모니터링 가능."
echo "========================================="

# 3. 로그, 릴리즈, 임시 디렉토리 추가 & 디스크 마운트
mkdir -p ~/logs ~/release ~/tmp
sudo chown -R ubuntu:ubuntu ~/release

# 파티션 및 파일 시스템 포맷 여부 확인
if [ -z "/$(sudo lsblk -f | grep ${DEVICE_NAME})" ]; then
  echo "========================================="
  echo "⚠️ 디바이스 ${DEVICE_NAME}를 찾을 수 없습니다. 마운트를 건너뜁니다."
  echo "========================================="
else
  # 포맷되지 않았으면 ext4로 포맷
  if ! sudo blkid ${DEVICE_NAME}; then
    echo "========================================="
    echo "🔸 디스크가 포맷되지 않아 ext4로 포맷합니다..."
    echo "========================================="
    sudo mkfs.ext4 -F ${DEVICE_NAME}
  fi

  # 마운트 디렉토리 생성 및 마운트
  sudo mkdir -p ${MOUNT_PATH}
  sudo mount ${DEVICE_NAME} ${MOUNT_PATH}
  sudo chown -R ubuntu:ubuntu ${MOUNT_PATH}

  # /etc/fstab에 UUID 등록
  UUID=$(sudo blkid -s UUID -o value ${DEVICE_NAME})
  if [ -z "\$(grep "\${UUID}" /etc/fstab)" ]; then
    echo "UUID=\${UUID} ${MOUNT_PATH} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    sudo systemctl daemon-reload
  fi

  echo "========================================="
  echo "✅ 디스크가 ${MOUNT_PATH}에 마운트되었습니다."
  echo "========================================="
fi

# 4. Java 21 (OpenJDK 21)
echo "========================================="
echo "🔹 Java 21 설치 중..."
echo "========================================="
sudo apt update -y
sudo apt install -y openjdk-21-jdk gradle

# 5. MySQL 8.4.0
echo "========================================="
echo "🔹 MySQL 8.4.0 설치 중..."
echo "========================================="
sudo apt update -y
sudo apt install -y mysql-server

sudo systemctl enable mysql
sudo systemctl start mysql

# 🔥 bind-address 수정 (0.0.0.0으로 변경)
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || \
sudo bash -c "echo 'bind-address = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf"

sudo systemctl restart mysql

# MySQL root 비밀번호 설정 및 보안 강화
sudo mysql <<MYSQL_ROOT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
MYSQL_ROOT

echo "========================================="
echo "🔐 root 비밀번호 설정 완료."
echo "========================================="

# 🔥 DB 및 사용자 생성
echo "========================================="
echo "🔹 MySQL 데이터베이스 및 사용자 생성 중..."
echo "========================================="
sudo mysql -uroot -p${DB_PASSWORD} <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
echo "========================================="
echo "✅ 데이터베이스(${DB_NAME})와 사용자(${DB_USERNAME}) 생성 완료."
echo "========================================="


# 6. Node.js 22.14.0
echo "========================================="
echo "🔹 Node.js 22.14.0 설치 중..."
echo "========================================="
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pnpm@10.7.1

# 7. Python 3.12.8 & vLLM
echo "========================================="
echo "🔹 Python 3.12.8 및 vLLM 설치 중..."
echo "========================================="
sudo apt update -y
sudo apt install -y python3.12 python3.12-venv python3.12-dev
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
python3.12 -m venv ~/venv
# 가상환경 활성화
source ~/venv/bin/activate

# huggingface-cli 및 vLLM 설치
pip install --upgrade pip
pip install huggingface_hub
huggingface-cli login --token $HF_TOKEN
huggingface-cli download mistralai/Mistral-7B-Instruct-v0.3 \
  --local-dir /mnt/data/mistral-7b \
  --local-dir-use-symlinks False

# 가상환경 비활성화
deactivate

# 8. Nginx + HTML 폴더
sudo apt install -y nginx
sudo mkdir -p /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html

# 8-1. Certbot 및 HTTPS 인증서 발급
echo "========================================="
echo "🔹 Certbot 설치 및 HTTPS 인증서 발급 중..."
echo "========================================="
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# 인증서가 없다면 GCS에서 복원 시도
if ! sudo test -d "${CERT_BASE_PATH}/live/${DOMAIN}"; then

  echo "========================================="
  echo "🔍 GCS에 인증서 백업이 존재하는지 확인 중..."
  echo "========================================="

  if gsutil ls "${BUCKET_BACKUP}/ssl/live/${DOMAIN}/" >/dev/null 2>&1; then

    echo "========================================="
    echo "🔄 인증서 백업이 확인되어 복원을 시작합니다."
    echo "========================================="

    # 디렉토리 생성
    sudo mkdir -p ${CERT_BASE_PATH}/{live,archive,renewal}

    # 인증서 복원
    if sudo gsutil -m cp -r \
      ${BUCKET_BACKUP}/ssl/live/${DOMAIN} ${CERT_BASE_PATH}/live/ &&
       sudo gsutil -m cp -r \
      ${BUCKET_BACKUP}/ssl/archive/${DOMAIN} ${CERT_BASE_PATH}/archive/ &&
       sudo gsutil cp \
      ${BUCKET_BACKUP}/ssl/renewal/${DOMAIN}.conf ${CERT_BASE_PATH}/renewal/ &&
       sudo gsutil cp \
      ${BUCKET_BACKUP}/ssl/options-ssl-nginx.conf ${CERT_BASE_PATH}/ &&
       sudo gsutil cp \
      ${BUCKET_BACKUP}/ssl/ssl-dhparams.pem ${CERT_BASE_PATH}/; then

      sudo chown -R root:root ${CERT_BASE_PATH}

      echo "========================================="
      echo "✅ 인증서 복원 완료."
      echo "========================================="

    else
      echo "========================================="
      echo "❌ 인증서 복원 중 일부 파일이 누락되어 실패했습니다."
      echo "========================================="
    fi

  else
    echo "========================================="
    echo "⚠️ GCS에서 인증서 백업을 찾을 수 없습니다. Certbot으로 신규 발급을 시도합니다."
    echo "========================================="

    sudo certbot --nginx --non-interactive --agree-tos --no-redirect \
      -m ${EMAIL} \
      -d ${DOMAIN} -d www.${DOMAIN} -d api.${DOMAIN} || {
        echo "❌ Certbot 인증서 발급 실패."
      }
  fi

else
  echo "========================================="
  echo "✅ 인증서가 이미 존재합니다. Certbot 실행을 건너뜁니다."
  echo "========================================="
fi

# 8-2. Nginx SPA fallback 설정 + HTTPS listen 추가
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF_NGINX
# HTTP → HTTPS 리디렉트
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name *.${DOMAIN};

    return 301 https://\\\$host\\\$request_uri;
}

# HTTPS 블록
server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    return 301 https://www.${DOMAIN}\\\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name www.${DOMAIN};

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files \\\$uri \\\$uri/ /index.html;
    }
}

server {
    listen 443 ssl;
    server_name api.${DOMAIN};

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
    }
}
EOF_NGINX

echo "========================================="
echo "✅ HTTPS 설정 추가 완료."
echo "========================================="

sudo nginx -t && sudo systemctl reload nginx

echo "========================================="
echo "✅ HTTPS 인증 완료 및 자동 갱신 설정됨."
echo "========================================="

# 9. UFW 설정
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3306
sudo ufw allow 8000
sudo ufw allow 8080
sudo ufw allow 5173
sudo ufw --force enable

# 10. cron 설치 및 설정
echo "========================================="
echo "🔹 cron 설치 및 AI 서버 예약 작업 등록 중..."
echo "========================================="

sudo apt install -y cron
sudo systemctl enable --now cron

CRON_CONTENT=""

if [ -d "/mnt/data/mistral-7b" ]; then
    CRON_CONTENT="\$CRON_CONTENT
@reboot nohup python3 -m vllm.entrypoints.openai.api_server \
--model /mnt/data/mistral-7b \
--dtype float16 \
--port 8000 \
--gpu-memory-utilization 0.9 > ~/logs/vllm.log 2>&1 &"
else
    echo "========================================="
    echo "⚠️ /mnt/data/mistral-7b 디렉터리가 없어 vllm 크론 잡을 등록하지 않습니다."
    echo "========================================="
fi

CRON_CONTENT="\$CRON_CONTENT
0 18 * * 1 /usr/bin/python3 ~/ai-server/summarizer_pipeline/main.py >> ~/logs/ai-cron.log 2>&1"

if [ -n "\$CRON_CONTENT" ]; then
    ( crontab -l 2>/dev/null | grep -v "vllm" | grep -v "main.py" ; echo "\$CRON_CONTENT" ) | crontab -
    echo "========================================="
    echo "✅ crontab 등록 완료: 매주 월요일 18:00에 main.py 실행"
    echo "========================================="
else
    echo "========================================="
    echo "⚠️ 등록할 크론 작업이 없어 crontab을 수정하지 않습니다."
    echo "========================================="
fi

# 11. 버전 확인 로그
echo "========================================="
echo "🔍 전체 설치/설정 요약 검증 중..."
echo "========================================="

echo "[✔] 디스크 마운트 상태:"
if mountpoint -q ${MOUNT_PATH}; then
  echo "✅ 디스크가 ${MOUNT_PATH}에 마운트되어 있습니다."
  df -h ${MOUNT_PATH}
else
  echo "❌ 디스크가 ${MOUNT_PATH}에 마운트되지 않았습니다. 수동 확인 필요."
  lsblk -f
fi

echo "[✔] Java 버전:"
java -version

echo "[✔] MySQL 상태:"
sudo systemctl is-active --quiet mysql && echo "MySQL 실행 중" || echo "❌ MySQL 비활성 상태"

echo "[✔] MySQL 사용자 및 DB 확인:"
sudo mysql -uroot -p${DB_PASSWORD} -e "SHOW DATABASES LIKE '${DB_NAME}';"
sudo mysql -uroot -p${DB_PASSWORD} -e "SELECT User, Host FROM mysql.user WHERE User='${DB_USERNAME}';"

echo "[✔] Node.js & pnpm 버전:"
node -v
pnpm -v

echo "[✔] Python3 버전:"
python3 --version

echo "[✔] vLLM 디렉토리 확인:"
[ -d "/mnt/data/mistral-7b" ] && echo "/mnt/data/mistral-7b 디렉토리 존재함" || echo "❌ /mnt/data/mistral-7b 디렉토리 없음"

echo "[✔] Nginx 상태:"
sudo systemctl is-active --quiet nginx && echo "Nginx 실행 중" || echo "❌ Nginx 비활성 상태"

echo "[✔] HTTPS 인증서:"
if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  echo "인증서 존재함"
else
  echo "❌ 인증서 없음"
fi

echo "[✔] UFW 방화벽 상태:"
sudo ufw status verbose

echo "[✔] 크론탭 등록 상태:"
crontab -l

echo "========================================="
echo "🎯 전체 설치/설정 검증 완료! 필요한 항목은 로그를 확인하세요."
echo "========================================="

echo "========================================="
echo "🎉 초기 설정 완료! 서버를 재부팅하는 것이 좋습니다."
echo "========================================="
EOF