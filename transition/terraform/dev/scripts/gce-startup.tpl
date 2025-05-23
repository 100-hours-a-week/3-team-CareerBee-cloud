#!/bin/bash
# set -e

# 1. 시스템 업데이트 및 필수 패키지
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl unzip nginx
# sudo apt-get install -y nvidia-driver-570

# aws-cli 설치
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
# AWS 인증 설정
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"

# 2. 로그, 릴리즈, 임시 디렉토리 추가 & 디스크 마운트
sudo mkdir -p /home/ubuntu/logs /home/ubuntu/release /home/ubuntu/tmp
sudo chown -R ubuntu:ubuntu /home/ubuntu

# 3. 디스크 마운트
if sudo ls "${DEVICE_ID}" > /dev/null 2>&1; then
  if ! blkid "${DEVICE_ID}"; then
      sudo mkfs.ext4 -F "${DEVICE_ID}"
  fi

  sudo mkdir -p "${MOUNT_DIR}"
  sudo mount -o discard,defaults "${DEVICE_ID}" "${MOUNT_DIR}"
  sudo chown -R ubuntu:ubuntu "${MOUNT_DIR}"

  if ! grep -q "${DEVICE_ID}" /etc/fstab; then
      echo "${DEVICE_ID} ${MOUNT_DIR} ext4 discard,defaults,nofail 0 2" | sudo tee -a /etc/fstab
  fi
fi

# Google Cloud Ops Agent 설치
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

sudo systemctl enable google-cloud-ops-agent
sudo systemctl restart google-cloud-ops-agent

# 4. Certbot 설치
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# 인증서 복원 - S3에서 다운로드 (GCP용 dev-ai.${DOMAIN})
sudo mkdir -p /etc/letsencrypt/{live,archive,renewal}
sudo mkdir -p /etc/letsencrypt/live/dev-ai.${DOMAIN}
sudo mkdir -p /etc/letsencrypt/archive/dev-ai.${DOMAIN}

sudo -E aws s3 cp ${BUCKET_BACKUP}/gcp/live/dev-ai.${DOMAIN}/     /etc/letsencrypt/live/dev-ai.${DOMAIN}/     --recursive
sudo -E aws s3 cp ${BUCKET_BACKUP}/gcp/archive/dev-ai.${DOMAIN}/  /etc/letsencrypt/archive/dev-ai.${DOMAIN}/  --recursive
sudo -E aws s3 cp ${BUCKET_BACKUP}/gcp/renewal/dev-ai.${DOMAIN}.conf /etc/letsencrypt/renewal/
sudo -E aws s3 cp ${BUCKET_BACKUP}/gcp/options-ssl-nginx.conf /etc/letsencrypt/
sudo -E aws s3 cp ${BUCKET_BACKUP}/gcp/ssl-dhparams.pem /etc/letsencrypt/


# sudo certbot --nginx --non-interactive --agree-tos --no-redirect \
#   -m ${EMAIL} -d dev-ai.${DOMAIN}

