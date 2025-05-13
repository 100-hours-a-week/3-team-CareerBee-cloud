#!/bin/bash

SERVER_USER=ubuntu
SERVER_IP=<GCP-VM-IP>
SSH_KEY=~/.ssh/gcp-ssmu-dev-key

echo "[1] 최신 이전 버전으로 롤백 중..."

ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP <<EOF
  PREV_JAR=\$(ls -t ~/release/app-*.jar | sed -n 2p)
  if [ -z "\$PREV_JAR" ]; then
    echo "❌ 롤백 가능한 이전 버전이 없습니다."
    exit 1
  fi
  echo "🔁 롤백 대상: \$PREV_JAR"
  pkill -f 'app.jar'
  ln -sf \$PREV_JAR ~/app.jar
  nohup java -jar ~/app.jar > ~/logs/backend_rollback.log 2>&1 &
EOF

echo "✅ 롤백 완료"

