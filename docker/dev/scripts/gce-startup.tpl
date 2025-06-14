#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

echo "[1] APT 업데이트"
sudo apt update -y && sudo apt upgrade -y

echo "[2] 기본 패키지 설치"
sudo apt install -y unzip nginx
(
  sudo apt-get install -y nvidia-driver-570
) &
(
  sudo mkdir -p ~/.aws /home/ubuntu/.aws
  echo "[2-1] AWS CLI 설치 및 자격증명 설정"
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
) &
(
  echo "[2-2] Docker 설치"
  curl -fsSL https://get.docker.com | sudo bash
  # Docker 유저 권한 부여
  sudo usermod -aG docker ubuntu
  newgrp docker
)
wait  # 병렬 설치 모두 완료될 때까지 대기

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

echo "[3] UFW 방화벽 열기"
sudo ufw allow OpenSSH
sudo ufw allow 8000
sudo ufw allow 8001
sudo ufw --force enable

echo "[4] 디스크 마운트 시작"
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

echo "[5] Python3.12 및 가상환경 구성"
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
if mountpoint -q ${MOUNT_DIR} && [ ! -d "${MOUNT_DIR}/aya-expanse-8b" ]; then
  huggingface-cli login --token "${HF_TOKEN}"
  huggingface-cli download CohereLabs/aya-expanse-8b \
    --local-dir "${MOUNT_DIR}/aya-expanse-8b" \
    --local-dir-use-symlinks False
fi

sudo chown -R ubuntu:ubuntu ${MOUNT_DIR}
deactivate
EOF

echo "[6] 환경변수 파일 및 compose 폴더 다운로드"

# .env 다운로드 및 실행
aws s3 cp s3://s3-careerbee-dev-infra/terraform.tfvars.enc terraform.tfvars.enc
openssl aes-256-cbc -d -salt -pbkdf2 -in terraform.tfvars.enc -out /home/ubuntu/.env -k "${DEV_TFVARS_ENC_PW}"
chmod 600 /home/ubuntu/.env
chown ubuntu:ubuntu /home/ubuntu
source /home/ubuntu/.env

# compose 폴더 다운로드
mkdir -p /home/ubuntu/compose/gcp
aws s3 cp s3://s3-careerbee-dev-infra/compose/gcp /home/ubuntu/compose/gcp --recursive

echo "[6-1] fluent-bit 실행"
cd /home/ubuntu/compose/gcp/fluent-bit
docker compose up -d

echo "[7] ECR 최신 이미지 기반 AI 실행"

# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

echo "[7-1] VLLM 실행"
docker run --gpus all --rm -it \
  --name VLLM \
  --log-driver=awslogs \
  --log-opt awslogs-region=ap-northeast-2 \
  --log-opt awslogs-group=vllm \
  --log-opt awslogs-stream=GCE-vllm-$(date +%Y-%m-%d) \
  -v ${MOUNT_DIR}/aya-expanse-8b:/model \
  -p 8001:8001 \
  vllm/vllm:latest \
  python3 -m vllm.entrypoints.api_server \
    --model /model \
    --tokenizer /model \
    --dtype bfloat16 \
    --max-model-len 4096 \
    --port 8001 \
    --gpu-memory-utilization 0.85

echo "[7-2] UVICORN 실행"
AI_TAG=$(aws ecr describe-images \
  --repository-name ai-server \
  --region ${AWS_DEFAULT_REGION} \
  --query 'reverse(sort_by(imageDetails[?imageTags != `null` && length(imageTags) > `0` && !contains(imageTags[0], `cache`)], &imagePushedAt))[0].imageTags[0]' \
  --output text)
docker pull ${ECR_REGISTRY}/ai-server:\$AI_TAG
docker run -d \
  --name ai-server \
  --log-driver=awslogs \
  --log-opt awslogs-region=ap-northeast-2 \
  --log-opt awslogs-group=uvicorn \
  --log-opt awslogs-stream=GCE-uvicorn-$(date +%Y-%m-%d) \
  -p 8000:8000 \
  --env-file /home/ubuntu/.env \
  ${ECR_REGISTRY}/ai-server:\$AI_TAG

echo "[8] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/gce" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2