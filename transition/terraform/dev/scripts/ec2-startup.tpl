#!/bin/bash
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

echo "[0] SSH 키 추가"
mkdir -p /home/ubuntu/.ssh
echo "${ADD_SSH_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

echo "[1] APT 업데이트"
sudo apt update -y && sudo apt upgrade -y

echo "[2] Fluent Bit 설치"
sudo apt install -y curl
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

[INPUT]
  Name   tail
  Path   /var/log/backend.log
  Tag    backend.log
  DB     /var/log/flb_tail.db
  Read_from_Head true

[INPUT]
  Name   tail
  Path   /var/log/scouter-server.log
  Tag    scouter.log
  DB     /var/log/flb_tail_scouter.db
  Read_from_Head true

[INPUT]
  Name   tail
  Path   /var/log/cloud-init-output.log
  Tag    userdata.log
  DB     /var/log/flb_tail_userdata.db
  Read_from_Head true

[OUTPUT]
  Name cloudwatch_logs
  Match backend.log
  region ap-northeast-2
  log_group_name backend-log
  log_stream_name backend-\$(date +%Y-%m-%d)
  auto_create_group true

[OUTPUT]
  Name cloudwatch_logs
  Match scouter.log
  region ap-northeast-2
  log_group_name scouter-log
  log_stream_name scouter-\$(date +%Y-%m-%d)
  auto_create_group true

[OUTPUT]
  Name cloudwatch_logs
  Match userdata.log
  region ap-northeast-2
  log_group_name userdata-log
  log_stream_name userdata-\$(date +%Y-%m-%d)
  auto_create_group true
EOF

sudo systemctl enable td-agent-bit
sudo systemctl restart td-agent-bit
sudo systemctl status td-agent-bit --no-pager

echo "[3] 기본 디렉토리 생성 및 s3 logs 마운트"
mkdir -p /home/ubuntu/{logs,release,tmp/s3cache}
sudo chown -R ubuntu:ubuntu /home/ubuntu
wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
sudo apt install -y ./mount-s3.deb
rm -f ./mount-s3.deb
echo "user_allow_other" | sudo tee -a /etc/fuse.conf

sudo -u ubuntu bash <<EOF
mount-s3 ${BUCKET_BACKUP_NAME} /home/ubuntu/logs --prefix logs/ --region ap-northeast-2 --cache /home/ubuntu/tmp/s3cache --metadata-ttl 60   --allow-other   --allow-overwrite   --allow-delete   --incremental-upload
EOF

echo "[4] 기본 패키지 설치 및 병렬로 필수 패키지 설치 시작"
sudo apt install -y git unzip build-essential ca-certificates gnupg lsb-release software-properties-common npm
(
  echo "[4-1] AWS CLI 설치"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
) &
(
  echo "[4-2] Java 21 설치"
  sudo apt update -y
  sudo apt install -y openjdk-21-jdk gradle
) &
(
  echo "[4-3] Node.js 22 + pnpm 설치"
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt install -y nodejs
  sudo npm install -g pnpm@10.7.1
) &

wait

echo "[5] MySQL 8.4.0 설치 및 설정"
sudo apt install -y mysql-server
sudo systemctl enable mysql && sudo systemctl start mysql

sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || \
sudo bash -c "echo 'bind-address = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
sudo systemctl restart mysql

sudo mysql <<MYSQL_ROOT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
MYSQL_ROOT

sudo mysql -uroot -p${DB_PASSWORD} <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "[6] UFW 방화벽 설정"
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3306
sudo ufw allow 8080
sudo ufw allow 5173
sudo ufw allow 6100
sudo ufw --force enable

echo "[7] Nginx 및 HTTPS 인증 설정"
sudo apt install -y nginx
sudo mkdir -p /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html

sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

mkdir -p /etc/letsencrypt/{live,archive,renewal}
mkdir -p /etc/letsencrypt/live/dev.${DOMAIN}
mkdir -p /etc/letsencrypt/archive/dev.${DOMAIN}

aws s3 cp ${BUCKET_BACKUP}/aws/live/dev.${DOMAIN}/     /etc/letsencrypt/live/dev.${DOMAIN}/     --recursive
aws s3 cp ${BUCKET_BACKUP}/aws/archive/dev.${DOMAIN}/  /etc/letsencrypt/archive/dev.${DOMAIN}/  --recursive
aws s3 cp ${BUCKET_BACKUP}/aws/renewal/dev.${DOMAIN}.conf /etc/letsencrypt/renewal/
aws s3 cp ${BUCKET_BACKUP}/aws/options-ssl-nginx.conf /etc/letsencrypt/
aws s3 cp ${BUCKET_BACKUP}/aws/ssl-dhparams.pem /etc/letsencrypt/

# sudo certbot --nginx --non-interactive --agree-tos --no-redirect \
#   -m ${EMAIL} -d dev.${DOMAIN} -d dev-api.${DOMAIN}