# 5. NGINX 설정
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF_NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name dev-ai.${DOMAIN};

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name dev-ai.${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/dev-ai.${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dev-ai.${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF_NGINX

sudo nginx -t && sudo systemctl reload nginx

# 6. Python 3.12.8 & vLLM
sudo apt update -y
sudo apt install -y python3.12 python3.12-venv python3.12-dev build-essential cmake libmupdf-dev libopenblas-dev libglib2.0-dev
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Python 설치 완료 확인
until command -v python3.12 >/dev/null 2>&1; do
  sleep 2
done

# 가상환경 생성 경로 변경
python3.12 -m venv "${MOUNT_DIR}/venv"
sudo chown -R ubuntu:ubuntu "${MOUNT_DIR}/venv"

# 토큰 환경변수
export HF_TOKEN="${HF_TOKEN}"

# 가상환경 활성화
source "${MOUNT_DIR}/venv/bin/activate"

# huggingface-cli 및 vLLM 설치
pip install --upgrade pip
pip install huggingface_hub
huggingface-cli login --token "${HF_TOKEN}"
huggingface-cli download mistralai/Mistral-7B-Instruct-v0.3 \
  --local-dir "${MOUNT_DIR}/mistral-7b" \
  --local-dir-use-symlinks False

# 가상환경 비활성화
deactivate

# 7. 방화벽 열기 (GCP 콘솔 방화벽 설정과 중복될 수 있음)
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 8000
sudo ufw --force enable

# 8. cron 설치 및 설정
sudo apt install -y cron
sudo systemctl enable --now cron

if [ -d "${MOUNT_DIR}/mistral-7b" ]; then
    CRON_CONTENT=$(cat <<EOF
@reboot nohup ${MOUNT_DIR}/venv/bin/python3 -m vllm.entrypoints.openai.api_server --model ${MOUNT_DIR}/mistral-7b --dtype float16 --port 8000 --gpu-memory-utilization 0.9 > /home/ubuntu/logs/vllm.log 2>&1 &
0 18 * * 1 ${MOUNT_DIR}/venv/bin/python3 /home/ubuntu/ai-server/summarizer_pipeline/main.py >> /home/ubuntu/logs/ai-cron.log 2>&1
EOF
)
fi

if [ -n "$CRON_CONTENT" ]; then
    ( crontab -l 2>/dev/null | grep -v "vllm" | grep -v "main.py" ; echo "$CRON_CONTENT" ) | crontab -
fi

# 9. S3에서 배포 산출물 받아와 AI 서버 배포
LATEST_PATH=$(aws s3 ls "${S3_BUCKET_INFRA}/ai/" | awk '{print $2}' | sort | tail -n 1 | tr -d '/')
DEPLOY_PATH="${LATEST_PATH}"
DEPLOY_DIR="/home/ubuntu/release"

aws s3 cp "${S3_BUCKET_INFRA}/ai/${DEPLOY_PATH}/" "${DEPLOY_DIR}/" --recursive

source "${MOUNT_DIR}/venv/bin/activate"

pip install --upgrade pip
pip install --no-cache-dir --prefer-binary -r "${DEPLOY_DIR}/requirements.txt"

pkill -f "uvicorn" || true

cd "${DEPLOY_DIR}"
nohup "${MOUNT_DIR}/venv/bin/uvicorn" app.main:app --host 0.0.0.0 --port 8000 > /home/ubuntu/logs/ai.log 2>&1 &

deactivate

# 10. 버전 확인 로그
echo "[✔] 디스크 마운트 상태:"
if mountpoint -q ${MOUNT_DIR}; then
  echo "✅ 디스크가 ${MOUNT_DIR}에 마운트되어 있습니다."
  df -h ${MOUNT_DIR}
else
  echo "❌ 디스크가 ${MOUNT_DIR}에 마운트되지 않았습니다. 수동 확인 필요."
  lsblk -f
fi

echo "[✔] Python3 버전:"
python3 --version

echo "[✔] vLLM 디렉토리 확인:"
[ -d "${MOUNT_DIR}/mistral-7b" ] && echo "${MOUNT_DIR}/mistral-7b 디렉토리 존재함" || echo "❌ ${MOUNT_DIR}/mistral-7b 디렉토리 없음"

echo "[✔] Nginx 상태:"
sudo systemctl is-active --quiet nginx && echo "Nginx 실행 중" || echo "❌ Nginx 비활성 상태"

echo "[✔] HTTPS 인증서:"
if [ -f "/etc/letsencrypt/live/dev-ai.${DOMAIN}/fullchain.pem" ]; then
  echo "인증서 존재함"
else
  echo "❌ 인증서 없음"
fi

echo "[✔] UFW 방화벽 상태:"
sudo ufw status verbose

echo "[✔] 크론탭 등록 상태:"
crontab -l

# 배포 확인 로그
echo "[✔] AI 서버 실행 상태 확인:"
sleep 5
if pgrep -f "uvicorn" > /dev/null; then
  echo "✅ uvicorn 프로세스가 실행 중입니다."
else
  echo "❌ uvicorn 프로세스가 실행되고 있지 않습니다."
fi