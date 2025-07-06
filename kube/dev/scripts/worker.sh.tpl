#!/bin/bash
set -e

echo "[1] apt 패키지 업데이트 및 업그레이드"
apt update && apt upgrade -y

echo "[2] 쿠버네티스 설치 전 설정"
# swap 비활성화
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 커널 모듈
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl 설정
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

apt install -y containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# systemd로 cgroup 설정 변경
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

apt install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  gpg --dearmor | tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "[3] AWS CLI 설치"
apt update -y
apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

echo "[4] Join command 다운로드"
for i in {1..40}; do
  echo "[$(date)] checking for join.sh in S3..."
  aws s3 cp s3://s3-careerbee-dev-infra/join.sh /tmp/join.sh && break
  sleep 30
done
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
hostnamectl set-hostname worker-$(curl -sH "X-aws-ec2-metadata-token: \$TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
chmod +x /tmp/join.sh
/tmp/join.sh

echo "[4] ssh 비공개키 설정"
echo "${ssh_key_base64_nopass}" | base64 -d > /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/id_rsa

echo "[5] SSH 접속을 통한 워커 노드 레이블 추가"
ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@192.168.110.100 <<EOF
echo "[5] 마스터 노드에 워커 노드 레이블 추가"
kubectl label node \$(hostname) dedicated=service --overwrite
echo "[6] 워커 노드 상태 확인"
kubectl get nodes --show-labels
EOF

echo "[6] UFW 방화벽 설정"
ufw allow 22/tcp
ufw --force enable