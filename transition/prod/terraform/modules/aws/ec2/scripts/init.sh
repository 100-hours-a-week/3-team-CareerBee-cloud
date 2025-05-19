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
    server_name _;

    location / {
        proxy_pass http://localhost:5173;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EON

nginx -t && systemctl restart nginx