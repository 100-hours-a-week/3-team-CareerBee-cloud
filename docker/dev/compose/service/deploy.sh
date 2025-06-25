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

aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

cd /app

if [[ -n "$FE_TAG" ]]; then
  FE_IMAGE="$ECR_REGISTRY/frontend:$FE_TAG"
  echo "🚀 프론트 배포: $FE_IMAGE"
  export TAG=$FE_TAG
  docker rm -f frontend && \
  docker compose -f docker-compose.fe.yml up -d --pull always && \
  docker image prune -f
fi

if [[ -n "$BE_TAG" ]]; then
  BE_IMAGE="$ECR_REGISTRY/backend:$BE_TAG"
  export TAG=$BE_TAG
  docker rm -f backend && \
  docker compose -f docker-compose.be.yml up -d --pull always && \
  docker image prune -f
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
    docker compose -f docker-compose.ai.yml up -d --pull always && \
    docker image prune -f
EOF
fi
echo "✅ 선택된 서비스 배포 완료"