# NGINX 설정
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF_NGINX
# HTTP → HTTPS 리디렉트
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name *.${DOMAIN};

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name dev.${DOMAIN};

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/dev.${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dev.${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen 443 ssl;
    server_name dev-api.${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/dev.${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dev.${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF_NGINX

sudo nginx -t && sudo systemctl reload nginx

echo "[8] Scouter 설치 및 설정"
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

echo "[9] 백엔드 배포"
sudo -u ubuntu bash <<EOF
sudo touch /var/log/backend.log
sudo chown -R ubuntu:ubuntu /var/log/backend.log

aws s3 cp "$(aws s3 ls "${BUCKET_BACKUP}/be/" | sort | tail -n 1 | awk '{print "'"${BUCKET_BACKUP}/be/"'" $2}' | sed 's#/$##')/careerbee-api.jar" /home/ubuntu/release/careerbee-api.jar
pkill -f "careerbee-api.jar" || true
nohup java \
    -Dspring.profiles.active=dev \
    -DDB_URL="${DB_URL}" \
    -DDB_USERNAME="${DB_USERNAME}" \
    -DDB_PASSWORD="${DB_PASSWORD}" \
    -DJWT_SECRETS="${JWT_SECRETS}" \
    -DKAKAO_CLIENT_ID="${KAKAO_CLIENT_ID}" \
    -DKAKAO_PROD_REDIRECT_URI="${KAKAO_PROD_REDIRECT_URI}" \
    -DKAKAO_DEV_REDIRECT_URI="${KAKAO_DEV_REDIRECT_URI}" \
    -DKAKAO_LOCAL_REDIRECT_URI="${KAKAO_LOCAL_REDIRECT_URI}" \
    -DCOOKIE_DOMAIN="${COOKIE_DOMAIN}" \
    -DSENTRY_DSN="${SENTRY_DSN}" \
    -DSENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN}" \
    -DAWS_S3_ACCESSKEY="${AWS_ACCESS_KEY_ID}" \
    -DAWS_S3_SECRETKEY="${AWS_SECRET_ACCESS_KEY}" \
    -DAWS_REGION="${AWS_DEFAULT_REGION}" \
    -DAWS_S3_BUCKET="${S3_BUCKET_IMAGE}" \
    -DSARAMIN_SECRET_KEY="${SARAMIN_SECRET_KEY}" \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-exports java.base/sun.net=ALL-UNNAMED \
    -Djdk.attach.allowAttachSelf=true \
    -javaagent:/home/ubuntu/scouter/agent.java/scouter.agent.jar \
    -Dscouter.config=/home/ubuntu/scouter/agent.java/conf/scouter.conf \
    -Dobj_name=careerbee-api \
    -jar /home/ubuntu/release/careerbee-api.jar > /var/log/backend.log 2>&1 &
EOF

echo "[10] 프론트엔드 배포"
sudo -u ubuntu bash <<EOF
sudo rm -rf /var/www/html/*
aws s3 cp "$(aws s3 ls "${BUCKET_BACKUP}/fe/" | sort | tail -n 1 | awk '{print "'"${BUCKET_BACKUP}/fe/"'" $2}' | sed 's#/$##')" /var/www/html/ --recursive
EOF

echo "[11] 상태 로그"
echo "[✔] Fluent Bit 상태 확인:"
if systemctl is-active --quiet td-agent-bit; then
  echo "✅ td-agent-bit 서비스 실행 중"
else
  echo "❌ td-agent-bit 서비스 실행 실패"
  journalctl -u td-agent-bit --no-pager | tail -n 20
fi

echo "[✔] S3 마운트 상태:"
if mountpoint -q /home/ubuntu/logs; then
  echo "✅ S3가 /home/ubuntu/logs에 마운트되어 있습니다."
  df -h /home/ubuntu/logs
else
  echo "❌ S3가 /home/ubuntu/logs에 마운트되지 않았습니다. 수동 확인 필요."
  lsblk -f
fi

echo "[✔] Java 버전:"
java -version

echo "[✔] MySQL 상태:"
sudo systemctl is-active --quiet mysql && echo "MySQL 실행 중" || echo "❌ MySQL 비활성 상태"

echo "[✔] MySQL 사용자 및 DB 확인:"
sudo mysql -uroot -p${DB_PASSWORD} -e "SHOW DATABASES LIKE '${DB_NAME}';"
sudo mysql -uroot -p${DB_PASSWORD} -e "SELECT User, Host FROM mysql.user WHERE User='${DB_USERNAME}';"

echo "[✔] Node.js & pnpm 버전:"
node -v
pnpm -v

echo "[✔] Nginx 상태:"
sudo systemctl is-active --quiet nginx && echo "Nginx 실행 중" || echo "❌ Nginx 비활성 상태"

echo "[✔] HTTPS 인증서:"
if [ -f "/etc/letsencrypt/live/dev.${DOMAIN}/fullchain.pem" ]; then
  echo "인증서 존재함"
else
  echo "❌ 인증서 없음"
fi

echo "[✔] Scouter 서버 포트 상태:"
if sudo lsof -i :6100 | grep LISTEN > /dev/null; then
  echo "✅ Scouter 서버가 포트 6100에서 리스닝 중"
else
  echo "❌ Scouter 서버가 포트 6100에서 리스닝하지 않음"
fi

echo "[✔] Scouter 에이전트 상태:"
if pgrep -f "scouter.agent.jar" > /dev/null; then
  echo "✅ Scouter Java Agent 실행 중"
else
  echo "❌ Scouter Java Agent 비활성 상태"
fi

echo "[✔] UFW 방화벽 상태:"
sudo ufw status verbose

# 13. 배포 확인 로그
echo "[✔] 백엔드 서버 상태 확인:"
if pgrep -f "careerbee-api.jar" > /dev/null; then
  echo "✅ 백엔드(Spring Boot) 서버 실행 중"
else
  echo "❌ 백엔드(Spring Boot) 서버 실행 실패"
fi

echo "[✔] 프론트엔드 정적 파일 확인:"
if [ -f "/var/www/html/index.html" ]; then
  echo "✅ 프론트엔드 index.html 배포 완료"
else
  echo "❌ 프론트엔드 index.html 없음"
fi

touch /home/ubuntu/tmp/ec2-startup.done

echo "[12] 권한 설정"
chown -R ubuntu:ubuntu /home/ubuntu/{release,tmp} /var/www/html