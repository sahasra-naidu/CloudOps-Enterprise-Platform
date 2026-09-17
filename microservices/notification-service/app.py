from flask import Flask, jsonify
from datetime import datetime, timezone

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "service": "notification-service",
        "status": "running",
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.route("/health")
def health():
    return jsonify({
        "service": "notification-service",
        "status": "healthy"
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
