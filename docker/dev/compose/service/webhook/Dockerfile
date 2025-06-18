FROM python:3.12-slim

ENV TZ=Asia/Seoul
# 설치를 위한 의존 패키지
RUN apt-get update && \
    apt-get install -y \
    curl unzip awscli \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/* \
    && curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
       -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose
    
# 디렉토리 준비
WORKDIR /deploy

# Python 파일 복사
COPY webhook.py .

# Flask 설치
RUN pip install flask

# deploy.sh는 호스트에서 마운트됨 (docker-compose로)
CMD ["python", "webhook.py"]