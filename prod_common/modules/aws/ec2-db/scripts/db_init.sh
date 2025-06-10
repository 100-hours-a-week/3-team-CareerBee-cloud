#!/bin/bash
set -e

exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1

DEBIAN_FRONTEND=noninteractive apt install -y mysql-server
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

mysql -u root <<EOC
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY "${db_root_password}";
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY "${db_root_password}";
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOC
