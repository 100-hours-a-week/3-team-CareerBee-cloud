#!/bin/bash

FE_TAG=$1
BE_TAG=$2
AI_TAG=$3

# 환경 변수 확인
if [[ -z "$ECR_REGISTRY" || -z "$AWS_DEFAULT_REGION" ]]; then
  echo "❌ 환경변수 ECR_REGISTRY 또는 AWS_DEFAULT_REGION가 설정되지 않았습니다."
  exit 1
fi

echo "📦 ECR Registry: $ECR_REGISTRY"
echo "📍 Region: $AWS_DEFAULT_REGION"

aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

cd /home/ubuntu/deploy

if [[ -n "$FE_TAG" ]]; then
  FE_IMAGE="$ECR_REGISTRY/frontend:$FE_TAG"
  echo "🚀 프론트 배포: $FE_IMAGE"
  docker pull $FE_IMAGE
  TAG=$FE_TAG docker compose stop frontend
  TAG=$FE_TAG docker compose rm -f frontend
  TAG=$FE_TAG docker compose up -d frontend
fi

if [[ -n "$BE_TAG" ]]; then
  BE_IMAGE="$ECR_REGISTRY/backend:$BE_TAG"
  echo "🚀 백엔드 배포: $BE_IMAGE"
  docker pull $BE_IMAGE
  TAG=$BE_TAG docker compose stop backend
  TAG=$BE_TAG docker compose rm -f backend
  TAG=$BE_TAG docker compose up -d backend
fi

if [[ -n "$AI_TAG" ]]; then
  # 3. AI 서버 원격 배포
  echo "🤖 AI 서버에 SSH 접속하여 배포 시작"

  ssh -i "/home/ubuntu/.ssh/id_rsa" -o StrictHostKeyChecking=no ubuntu@10.0.110.2 <<EOF
    echo "🔐 SSH 연결됨, AI 배포 진행 중..."

    export ECR_REGISTRY=$ECR_REGISTRY
    export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
    export TAG=$AI_TAG

    aws ecr get-login-password --region \$AWS_DEFAULT_REGION | \
      sudo docker login --username AWS --password-stdin \$ECR_REGISTRY

    sudo docker pull "$ECR_REGISTRY/ai-server:$AI_TAG"

    cd /home/ubuntu/deploy
    TAG=$AI_TAG sudo docker compose stop ai-server
    TAG=$AI_TAG sudo docker compose rm -f ai-server
    TAG=$AI_TAG sudo docker compose up -d ai-server
EOF
fi
echo "✅ 선택된 서비스 배포 완료"