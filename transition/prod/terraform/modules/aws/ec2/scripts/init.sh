#!/bin/bash
set -e

exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1

apt update && apt upgrade -y
apt install -y curl gnupg build-essential git unzip software-properties-common lsb-release

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
corepack enable
corepack prepare pnpm@10.7.1 --activate

add-apt-repository ppa:deadsnakes/ppa -y
apt update
apt install -y python3.12 python3.12-venv python3.12-dev

apt install -y openjdk-21-jdk

DEBIAN_FRONTEND=noninteractive apt install -y mysql-server
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

mysql -u root <<EOC
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY "${db_root_password}";
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY "${db_root_password}";
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOC

# Nginx
apt install -y nginx
ufw allow 'Nginx Full'

cat > /etc/nginx/sites-available/default <<EON
server {
    listen 80;
    server_name www.careerbee.co.kr;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

server {
    listen 80;
    server_name api.careerbee.co.kr;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EON

nginx -t && systemctl restart nginx