#!/bin/bash

FE_TAG=$1
BE_TAG=$2
AI_TAG=$3

# 환경 변수 확인
if [[ -z "$ECR_REGISTRY" || -z "$AWS_DEFAULT_REGION" || -z "$MOUNT_DIR" ]]; then
  echo "❌ 환경변수 ECR_REGISTRY 또는 AWS_DEFAULT_REGION가 설정되지 않았습니다."
  exit 1
fi

echo "📦 ECR Registry: $ECR_REGISTRY"
echo "📍 Region: $AWS_DEFAULT_REGION"

if [[ -n "$FE_TAG" ]] || [[ -n "$BE_TAG" ]]; then
  echo "🚀 오토스케일링 그룹에 롤링 배포 시작"

  ASG_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "asg-careerbee-dev-service" \
    --region $AWS_DEFAULT_REGION \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text)

  echo "📋 배포 대상 인스턴스: $ASG_INSTANCES"

  for INSTANCE_ID in $ASG_INSTANCES; do
    echo "📦 인스턴스 $INSTANCE_ID에 배포 중..."
    
    # 인스턴스의 프라이빗 IP 가져오기
    PRIVATE_IP=$(aws ec2 describe-instances \
      --instance-ids $INSTANCE_ID \
      --region $AWS_DEFAULT_REGION \
      --query 'Reservations[0].Instances[0].PrivateIpAddress' \
      --output text)

    ssh -T -i "/home/ubuntu/.ssh/id_rsa" -o StrictHostKeyChecking=no ubuntu@$PRIVATE_IP <<EOF
      sudo -i
      aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
        docker login --username AWS --password-stdin $ECR_REGISTRY

      cd /home/ubuntu

      # 프론트엔드 배포
      if [[ -n "$FE_TAG" ]]; then
        export TAG=$FE_TAG
        docker rm -f frontend && \
        docker image prune -a -f && \
        docker compose pull frontend && \
        docker compose up -d frontend
        echo "✅ Frontend 배포 완료: $FE_TAG"
      fi
      
      # 백엔드 배포
      if [[ -n "$BE_TAG" ]]; then
        export TAG=$BE_TAG
        docker rm -f backend && \
        docker image prune -a -f && \
        docker compose pull backend && \
        docker compose up -d backend
        echo "✅ Backend 배포 완료: $BE_TAG"
      fi
      
      docker image prune -f
EOF
  done
fi

if [[ -n "$AI_TAG" ]]; then
  # 3. AI 서버 원격 배포
  echo "🤖 AI 서버에 SSH 접속하여 배포 시작"

  ssh -T -i "/home/ubuntu/.ssh/id_rsa" -o StrictHostKeyChecking=no ubuntu@10.0.110.10 <<EOF
    echo "🔐 SSH 연결됨, AI 배포 진행 중..."
    sudo -i

    export ECR_REGISTRY=$ECR_REGISTRY
    export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
    export TAG=$AI_TAG
    export MOUNT_DIR=$MOUNT_DIR

    aws ecr get-login-password --region \$AWS_DEFAULT_REGION | \
      docker login --username AWS --password-stdin \$ECR_REGISTRY

    cd ${MOUNT_DIR} && \
    docker rm -f ai-server && \
    docker compose pull ai-server && \
    docker compose up -d ai-server && \
    docker image prune -a -f 
EOF
fi
echo "✅ 선택된 서비스 배포 완료"