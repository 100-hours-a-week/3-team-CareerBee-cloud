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
apt install -y unzip curl wget openssl git python3-pip python3-venv jq

####################################################################################################################

echo "[2] Docker 설치"
curl -fsSL https://get.docker.com | bash

echo "[3] AWS CLI 설치"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install > /dev/null 2>&1

echo "[5] WEBHOOK 관련 패키지 설치"
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

echo "[6] Cloudflare 실행"
aws s3 cp s3://s3-careerbee-dev-infra/.cloudflared ~/.cloudflared --recursive
mkdir -p /etc/cloudflared
cp ~/.cloudflared/* /etc/cloudflared/
rm -rf ~/.cloudflared

cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared

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
mkdir -p /home/ubuntu/{deploy,log}
aws s3 cp s3://s3-careerbee-dev-infra/compose/service /home/ubuntu --recursive


echo "[5-1] webhook, fluent-bit 실행"
cd /home/ubuntu && docker compose up -d --build

####################################################################################################################

echo "[8] UFW 방화벽 설정"
ufw allow OpenSSH
ufw allow 3000
ufw allow 5000
ufw allow 6000
ufw --force enable

####################################################################################################################

echo "[9] Scouter 설치 및 설정"
apt-get update
apt install -y openjdk-11-jdk
cd /home/ubuntu
wget https://github.com/scouter-project/scouter/releases/download/v2.20.0/scouter-all-2.20.0.tar.gz
tar -xvf scouter-all-2.20.0.tar.gz && rm scouter-all-2.20.0.tar.gz

cd scouter/server/lib
wget https://repo1.maven.org/maven2/javax/xml/bind/jaxb-api/2.3.1/jaxb-api-2.3.1.jar
wget https://repo1.maven.org/maven2/org/glassfish/jaxb/jaxb-runtime/2.3.1/jaxb-runtime-2.3.1.jar

cd /home/ubuntu/scouter/server
/usr/lib/jvm/java-11-openjdk-amd64/bin/java \
  -cp "./lib/*:./lib/jaxb-api-2.3.1.jar:./lib/jaxb-runtime-2.3.1.jar:./scouter-server-boot.jar" \
  scouter.boot.Boot ./lib > /home/ubuntu/log/scouter.log 2>&1 &

cat <<EOF > /home/ubuntu/scouter/agent.java/conf/scouter.conf
net_collector_ip=127.0.0.1
EOF

cat <<EOF > /home/ubuntu/scouter/agent.host/conf/scouter.conf
net_collector_ip=127.0.0.1
EOF

cd /home/ubuntu/scouter/agent.host
sh host.sh start

####################################################################################################################

echo "[10] ECR latest 이미지 기반 프론트/백엔드 실행"
# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

cd /home/ubuntu/deploy
docker compose --env-file /home/ubuntu/.env up -d
docker ps # debug
####################################################################################################################

echo "[11] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/service" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2