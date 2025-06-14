#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

echo "[0] SSH 키 추가"
mkdir -p /home/ubuntu/.ssh/authorized_keys /home/ubuntu/.ssh/id_rsa
# 공개키 등록
echo "${public_nopass_key_base64}" | base64 -d >> /home/ubuntu/.ssh/authorized_keys

# 비공개키 저장
echo "${SSH_KEY_BASE64_NOPASS}" | base64 -d > /home/ubuntu/.ssh/id_rsa

# 권한 및 소유자 설정
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/id_rsa

echo "[1] APT 업데이트"
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y unzip curl wget

echo "[2] Docker 설치"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Docker 유저 권한 부여
sudo usermod -aG docker ubuntu
newgrp docker

echo "[3] Docker Compose 설치"
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "[4] AWS CLI 설치"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "[5] 환경변수 파일 및 compose 폴더 다운로드"

# .env 다운로드 및 실행
aws s3 cp s3://s3-careerbee-dev-infra/terraform.tfvars /home/ubuntu/.env
chmod 600 /home/ubuntu/.env
chown ubuntu:ubuntu /home/ubuntu
source /home/ubuntu/.env

# compose 폴더 다운로드
mkdir -p /home/ubuntu/compose/db
aws s3 cp s3://s3-careerbee-dev-infra/compose/db /home/ubuntu/compose/db --recursive

echo "[5-1] Mysql 실행"
cd /home/ubuntu/compose/db/fluent-bit
docker-compose up -d

echo "[5-2] fluent-bit 실행"
cd /home/ubuntu/compose/db/fluent-bit
docker-compose up -d

echo "[6] UFW 방화벽 설정"
sudo ufw allow 3306
sudo ufw --force enable

aws ssm put-parameter \
  --name "/careerbee/dev/db" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2