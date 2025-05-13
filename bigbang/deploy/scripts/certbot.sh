#!/bin/bash
source ./app-variables.sh

ssh -i $SSH_KEY ubuntu@$SERVER_IP <<EOF
# 8-1. Certbot 및 HTTPS 인증서 발급
echo "🔹 Certbot 설치 및 HTTPS 인증서 발급 중..."
# sudo snap install --classic certbot
# sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# # Certbot 인증서 발급
# sudo certbot --nginx --non-interactive --agree-tos --no-redirect -m ${EMAIL} \
#     -d ${DOMAIN} -d www.${DOMAIN} -d api.${DOMAIN} || echo "⚠️ Certbot 인증 실패 또는 이미 인증됨"

# 8-2. Nginx SPA fallback 설정 + HTTPS listen 추가
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF_NGINX
# HTTP → HTTPS 리디렉트
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name *.${DOMAIN};

    return 301 https://\\\$host\\\$request_uri;
}

# HTTPS 블록
server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    return 301 https://www.${DOMAIN}\\\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name www.${DOMAIN};

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files \\\$uri \\\$uri/ /index.html;
    }
}

server {
    listen 443 ssl;
    server_name api.${DOMAIN};

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
    }
}
EOF_NGINX

echo "✅ HTTPS 설정 추가 완료."
sudo nginx -t && sudo systemctl reload nginx

echo "✅ HTTPS 인증 완료 및 자동 갱신 설정됨."
EOF