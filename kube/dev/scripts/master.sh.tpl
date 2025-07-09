#!/bin/bash
set -e

echo "[1] apt 패키지 업데이트 및 필수 패키지 설치"
apt update && apt upgrade -y && \
apt install -y curl tar sudo unzip python3-pip python3-venv && \
python3 -m venv /home/ubuntu/venv && \
/home/ubuntu/venv/bin/pip install --upgrade pip && \
/home/ubuntu/venv/bin/pip install kubernetes openshift pyyaml

echo "[2] AWS CLI 설치"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

echo "[3] Tailscale 설치 및 복원"
curl -fsSL https://tailscale.com/install.sh | sh

# 복원
systemctl stop tailscaled
aws s3 cp s3://s3-careerbee-dev-infra/kube/tailscaled.state /var/lib/tailscale/tailscaled.state
sudo chown root:root /var/lib/tailscale/tailscaled.state
sudo chmod 600 /var/lib/tailscale/tailscaled.state
systemctl start tailscaled
tailscale up --authkey=${tailscale_key} --hostname=dev-master

echo "[4] GitHub Actions Runner 설치"
mkdir /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

sudo -u ubuntu /home/ubuntu/actions-runner/config.sh --unattended --replace \
  --url "https://github.com/${github_org}/${github_repo}" \
  --token "$(curl -X POST \
    -H "Authorization: Bearer ${github_token}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/${github_org}/${github_repo}/actions/runners/registration-token \
    | jq -r .token)" \
  --name self-hosted \
  --labels self-hosted

/home/ubuntu/actions-runner/svc.sh install && \
/home/ubuntu/actions-runner/svc.sh start

echo "[5] ssh 비공개키 설정"
echo "${ssh_key_base64_nopass}" | base64 -d > /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/id_rsa

echo "[6] UFW 방화벽 설정"
ufw allow 22/tcp
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 179/tcp
ufw allow 6443/tcp
ufw allow 9443/tcp
ufw --force enable