#!/bin/bash

FE_TAG=$1
BE_TAG=$2
AI_TAG=$3

# 환경 변수 확인
if [[ -z "$ECR_REGISTRY" || -z "$AWS_DEFAULT_REGION" ]]; then
  echo "❌ 환경변수 ECR_REGISTRY 또는 AWS_DEFAULT_REGION가 설정되지 않았습니다."
  exit 1
fi

FE_IMAGE="$ECR_REGISTRY/frontend:$FE_TAG"
BE_IMAGE="$ECR_REGISTRY/backend:$BE_TAG"
AI_IMAGE="$ECR_REGISTRY/ai-server:$AI_TAG"

echo "🚀 배포 시작: FE=$FE_TAG, BE=$BE_TAG, AI=$AI_TAG"
echo "📦 ECR Registry: $ECR_REGISTRY"
echo "📍 Region: $AWS_DEFAULT_REGION"

aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

docker pull $FE_IMAGE
docker pull $BE_IMAGE

cd /home/ubuntu/deploy
docker-compose down
docker-compose up -d

# 3. AI 서버 원격 배포
echo "🤖 AI 서버에 SSH 접속하여 배포 시작"

AI_HOST="10.0.110.2"
AI_KEY="/home/ubuntu/.ssh/id_rsa"

ssh -i "$AI_KEY" -o StrictHostKeyChecking=no ubuntu@$AI_HOST <<EOF
  echo "🔐 SSH 연결됨, AI 배포 진행 중..."
  export ECR_REGISTRY=$ECR_REGISTRY
  export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
  export AI_IMAGE=$AI_IMAGE
  
  aws ecr get-login-password --region \$AWS_DEFAULT_REGION | \
    docker login --username AWS --password-stdin \$ECR_REGISTRY

  docker pull \$AI_IMAGE

  cd /home/ubuntu/deploy
  docker-compose down
  docker-compose up -d

EOF

echo "✅ 전체 배포 완료"