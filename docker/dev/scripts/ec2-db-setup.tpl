#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드
export DB_NAME=${DB_NAME}
export DB_USERNAME=${DB_USERNAME}
export DB_PASSWORD=${DB_PASSWORD}

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

echo "[1] APT 업데이트"
apt update -y && apt upgrade -y
apt install -y unzip curl wget

echo "[2] Docker 설치"
curl -fsSL https://get.docker.com | bash
# Docker 유저 권한 부여
usermod -aG docker ubuntu
newgrp docker

echo "[4] AWS CLI 설치"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

####################################################################################################################

echo "[5] compose 폴더 다운로드"

# compose 폴더 다운로드
mkdir -p /home/ubuntu/{log,mysql/data}
aws s3 cp s3://s3-careerbee-dev-infra/compose/db /home/ubuntu --recursive
chown -R 999:999 /home/ubuntu/mysql

echo "[5-1] Mysql, fluent-bit 실행"
cd /home/ubuntu
docker compose up -d

####################################################################################################################

echo "[6] UFW 방화벽 설정"
ufw allow OpenSSH
ufw allow 3306
ufw --force enable

echo "[7] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/db" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2