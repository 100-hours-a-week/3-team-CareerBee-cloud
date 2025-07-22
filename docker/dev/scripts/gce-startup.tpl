#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드
export ECR_REGISTRY=${ECR_REGISTRY}
export TAG=latest
export MOUNT_DIR=${MOUNT_DIR}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

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

echo "[2-2] Docker 설치"
curl -fsSL https://get.docker.com | bash

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

echo "[3] UFW 방화벽 열기"
ufw allow OpenSSH
ufw allow 8000
ufw allow 8001
ufw allow 9100
ufw allow 9400
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


echo "[5] 도커 설정 및 플러그인 설치"
# 1. 도커 플러그인 설치
docker plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions || true

# 2. Docker 중지
systemctl stop docker

# 3. SSD 디렉토리 준비
rm -rf ${MOUNT_DIR}/docker
mkdir -p ${MOUNT_DIR}/docker

# 4. 기존 도커 데이터가 있으면 이동
if [ -d "/var/lib/docker" ] && [ ! -L "/var/lib/docker" ]; then
  mv /var/lib/docker/* ${MOUNT_DIR}/docker/
fi

# 5. 도커 설정파일 작성 - 도커 저장소 변경, 로그 드라이버 설정
mkdir -p /etc/docker
tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "${MOUNT_DIR}/docker",
  "log-driver": "loki",
  "log-opts": {
    "loki-url": "http://192.168.110.100:3100/loki/api/v1/push"
  }
}
EOF

# nvidia-container-toolkit 설치
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
apt-get install -y \
    nvidia-container-toolkit=$${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base=$${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools=$${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1=$${NVIDIA_CONTAINER_TOOLKIT_VERSION}
nvidia-ctk runtime configure --runtime=docker

# 6. 도커 시작 및 상태 확인
systemctl enable docker
systemctl start docker

echo "[6] 가상환경 구성"
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

echo "[7] 환경변수 파일 및 compose 폴더 다운로드"
# .env 다운로드 및 실행
aws s3 cp s3://s3-careerbee-dev-infra/terraform.tfvars.enc ./terraform.tfvars.enc
openssl version # debug
openssl aes-256-cbc -d -salt -pbkdf2 -in ./terraform.tfvars.enc -out /home/ubuntu/.env -k ${DEV_TFVARS_ENC_PW}
chmod 600 /home/ubuntu/.env
set -a
source /home/ubuntu/.env
set +a

# compose 폴더 다운로드
aws s3 cp s3://s3-careerbee-dev-infra/compose/gce ${MOUNT_DIR} --recursive

####################################################################################################################

echo "[8] ECR 최신 이미지 기반 AI 실행"
# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

mkdir -p /var/log/promtail
cd ${MOUNT_DIR}
docker compose -f docker-compose.infra.yml up -d
docker compose up -d

echo "[9] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/gce" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2