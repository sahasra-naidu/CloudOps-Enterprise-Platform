FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY service_request_model.joblib .
COPY service_request_vectorizer.joblib .

EXPOSE 5002

CMD ["python", "app.py"]
