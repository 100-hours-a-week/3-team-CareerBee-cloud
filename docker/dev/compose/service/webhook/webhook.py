from flask import Flask, request, jsonify
from functools import wraps
import subprocess
import datetime
import os

WEBHOOK_TOKEN = os.getenv("WEBHOOK_TOKEN")

def auth_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or auth.split(" ")[1] != WEBHOOK_TOKEN:
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper

app = Flask(__name__)

# 헬스 체크
@app.route('/health-check', methods=['GET'])
def index():
    return "✅ Webhook server is running", 200

# 배포
@app.route('/deploy', methods=['POST'])
@auth_required
def deploy():
    try:
        data = request.get_json(force=True)

        frontend_tag = data.get('frontend_tag')
        backend_tag = data.get('backend_tag')
        ai_server_tag = data.get('ai_server_tag')

        if not (frontend_tag or backend_tag or ai_server_tag):
            return jsonify({
                "error": "하나의 태그라도 존재해야 합니다."
            }), 400

        timestamp = datetime.datetime.now().isoformat()
        print(f"[{timestamp}] 🔔 배포 요청:")
        if frontend_tag:
            print(f"  ↪️ 프론트엔드: {frontend_tag}")
        if backend_tag:
            print(f"  ↪️ 백엔드: {backend_tag}")
        if ai_server_tag:
            print(f"  ↪️ AI 서버: {ai_server_tag}")
        
        args = ["/deploy/deploy.sh"]
        args.append(frontend_tag if frontend_tag else "")
        args.append(backend_tag if backend_tag else "")
        args.append(ai_server_tag if ai_server_tag else "")

        subprocess.run(args, check=True)

        return jsonify({
            "message": "✅ 배포 완료",
            "fe_tag": frontend_tag,
            "be_tag": backend_tag,
            "ai_tag": ai_server_tag
        }), 200

    except Exception as e:
        print(f"❌ 배포 실패: {e}")
        return jsonify({"error": "❌ 배포 실패", "details": str(e)}), 500

# DB 백업
@app.route("/db_backup", methods=["GET"])
@auth_required
def db_backup():
    try:
        subprocess.check_call(["/deploy/db_backup.sh"])
        return jsonify({"message": "Backup script executed"}), 200
    except subprocess.CalledProcessError as e:
        return jsonify({"error": f"Backup failed: {e}"}), 500

# DB 복원
@app.route("/db_restore", methods=["GET"])
@auth_required
def db_restore():
    try:
        subprocess.check_call(["/deploy/db_restore.sh"])
        return jsonify({"message": "Restore script executed"}), 200
    except subprocess.CalledProcessError as e:
        return jsonify({"error": f"Restore failed: {e}"}), 500
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)