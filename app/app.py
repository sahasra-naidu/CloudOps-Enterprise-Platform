from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

requests_data = []


@app.route("/")
def home():
    return jsonify({
        "application": "CloudOps Enterprise Platform",
        "status": "running",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": "cloudops-api"
    })


@app.route("/requests", methods=["GET"])
def get_requests():
    return jsonify({
        "count": len(requests_data),
        "requests": requests_data
    })


@app.route("/requests", methods=["POST"])
def create_request():
    data = request.get_json()

    if not data or "title" not in data:
        return jsonify({
            "error": "title is required"
        }), 400

    new_request = {
        "id": len(requests_data) + 1,
        "title": data["title"],
        "description": data.get("description", ""),
        "status": "OPEN",
        "created_at": datetime.utcnow().isoformat()
    }

    requests_data.append(new_request)

    return jsonify(new_request), 201


@app.route("/requests/<int:request_id>", methods=["GET"])
def get_request(request_id):
    for item in requests_data:
        if item["id"] == request_id:
            return jsonify(item)

    return jsonify({
        "error": "request not found"
    }), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)