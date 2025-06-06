#!/bin/bash
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

echo "[1] APT 업데이트 및 기본 패키지 설치"
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl unzip nginx
(
  sudo apt-get install -y nvidia-driver-570
) &
(
  echo "[2] Certbot 설치"
  sudo snap install --classic certbot
  sudo ln -sf /snap/bin/certbot /usr/bin/certbot
) &
(
  echo "[3] Google Cloud Ops Agent 설치"
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  sudo bash add-google-cloud-ops-agent-repo.sh --also-install
  sudo systemctl enable google-cloud-ops-agent
  sudo systemctl restart google-cloud-ops-agent
) &
(
  sudo mkdir -p ~/.aws /home/ubuntu/.aws
  echo "[4] AWS CLI 설치 및 자격증명 설정"
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
) &

wait  # 병렬 설치 모두 완료될 때까지 대기

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
cat > ~/.aws/config <<EOF
[default]
region = ${AWS_DEFAULT_REGION}
output = json
EOF

cat > /home/ubuntu/.aws/credentials <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
cat > /home/ubuntu/.aws/config <<EOF
[default]
region = ${AWS_DEFAULT_REGION}
output = json
EOF

echo "[5] Fluent Bit 설치"
curl https://packages.fluentbit.io/fluentbit.key | gpg --dearmor | sudo tee /usr/share/keyrings/fluentbit-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/jammy jammy main" \
| sudo tee /etc/apt/sources.list.d/fluentbit.list
sudo apt update -y
sudo apt install td-agent-bit -y

sudo mkdir -p /var/log/fluent-bit/s3
sudo tee /etc/td-agent-bit/td-agent-bit.conf > /dev/null <<EOF
[SERVICE]
  Flush        5
  Daemon       Off
  Log_Level    info
  Parsers_File parsers.conf

[INPUT]
  Name   tail
  Path   /var/log/vLLM.log
  Tag    vLLM.log
  DB     /var/log/flb_tail.db
  Parser json
  Read_from_Head true
  
[INPUT]
  Name   tail
  Path   /var/log/uvicorn.log
  Tag    uvicorn.log
  DB     /var/log/flb_tail_uvicorn.db
  Parser json
  Read_from_Head true

[OUTPUT]
  Name s3
  Match vLLM.log
  bucket ${BUCKET_BACKUP_NAME}
  region ap-northeast-2
  total_file_size 5M
  upload_timeout 10s
  use_put_object On
  store_dir /var/log/fluent-bit/s3
  s3_key_format /logs/%Y-%m-%d/vLLM.log
  s3_key_format_tag_delimiters ""
  auto_retry_requests Off

[OUTPUT]
  Name s3
  Match uvicorn.log
  bucket ${BUCKET_BACKUP_NAME}
  region ap-northeast-2
  total_file_size 5M
  upload_timeout 10s
  use_put_object On
  store_dir /var/log/fluent-bit/s3
  s3_key_format /logs/%Y-%m-%d/uvicorn.log
  s3_key_format_tag_delimiters ""
  auto_retry_requests Off
EOF

sudo tee /etc/td-agent-bit/parsers.conf > /dev/null <<EOF
[PARSER]
  Name   json
  Format json
  Time_Key time
  Time_Format %Y-%m-%dT%H:%M:%S
EOF

sudo systemctl enable td-agent-bit
sudo systemctl restart td-agent-bit
sudo systemctl status td-agent-bit --no-pager

echo "[6] 디스크&S3(mount-s3) 마운트 시작"
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

mkdir -p /home/ubuntu/{logs,release,tmp/s3cache}
sudo chown -R ubuntu:ubuntu /home/ubuntu
wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
sudo apt install -y ./mount-s3.deb
rm -f ./mount-s3.deb
echo "user_allow_other" | sudo tee -a /etc/fuse.conf

sudo -u ubuntu bash <<EOF
mount-s3 ${BUCKET_BACKUP_NAME} /home/ubuntu/logs --prefix logs/ --region ap-northeast-2 --cache /home/ubuntu/tmp/s3cache --metadata-ttl 60   --allow-other   --allow-overwrite   --allow-delete   --incremental-upload
EOF

echo "[7] Python3.12 및 가상환경 구성"
sudo apt update -y
sudo apt install -y python3.12 python3.12-venv python3.12-dev build-essential cmake libmupdf-dev libopenblas-dev libglib2.0-dev
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Python 설치 완료 대기
until command -v python3.12 >/dev/null 2>&1; do
  sleep 2
done

