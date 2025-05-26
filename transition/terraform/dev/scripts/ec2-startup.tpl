#!/bin/bash
export DEBIAN_FRONTEND=noninteractive # 비대화 모드

# ssh 키 추가
mkdir -p /home/ubuntu/.ssh
echo "${ADD_SSH_KEY}" >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# 1. 시스템 업데이트
sudo apt update -y && sudo apt upgrade -y

# 2. 필수 패키지
sudo apt install -y curl git unzip build-essential ca-certificates gnupg lsb-release software-properties-common npm
# aws-cli 설치
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 3. 로그, 릴리즈, 임시 디렉토리 추가 & 디스크 마운트
sudo mkdir -p /home/ubuntu/logs /home/ubuntu/release /home/ubuntu/tmp
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh /home/ubuntu/logs /home/ubuntu/release /home/ubuntu/tmp

# 4. Java 21 (OpenJDK 21)
sudo apt update -y
sudo apt install -y openjdk-21-jdk gradle

# 5. MySQL 8.4.0
sudo apt update -y
sudo apt install -y mysql-server

sudo systemctl enable mysql
sudo systemctl start mysql

# 🔥 bind-address 수정 (0.0.0.0으로 변경)
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf || \
sudo bash -c "echo 'bind-address = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf"

sudo systemctl restart mysql

# MySQL root 비밀번호 설정 및 보안 강화
sudo mysql <<MYSQL_ROOT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
MYSQL_ROOT

# 🔥 DB 및 사용자 생성
sudo mysql -uroot -p${DB_PASSWORD} <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USERNAME}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# 6. Node.js 22.14.0
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pnpm@10.7.1

# 8. Nginx + HTML 폴더
sudo apt install -y nginx
sudo mkdir -p /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html

# 8-1. Certbot 및 HTTPS 인증서 발급
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# 인증서 복원 - S3에서 다운로드 (AWS용 dev.${DOMAIN})
sudo mkdir -p /etc/letsencrypt/{live,archive,renewal}
sudo mkdir -p /etc/letsencrypt/live/dev.${DOMAIN}
sudo mkdir -p /etc/letsencrypt/archive/dev.${DOMAIN}

sudo aws s3 cp ${BUCKET_BACKUP}/aws/live/dev.${DOMAIN}/     /etc/letsencrypt/live/dev.${DOMAIN}/     --recursive
sudo aws s3 cp ${BUCKET_BACKUP}/aws/archive/dev.${DOMAIN}/  /etc/letsencrypt/archive/dev.${DOMAIN}/  --recursive
sudo aws s3 cp ${BUCKET_BACKUP}/aws/renewal/dev.${DOMAIN}.conf /etc/letsencrypt/renewal/
sudo aws s3 cp ${BUCKET_BACKUP}/aws/options-ssl-nginx.conf /etc/letsencrypt/
sudo aws s3 cp ${BUCKET_BACKUP}/aws/ssl-dhparams.pem /etc/letsencrypt/


# sudo certbot --nginx --non-interactive --agree-tos --no-redirect \
#   -m ${EMAIL} -d dev.${DOMAIN} -d dev-api.${DOMAIN}

# 8-2. Nginx SPA fallback 설정 + HTTPS listen 추가
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

# 9. Scouter Java Agent 설치 및 설정
sudo apt install -y openjdk-11-jdk
cd /home/ubuntu
wget https://github.com/scouter-project/scouter/releases/download/v2.20.0/scouter-all-2.20.0.tar.gz
tar -xvf scouter-all-2.20.0.tar.gz
rm scouter-all-2.20.0.tar.gz
sudo chown -R ubuntu:ubuntu /home/ubuntu/scouter

cd /home/ubuntu/scouter/server/lib
wget https://repo1.maven.org/maven2/javax/xml/bind/jaxb-api/2.3.1/jaxb-api-2.3.1.jar
wget https://repo1.maven.org/maven2/org/glassfish/jaxb/jaxb-runtime/2.3.1/jaxb-runtime-2.3.1.jar

cd /home/ubuntu/scouter/server
/usr/lib/jvm/java-11-openjdk-amd64/bin/java \
  -cp "./lib/*:./lib/jaxb-api-2.3.1.jar:./lib/jaxb-runtime-2.3.1.jar:./scouter-server-boot.jar" \
  scouter.boot.Boot ./lib > /home/ubuntu/logs/scouter-server.log 2>&1 &

cat <<EOF > /home/ubuntu/scouter/agent.java/conf/scouter.conf
net_collector_ip=127.0.0.1
EOF

cd ~

# 10. UFW 설정
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3306
sudo ufw allow 8080
sudo ufw allow 5173
sudo ufw allow 6100
sudo ufw --force enable

# 11.1 S3에서 BE 산출물 다운로드 및 배포
mkdir -p /home/ubuntu/release
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
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-exports java.base/sun.net=ALL-UNNAMED \
    -Djdk.attach.allowAttachSelf=true \
    -javaagent:/home/ubuntu/scouter/agent.java/scouter.agent.jar \
    -Dscouter.config=/home/ubuntu/scouter/agent.java/conf/scouter.conf \
    -Dobj_name=careerbee-api \
    -jar /home/ubuntu/release/careerbee-api.jar > /home/ubuntu/logs/backend.log 2>&1 &

# 11.2 S3에서 BE/FE 산출물 다운로드 및 배포
sudo rm -rf /var/www/html/*
aws s3 cp "$(aws s3 ls "${BUCKET_BACKUP}/fe/" | sort | tail -n 1 | awk '{print "'"${BUCKET_BACKUP}/fe/"'" $2}' | sed 's#/$##')" /var/www/html/ --recursive

# 12. 버전 확인 로그
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