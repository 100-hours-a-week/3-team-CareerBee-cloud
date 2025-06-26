#!/bin/bash
# set -e
export TAG=latest
export ECR_REGISTRY=${ECR_REGISTRY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

set -a
source /home/ubuntu/.env
set +a

aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
docker login --username AWS --password-stdin ${ECR_REGISTRY}

cd /home/ubuntu

docker compose -f docker-compose.fluent-bit.yml up -d

docker compose \
  -f docker-compose.nginx.yml \
  -f docker-compose.fe.yml \
  -f docker-compose.be.yml \
  -f docker-compose.webhook.yml \
  --env-file /home/ubuntu/.env \
  up -d