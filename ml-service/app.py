from flask import Flask, request, jsonify
import joblib

app = Flask(__name__)

model = joblib.load("service_request_model.joblib")
vectorizer = joblib.load("service_request_vectorizer.joblib")

@app.route("/health")
def health():
    return jsonify({
        "service": "ml-service",
        "status": "healthy",
        "model": "service-request-classifier"
    })

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()

    if not data or "title" not in data:
        return jsonify({"error": "title is required"}), 400

    title = data["title"]
    prediction = model.predict(vectorizer.transform([title]))[0]

    return jsonify({
        "title": title,
        "predicted_status": prediction
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)
