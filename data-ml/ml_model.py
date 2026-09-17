import csv
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
import joblib

texts = []
labels = []

with open("service_requests.csv", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        texts.append(row["title"])
        labels.append(row["status"])

vectorizer = TfidfVectorizer()
X = vectorizer.fit_transform(texts)

model = LogisticRegression(max_iter=1000)
model.fit(X, labels)

joblib.dump(model, "service_request_model.joblib")
joblib.dump(vectorizer, "service_request_vectorizer.joblib")

print("ML model training completed")
print("Model saved: service_request_model.joblib")
print("Vectorizer saved: service_request_vectorizer.joblib")

sample = ["Database connection problem"]
prediction = model.predict(vectorizer.transform(sample))[0]

print("Sample inference:")
print(f"'{sample[0]}' -> {prediction}")
