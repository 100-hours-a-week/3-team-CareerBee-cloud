events {}

http {
  
  # www.dev.careerbee.co.kr - SPA
  
  server {
    listen 80;
    server_name dev.careerbee.co.kr;

    return 301 http://www.dev.careerbee.co.kr$request_uri;
  }

  server {
      listen 80;
      server_name www.dev.careerbee.co.kr;
      location / {
          proxy_pass http://localhost:5173;
      }
  }

  server {
      listen 80;
      server_name api.dev.careerbee.co.kr;
      location / {
          proxy_pass http://localhost:8080;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
      }

      location /api/v1/sse/subscribe {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;

        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Cache-Control no-cache;
        proxy_set_header X-Accel-Buffering no;
        proxy_set_header Content-Type text/event-stream;

        proxy_buffering off;
        chunked_transfer_encoding on;
        proxy_read_timeout 86400;
    }

  }

  server {
      listen 80;
      server_name ai.dev.careerbee.co.kr;
      location / {
          proxy_pass http://${GCP_SERVER_IP}:8000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
      }
  }

  server {
      listen 80;
      server_name openvpn.dev.careerbee.co.kr;

      location / {
          proxy_pass http://${AWS_SERVER_IP}:943;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
      }
  }
}