#!/bin/bash
# set -e
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

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
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y unzip curl wget

####################################################################################################################
(
  echo "[2] Docker 설치"
  curl -fsSL https://get.docker.com | sudo bash
  # Docker 유저 권한 부여
  sudo usermod -aG docker ubuntu
  newgrp docker
) &
(
  echo "[4] AWS CLI 설치"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
) &

wait

echo "[5] 환경변수 파일 및 compose 폴더 다운로드"

# .env 다운로드 및 실행
aws s3 cp s3://s3-careerbee-dev-infra/terraform.tfvars.enc terraform.tfvars.enc
sudo openssl aes-256-cbc -d -salt -pbkdf2 -in terraform.tfvars.enc -out /home/ubuntu/.env -k "${DEV_TFVARS_ENC_PW}"
chmod 600 /home/ubuntu/.env
chown ubuntu:ubuntu /home/ubuntu/.env
source /home/ubuntu/.env

# compose 폴더 다운로드
mkdir -p /home/ubuntu/compose/service
aws s3 cp s3://s3-careerbee-dev-infra/compose/service /home/ubuntu/compose/service --recursive

echo "[5-1] fluent-bit 실행"
cd /home/ubuntu/compose/service/fluent-bit
docker compose up -d

echo "[5-2] nginx 실행"
cd /home/ubuntu/compose/service/nginx
GCP_SERVER_IP=${GCP_SERVER_IP} AWS_SERVER_IP=${AWS_SERVER_IP} docker compose up -d

####################################################################################################################

echo "[6] UFW 방화벽 설정"
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 8080
sudo ufw allow 5173
sudo ufw allow 6100
sudo ufw --force enable

####################################################################################################################

echo "[7] Scouter 설치 및 설정"
sudo apt-get update
sudo apt install -y openjdk-11-jdk
cd /home/ubuntu
wget https://github.com/scouter-project/scouter/releases/download/v2.20.0/scouter-all-2.20.0.tar.gz
tar -xvf scouter-all-2.20.0.tar.gz && rm scouter-all-2.20.0.tar.gz

cd scouter/server/lib
wget https://repo1.maven.org/maven2/javax/xml/bind/jaxb-api/2.3.1/jaxb-api-2.3.1.jar
wget https://repo1.maven.org/maven2/org/glassfish/jaxb/jaxb-runtime/2.3.1/jaxb-runtime-2.3.1.jar

cd /home/ubuntu/scouter/server
/usr/lib/jvm/java-11-openjdk-amd64/bin/java \
  -cp "./lib/*:./lib/jaxb-api-2.3.1.jar:./lib/jaxb-runtime-2.3.1.jar:./scouter-server-boot.jar" \
  scouter.boot.Boot ./lib > /var/log/scouter-server.log 2>&1 &

cat <<EOF > /home/ubuntu/scouter/agent.java/conf/scouter.conf
net_collector_ip=127.0.0.1
EOF

cat <<EOF > /home/ubuntu/scouter/agent.host/conf/scouter.conf
net_collector_ip=127.0.0.1
EOF

cd /home/ubuntu/scouter/agent.host
sh host.sh start

####################################################################################################################

echo "[8] ECR 최신 이미지 기반 프론트/백엔드 실행"

# Docker 로그인 (필요시, AWS CLI v2 기준)
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

sudo -u ubuntu bash <<EOF
echo "[8-1] FRONTEND 실행"
sudo docker pull ${ECR_REGISTRY}/frontend:$(aws ecr describe-images \
  --repository-name frontend \
  --region ${AWS_DEFAULT_REGION} \
  --query 'reverse(sort_by(imageDetails[?imageTags != `null` && length(imageTags) > `0` && !contains(imageTags[0], `cache`)], &imagePushedAt))[0].imageTags[0]' \
  --output text)
sudo docker run -d \
  --log-driver=awslogs \
  --log-opt awslogs-region=ap-northeast-2 \
  --log-opt awslogs-group=frontend \
  --log-opt awslogs-stream=frontend-$(date +%Y-%m-%d) \
  --name frontend \
  -p 5173:5173 \
  --env-file /home/ubuntu/.env \
  ${ECR_REGISTRY}/frontend:$(aws ecr describe-images \
    --repository-name frontend \
    --region ${AWS_DEFAULT_REGION} \
    --query 'reverse(sort_by(imageDetails[?imageTags != `null` && length(imageTags) > `0` && !contains(imageTags[0], `cache`)], &imagePushedAt))[0].imageTags[0]' \
    --output text)

echo "[8-2] BACKEND 실행"
sudo docker pull ${ECR_REGISTRY}/backend:$(aws ecr describe-images \
  --repository-name backend \
  --region ${AWS_DEFAULT_REGION} \
  --query 'reverse(sort_by(imageDetails[?imageTags != `null` && length(imageTags) > `0` && !contains(imageTags[0], `cache`)], &imagePushedAt))[0].imageTags[0]' \
  --output text)
sudo docker run -d \
  --log-driver=awslogs \
  --log-opt awslogs-region=ap-northeast-2 \
  --log-opt awslogs-group=backend \
  --log-opt awslogs-stream=backend-$(date +%Y-%m-%d) \
  --name backend \
  -p 8080:8080 \
  --env-file /home/ubuntu/.env \
  -v /home/ubuntu/scouter:/scouter \
  -e JAVA_TOOL_compose/serviceIONS="\
    -Dspring.profiles.active=dev \
    -javaagent:/scouter/agent.java/scouter.agent.jar \
    -Dscouter.config=/scouter/agent.java/conf/scouter.conf \
    -Dobj_name=careerbee-api \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-exports java.base/sun.net=ALL-UNNAMED \
    -Djdk.attach.allowAttachSelf=true" \
  ${ECR_REGISTRY}/backend:$(aws ecr describe-images \
    --repository-name backend \
    --region ${AWS_DEFAULT_REGION} \
    --query 'reverse(sort_by(imageDetails[?imageTags != `null` && length(imageTags) > `0` && !contains(imageTags[0], `cache`)], &imagePushedAt))[0].imageTags[0]' \
    --output text)
EOF

echo "[9] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/service" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2