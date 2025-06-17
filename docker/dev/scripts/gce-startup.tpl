#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

echo "[1] APT 업데이트 및 시간대 설정"
apt update -y && apt upgrade -y
timedatectl set-timezone Asia/Seoul

echo "[2] 기본 및 필수 패키지 설치"
apt install -y curl unzip openssl nginx
apt-get install -y nvidia-driver-570
apt install -y python3.12 python3.12-venv
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

echo "[2-1] AWS CLI 설치 및 자격증명 설정"
mkdir -p ~/.aws /home/ubuntu/.aws
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

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

echo "[2-2] Docker 설치"
curl -fsSL https://get.docker.com | bash

echo "[3] UFW 방화벽 열기"
ufw allow OpenSSH
ufw allow 8000
ufw allow 8001
ufw --force enable

echo "[4] 디스크 마운트 시작"
if ls "${DEVICE_ID}" > /dev/null 2>&1; then
  if ! blkid "${DEVICE_ID}"; then
      mkfs.ext4 -F "${DEVICE_ID}"
  fi

  mkdir -p "${MOUNT_DIR}"
  mount -o discard,defaults "${DEVICE_ID}" "${MOUNT_DIR}"

  if ! grep -q "${DEVICE_ID}" /etc/fstab; then
      echo "${DEVICE_ID} ${MOUNT_DIR} ext4 discard,defaults,nofail 0 2" | tee -a /etc/fstab
  fi
fi

####################################################################################################################

echo "[5] 가상환경 구성"
# Python 설치 완료 대기
until command -v python3.12 >/dev/null 2>&1; do
  sleep 2
done

# 가상환경 생성
if [ ! -d "${MOUNT_DIR}/venv" ]; then
  python3.12 -m venv ${MOUNT_DIR}/venv
fi

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

deactivate

####################################################################################################################

echo "[6] 환경변수 파일 및 compose 폴더 다운로드"
# .env 다운로드 및 실행
aws s3 cp s3://s3-careerbee-dev-infra/terraform.tfvars.enc ./terraform.tfvars.enc
openssl version # debug
openssl aes-256-cbc -d -salt -pbkdf2 -in ./terraform.tfvars.enc -out /home/ubuntu/.env -k ${DEV_TFVARS_ENC_PW}
chmod 600 /home/ubuntu/.env
set -a
source /home/ubuntu/.env
set +a

# compose 폴더 다운로드
mkdir -p /home/ubuntu/compose/gce
aws s3 cp s3://s3-careerbee-dev-infra/compose/gce /home/ubuntu --recursive
ls -l /home/ubuntu #debug

echo "[6-1] fluent-bit 실행"
cd /home/ubuntu
docker compose up -d

####################################################################################################################

echo "[7] ECR 최신 이미지 기반 AI 실행"
# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

docker pull "${ECR_REGISTRY}/ai-server:latest"

export ECR_REGISTRY=${ECR_REGISTRY}
export TAG=latest
export MOUNT_DIR=${MOUNT_DIR}
cd /home/ubuntu/deploy
docker compose --env-file /home/ubuntu/.env up -d
docker ps # debug

echo "[8] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/gce" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2