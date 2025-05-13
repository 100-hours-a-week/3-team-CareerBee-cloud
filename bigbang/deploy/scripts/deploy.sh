#!/bin/bash
source ./app-variables.sh # cd deploy/scripts

exec > >(gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' >> ../logs/deploy.log) 2>&1

BACKEND_DIR=../backend
FRONTEND_DIR=../frontend
AI_DIR=../ai-server
VERSION_TAG=$(date +v%Y%m%d%H%M%S)

echo "========== [0] 코드 rsync로 서버로 전송 =========="

rsync -avz -e "ssh -i $SSH_KEY" --exclude=node_modules $BACKEND_DIR ubuntu@$SERVER_IP:~/tmp/
rsync -avz -e "ssh -i $SSH_KEY" --exclude=node_modules $FRONTEND_DIR ubuntu@$SERVER_IP:~/tmp/
rsync -avz -e "ssh -i $SSH_KEY" $AI_DIR ubuntu@$SERVER_IP:~/tmp/

echo "✅ 임시 디렉토리로 코드 전송 완료"

echo "========== [1] 서버 내 빌드/배포 및 롤백 준비 =========="

ssh -i $SSH_KEY ubuntu@$SERVER_IP << EOF
sudo cp -r ~/tmp/backend ~/release/
sudo cp -r ~/tmp/frontend ~/release/
sudo cp -r ~/tmp/ai-server ~/release/
sudo chown -R ubuntu:ubuntu ~/release
echo "✅ release 디렉토리로 복사 완료"

echo "[1-1] 백엔드 빌드 시작..."
cd ~/release/backend
./gradlew clean build -x test || {
  echo "❌ Gradle 빌드 실패. 배포 중단."
  exit 1
}

echo "[1-2] 백엔드 실행 중단 및 새로운 JAR 연결..."
pkill -f 'app.jar' || echo "기존 백엔드 없음"

JAR_PATH=\$(ls -t build/libs/*.jar | grep -v plain | head -n 1)
# echo "[디버그] 선택된 JAR_PATH: \$JAR_PATH"

cp \$JAR_PATH ~/release/app-${VERSION_TAG}.jar
ln -sfn ~/release/app-${VERSION_TAG}.jar ~/app.jar

if [ -L ~/app.jar ]; then
  TARGET=\$(readlink -f ~/app.jar)
  # echo "[디버그] 현재 TARGET 심볼릭 링크 대상: \$TARGET"
  echo "$VERSION_TAG → \$TARGET" >> ~/release/deployment-history.log
  echo "버전 기록 완료: $VERSION_TAG → \$TARGET"
fi

echo "[1-2-1] 새로운 백엔드 실행..."
nohup java \
-Dspring.profiles.active=dev \
-DDB_URL="${DB_URL}" \
-DDB_USERNAME="${DB_USERNAME}" \
-DDB_PASSWORD="${DB_PASSWORD}" \
-DJWT_SECRETS="${JWT_SECRETS}" \
-DKAKAO_CLIENT_ID="${KAKAO_CLIENT_ID}" \
-DKAKAO_REDIRECT_URI="${KAKAO_REDIRECT_URI}" \
-jar ~/app.jar > ~/logs/backend.log 2>&1 &

sleep 5
RUNNING=\$(pgrep -f 'app.jar' || true)

if [ -z "\$RUNNING" ]; then
  echo "❌ 새 백엔드 실행 실패 → 롤백 시작..."
  PREVIOUS_LINE=$(tail -n 2 ~/release/deployment-history.log | head -n 1)
  PREVIOUS_VERSION=\$(echo "\$PREVIOUS_LINE" | awk '{print $3}')

  if [ -f "\$PREVIOUS_VERSION" ]; then
      echo "🔄 이전 버전 (\$PREVIOUS_VERSION)으로 롤백 중..."
      ln -sfn "\$PREVIOUS_VERSION" ~/app.jar

      nohup java \
      -Dspring.profiles.active=dev \
      -DDB_URL="${DB_URL}" \
      -DDB_USERNAME="${DB_USERNAME}" \
      -DDB_PASSWORD="${DB_PASSWORD}" \
      -DJWT_SECRETS="${JWT_SECRETS}" \
      -DKAKAO_CLIENT_ID="${KAKAO_CLIENT_ID}" \
      -DKAKAO_REDIRECT_URI="${KAKAO_REDIRECT_URI}" \
      -jar ~/app.jar > ~/logs/backend.log 2>&1 &
      
    echo "✅ 이전 버전으로 롤백 완료."
  else
    echo "⚠️ 롤백 불가: 이전 JAR 없음."
  fi
else
  echo "✅ 백엔드 새 버전 정상 실행됨."
fi

echo "[1-3] 프론트엔드 빌드 시작..."
cd ~/release/frontend
pnpm install

echo "[1-3-1] 환경변수 파일(.env) 생성..."
echo "VITE_KAKAOMAP_KEY=${VITE_KAKAOMAP_KEY}" > ~/release/frontend/.env
echo "VITE_API_URL=\"https://api.${DOMAIN}\"" >> ~/release/frontend/.env

pnpm build

echo "[1-4] 프론트엔드 파일 배포..."
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/

echo "[1-5] AI 서버 준비 및 패키지 설치..."
cd ~/release/ai-server/summarizer_pipeline
if [ ! -d "venv" ]; then
  python3.12 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt

EOF

echo "✅ 서버 내 빌드 및 배포 완료 🎉"