#!/bin/bash
set -e

# echo "[1] OpenVPN 설치 및 실행"
# bash <(curl -fsS https://packages.openvpn.net/as/install.sh) --yes
# /usr/local/openvpn_as/scripts/sacli --key "host.name" --value "${aws_static_ip}" ConfigPut
# /usr/local/openvpn_as/scripts/sacli start
# /usr/local/openvpn_as/scripts/sacli --user openvpn --key "type" --value "admin" UserPropPut
# /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "${openvpn_pw}" SetLocalPassword
# /usr/local/openvpn_as/scripts/sacli --user mumu --key "type" --value "user_connect" UserPropPut
# /usr/local/openvpn_as/scripts/sacli --user mumu --new_pass "${openvpn_pw}" SetLocalPassword
# /usr/local/openvpn_as/scripts/sacli --user emily --key "type" --value "user_connect" UserPropPut
# /usr/local/openvpn_as/scripts/sacli --user emily --new_pass "${openvpn_pw}" SetLocalPassword
# /usr/local/openvpn_as/scripts/sacli --user dain --key "type" --value "user_connect" UserPropPut
# /usr/local/openvpn_as/scripts/sacli --user dain --new_pass "${openvpn_pw}" SetLocalPassword
# /usr/local/openvpn_as/scripts/sacli --user ellina --key "type" --value "user_connect" UserPropPut
# /usr/local/openvpn_as/scripts/sacli --user ellina --new_pass "${openvpn_pw}" SetLocalPassword

systemctl start openvpnas

echo "[2] SSM에 상태 기록"
aws ssm put-parameter \
  --name "/careerbee/dev/openvpn" \
  --value "ready" \
  --type "String" \
  --overwrite \
  --region ap-northeast-2