# 가상환경 생성
if [ ! -d "${MOUNT_DIR}/venv" ]; then
  python3.12 -m venv ${MOUNT_DIR}/venv
  sudo chown -R ubuntu:ubuntu ${MOUNT_DIR}
fi

sudo -u ubuntu bash <<EOF
source ${MOUNT_DIR}/venv/bin/activate
pip install --upgrade pip
pip install huggingface_hub

# 모델 다운로드 (디스트 마운트 확인 시에만)
if mountpoint -q ${MOUNT_DIR} && [ ! -d "${MOUNT_DIR}/mistral-7b" ]; then
  huggingface-cli login --token "${HF_TOKEN}"
  huggingface-cli download mistralai/Mistral-7B-Instruct-v0.3 \
    --local-dir "${MOUNT_DIR}/mistral-7b" \
    --local-dir-use-symlinks False
fi

sudo chown -R ubuntu:ubuntu ${MOUNT_DIR}
deactivate
EOF

echo "[8] UFW 방화벽 열기"
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 8000
sudo ufw allow 8001
sudo ufw --force enable


echo "[9] Certbot 인증서 복원 시작"
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


echo "[10] NGINX 설정 구성"
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


echo "[11] 애플리케이션 배포 및 실행"
sudo touch /var/log/vLLM.log /var/log/uvicorn.log
sudo chown -R ubuntu:ubuntu /var/log/vLLM.log /var/log/uvicorn.log

sudo -u ubuntu bash <<EOF
aws s3 cp "$(aws s3 ls "${BUCKET_BACKUP}/ai/" | awk '{print $2}' | sort | tail -n 1 | sed 's#^#'"${BUCKET_BACKUP}/ai/"'#;s#/$##')" "${DEPLOY_DIR}/" --recursive
source ${MOUNT_DIR}/venv/bin/activate

pip install --upgrade pip setuptools wheel
pip install --no-cache-dir --no-binary PyMuPDF "PyMuPDF==1.22.3"
pip install --no-cache-dir --prefer-binary -r "${DEPLOY_DIR}/requirements.txt"

pkill -f "uvicorn" || true

nohup python3 -m vllm.entrypoints.openai.api_server \
    --model ${MOUNT_DIR}/mistral-7b \
    --dtype float16 \
    --port 8001 \
    --gpu-memory-utilization 0.9 > /var/log/vLLM.log 2>&1 &

cd "${DEPLOY_DIR}"
nohup ${MOUNT_DIR}/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 > /var/log/uvicorn.log 2>&1 &

deactivate
EOF

# 버전 확인 로그
echo "[12] 설치 확인 로그"
echo "[✔] Fluent Bit 상태 확인:"
if systemctl is-active --quiet td-agent-bit; then
  echo "✅ td-agent-bit 서비스 실행 중"
else
  echo "❌ td-agent-bit 서비스 실행 실패"
  journalctl -u td-agent-bit --no-pager | tail -n 20
fi

echo "[✔] 디스크 마운트 상태:"
if mountpoint -q ${MOUNT_DIR}; then
  echo "✅ 디스크가 ${MOUNT_DIR}에 마운트되어 있습니다."
  df -h ${MOUNT_DIR}
else
  echo "❌ 디스크가 ${MOUNT_DIR}에 마운트되지 않았습니다. 수동 확인 필요."
  lsblk -f
fi

echo "[✔] S3 마운트 상태:"
if mountpoint -q /home/ubuntu/logs; then
  echo "✅ S3가 /home/ubuntu/logs에 마운트되어 있습니다."
  df -h /home/ubuntu/logs
else
  echo "❌ S3가 /home/ubuntu/logs에 마운트되지 않았습니다. 수동 확인 필요."
  lsblk -f
fi

echo "[✔] NVIDIA 드라이버 상태 (nvidia-smi):"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  echo "❌ nvidia-smi 명령을 찾을 수 없습니다. 드라이버 설치 확인 필요."
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

# 배포 확인 로그
echo "[✔] AI 서버 실행 상태 확인:"
sleep 5
if pgrep -f "vllm.entrypoints.openai.api_server" > /dev/null; then
  echo "✅ vLLM API 서버가 실행 중입니다."
else
  echo "❌ vLLM API 서버가 실행되고 있지 않습니다."
fi

if pgrep -f "uvicorn" > /dev/null; then
  echo "✅ uvicorn 프로세스가 실행 중입니다."
else
  echo "❌ uvicorn 프로세스가 실행되고 있지 않습니다."
fi

touch /home/ubuntu/tmp/gce-startup.done

echo "[13] 권한 설정"
sudo chown -R ubuntu:ubuntu /home/ubuntu/{release,tmp} ${MOUNT_DIR}