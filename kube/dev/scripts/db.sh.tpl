#!/bin/bash
set -e

echo "[1] Hostname 변경"
hostnamectl set-hostname db

echo "[2] UFW 방화벽 설정"
ufw allow 22/tcp
ufw allow 179/tcp
ufw allow 10250/tcp
ufw allow 3306/tcp
ufw --force enable