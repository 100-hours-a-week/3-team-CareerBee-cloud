variable "machine_type" {
  type = string
}

variable "zone" {
  type = string
}

variable "network_id" {
  type        = string
  description = "ID of the VPC network"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnetwork"
}

variable "startup_script" {
  default = <<-EOT
#!/bin/bash
set -e
apt-get update
apt-get install -y build-essential dkms curl python3-pip
apt-get install -y nvidia-driver-535 nvidia-utils-535
sleep 10
modprobe nvidia
DISK_PATH="/dev/disk/by-id/google-careerbee-ai-ssd"
MOUNT_PATH="/mnt/ssd"
mkdir -p "$MOUNT_PATH"
mount -o discard,defaults "$DISK_PATH" "$MOUNT_PATH"
grep -q "$DISK_PATH" /etc/fstab || echo "$DISK_PATH $MOUNT_PATH ext4 discard,defaults,nofail 0 2" >> /etc/fstab
  EOT
}
