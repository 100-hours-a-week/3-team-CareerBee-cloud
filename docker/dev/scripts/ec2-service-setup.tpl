#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드
export TAG=latest
export ECR_REGISTRY=${ECR_REGISTRY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

echo "[0] SSH 키 추가"
mkdir -p /home/ubuntu/.ssh
# 공개키 등록
echo "${public_nopass_key_base64}" | base64 -d >> /home/ubuntu/.ssh/authorized_keys

# 비공개키 저장
echo "${SSH_KEY_BASE64_NOPASS}" | base64 -d > /home/ubuntu/.ssh/id_rsa

# 권한 및 소유자 설정
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/id_rsa

####################################################################################################################

echo "[1] APT 업데이트 및 시간대 설정"
apt update -y && apt upgrade -y
timedatectl set-timezone Asia/Seoul
apt install -y unzip curl wget openssl git python3-pip python3-venv jq mysql-client

####################################################################################################################

echo "[2] Docker 설치"
curl -fsSL https://get.docker.com | bash

echo "[3] AWS CLI 설치"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install > /dev/null 2>&1

if aws ssm put-parameter \
  --name "/careerbee/dev/tailscale-lock" \
  --value "ready" \
  --type "String" \
  --region ap-northeast-2 2>/dev/null; then
      
  echo "[4] Tailscale 설치 및 복원"
  curl -fsSL https://tailscale.com/install.sh | sh

  # 복원
  systemctl stop tailscaled
  aws s3 cp s3://s3-careerbee-dev-infra/docker/tailscaled_service.state /var/lib/tailscale/tailscaled.state
  sudo chown root:root /var/lib/tailscale/tailscaled.state
  sudo chmod 600 /var/lib/tailscale/tailscaled.state
  systemctl start tailscaled
  tailscale up --authkey=${tailscale_key} --hostname=dev-docker-service

  echo "Tailscale 설정 완료"
else
    echo "이미 다른 인스턴스에서 Tailscale이 설정되었습니다. 스킵합니다."
fi

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

# deploy 폴더 다운로드
aws s3 cp s3://s3-careerbee-dev-infra/compose/service /home/ubuntu --recursive

####################################################################################################################

echo "[8] UFW 방화벽 설정"
ufw allow OpenSSH
ufw allow 5173
ufw allow 8080
ufw allow 9100
ufw --force enable

####################################################################################################################

echo "[10] ECR latest 이미지 기반 프론트/백엔드, Promtail 실행"
# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

mkdir -p /var/log/promtail
cd /home/ubuntu
docker compose --env-file /home/ubuntu/.env up -d --build

####################################################################################################################

echo "[11] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/service" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2