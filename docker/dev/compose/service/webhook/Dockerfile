FROM python:3.12-slim

ENV TZ=Asia/Seoul
# 설치를 위한 의존 패키지
RUN apt-get update && \
    apt-get install -y \
        curl unzip awscli \
        default-mysql-client \
        ca-certificates gnupg lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p ~/.docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 \
        -o ~/.docker/cli-plugins/docker-compose && \
    chmod +x ~/.docker/cli-plugins/docker-compose
    
# 디렉토리 준비
WORKDIR /deploy

# Python 파일 복사
COPY webhook.py .

# Flask 설치
RUN pip install flask

# deploy.sh는 호스트에서 마운트됨 (docker-compose로)
CMD ["python", "webhook.py"]