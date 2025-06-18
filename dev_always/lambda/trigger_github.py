import json
import os
import urllib.request

def lambda_handler(event, context):
    github_token = os.environ['GITHUB_TOKEN']
    repo = os.environ['GITHUB_REPO']
    workflow = os.environ['GITHUB_WORKFLOW']

    url = f"https://api.github.com/repos/{repo}/actions/workflows/{workflow}/dispatches"
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json"
    }
    data = json.dumps({
        "ref": "develop"
    }).encode("utf-8")

    req = urllib.request.Request(url, headers=headers, data=data, method="POST")
    try:
        with urllib.request.urlopen(req) as response:
            return {
                "statusCode": response.getcode(),
                "body": response.read().decode()
            }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": str(e)
        }