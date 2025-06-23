#!/bin/bash
set -e

echo "[1] AWS CLI 설치"
apt update -y
apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

echo "[2] OpenVPN 복원"
aws s3 cp s3://s3-careerbee-dev-infra/openvpn/ /usr/local/openvpn_as/etc/ --recursive
sudo chown -R openvpnas:openvpnas /usr/local/openvpn_as/etc/

echo "[3] 관리자 계정 설정"
/usr/local/openvpn_as/scripts/sacli --user openvpn --key "type" --value "admin" UserPropPut
/usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "${openvpn_pw}" SetLocalPassword
/usr/local/openvpn_as/scripts/sacli --user mumu --key "type" --value "user_connect" UserPropPut
/usr/local/openvpn_as/scripts/sacli --user mumu --new_pass "${openvpn_pw}" SetLocalPassword
/usr/local/openvpn_as/scripts/sacli --user emily --key "type" --value "user_connect" UserPropPut
/usr/local/openvpn_as/scripts/sacli --user emily --new_pass "${openvpn_pw}" SetLocalPassword
/usr/local/openvpn_as/scripts/sacli --user dain --key "type" --value "user_connect" UserPropPut
/usr/local/openvpn_as/scripts/sacli --user dain --new_pass "${openvpn_pw}" SetLocalPassword
/usr/local/openvpn_as/scripts/sacli --user ellina --key "type" --value "user_connect" UserPropPut
/usr/local/openvpn_as/scripts/sacli --user ellina --new_pass "${openvpn_pw}" SetLocalPassword

# 서비스 시작
echo "[4] OpenVPN 서비스 시작"
systemctl enable openvpnas
systemctl restart openvpnas

echo "[5] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/openvpn" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2