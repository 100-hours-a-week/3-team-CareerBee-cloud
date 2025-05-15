#!/bin/bash
source ./app-variables.sh

ssh -i $SSH_KEY ubuntu@$SERVER_IP <<EOF
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
# 가상환경 활성화
source ~/venv/bin/activate

# huggingface-cli 및 vLLM 설치
pip install --upgrade pip
pip install huggingface_hub
huggingface-cli login --token ${HF_TOKEN}
huggingface-cli download mistralai/Mistral-7B-Instruct-v0.3 \
  --local-dir /mnt/data/mistral-7b \
  --local-dir-use-symlinks False

# 가상환경 비활성화
deactivate


# 인증서가 없다면 GCS에서 복원 시도
if ! sudo test -d "${CERT_BASE_PATH}/live/${DOMAIN}"; then
  
  echo "========================================="
  echo "🔄 인증서가 없어 GCS에서 복원을 시도합니다..."
  echo "========================================="
  
  sudo mkdir -p ${CERT_BASE_PATH}/{live,archive,renewal}

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
    echo "⚠️ GCS 인증서 복원 실패. Certbot으로 신규 발급을 시도합니다."
    echo "========================================="

    # Certbot 발급 시도
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


CRON_CONTENT=""

if [ -d "/mnt/data/mistral-7b" ]; then
    CRON_CONTENT="\${CRON_CONTENT}
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

CRON_CONTENT="\${CRON_CONTENT}
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
EOF