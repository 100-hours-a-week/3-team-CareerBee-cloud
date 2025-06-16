from flask import Flask, request, jsonify
import subprocess
import datetime

app = Flask(__name__)

@app.route('/health-check', methods=['GET'])
def index():
    return "✅ Webhook server is running", 200

@app.route('/deploy', methods=['POST'])
def deploy():
    try:
        data = request.get_json(force=True)

        frontend_tag = data.get('frontend_tag')
        backend_tag = data.get('backend_tag')
        aiserver_tag = data.get('ai_server_tag')  # 추가된 부분

        if not frontend_tag or not backend_tag or not aiserver_tag:
            return jsonify({
                "error": "frontend_tag, backend_tag, and ai_server_tag are required"
            }), 400

        timestamp = datetime.datetime.now().isoformat()
        print(f"[{timestamp}] 🔔 배포 요청: FE={frontend_tag}, BE={backend_tag}, AI={aiserver_tag}")

        subprocess.run(
            ["/deploy/deploy.sh", frontend_tag, backend_tag, aiserver_tag],
            check=True
        )

        return jsonify({
            "message": "✅ 배포 완료",
            "fe_tag": frontend_tag,
            "be_tag": backend_tag,
            "ai_tag": aiserver_tag
        }), 200

    except Exception as e:
        print(f"❌ 배포 실패: {e}")
        return jsonify({"error": "❌ 배포 실패", "details": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)