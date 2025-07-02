#!bin/bash
set -e

echo "[1] apt 패키지 업데이트 및 업그레이드"
apt update && apt upgrade -y

echo "[2] NVIDIA 드라이버 설치"
apt-get update
apt-get install -y nvidia-driver-570

echo "[3] 디스크 마운트"
if ls "${device_id}" > /dev/null 2>&1; then
  if ! blkid "${device_id}"; then
      mkfs.ext4 -F "${device_id}"
  fi

  mkdir -p "${mount_dir}"
  mount -o discard,defaults "${device_id}" "${mount_dir}"

  if ! grep -q "${device_id}" /etc/fstab; then
      echo "${device_id} ${mount_dir} ext4 discard,defaults,nofail 0 2" | tee -a /etc/fstab
  fi
fi

echo "[4] UFW 방화벽 설정"
ufw allow 22/tcp
ufw --force enable