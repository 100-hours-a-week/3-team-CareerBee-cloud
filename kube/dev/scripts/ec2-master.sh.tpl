#!/bin/bash
set -e

apt update && apt upgrade -y && \
apt install -y curl tar sudo python3-pip python3-venv && \
python3 -m venv /home/ubuntu/venv && \
/home/ubuntu/venv/bin/pip install --upgrade pip && \
/home/ubuntu/venv/bin/pip install kubernetes openshift pyyaml

# Runner 설치 디렉토리 생성
mkdir actions-runner && cd actions-runner

# GitHub에서 Actions Runner 파일 다운로드 및 설치
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz

# GitHub에서 받은 토큰으로 등록
./config.sh --url ${dev_github_url} --token ${dev_github_token}

# 백그라운드 실행
./svc.sh install
./svc.sh start

# 비공개키 저장
echo "${ssh_key_base64_nopass}" | base64 -d > /home/ubuntu/.ssh/id_rsa

# 권한 및 소유자 설정
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/id_rsa