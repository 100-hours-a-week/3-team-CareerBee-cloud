FROM python:3.11-slim

# 디렉토리 준비
WORKDIR /deploy

# Python 파일 복사
COPY webhook.py .

# Flask 설치
RUN pip install flask

# deploy.sh는 호스트에서 마운트됨 (docker-compose로)
CMD ["python", "webhook.py"]