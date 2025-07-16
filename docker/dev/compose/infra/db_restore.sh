#!/bin/bash
set -e

echo "[db_restore.sh] 복원 스크립트 실행 시작"

LATEST_BACKUP=$(aws s3 ls s3-careerbee-dev-infra/db/ | sort | tail -n 1 | awk '{print $4}')
ASG_INSTANCE=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "asg-careerbee-dev-service" \
    --region $AWS_DEFAULT_REGION \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId | [0]' \
    --output text)
PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $ASG_INSTANCE \
    --region $AWS_DEFAULT_REGION \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

if [ -z "$LATEST_BACKUP" ]; then
  echo "❌ 최신 백업 파일을 찾을 수 없습니다."
  exit 1
fi

echo "🗂️ 최신 백업 파일: $LATEST_BACKUP"

ssh -T -i "/home/ubuntu/.ssh/id_rsa" -o StrictHostKeyChecking=no ubuntu@$PRIVATE_IP <<EOF
  aws s3 cp s3://s3-careerbee-dev-infra/db/$LATEST_BACKUP $LATEST_BACKUP # /home/ubuntu/webhook

  mysql -h 192.168.210.10 -u "${DB_USERNAME}" -p"${DB_PASSWORD}" ${DB_NAME} < "$LATEST_BACKUP"

  echo "✅ 복원 완료"
EOF