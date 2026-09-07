from flask import Flask, jsonify, request
import os
import psycopg2
from datetime import datetime, timezone

app = Flask(__name__)

DB_HOST = os.getenv(
    "DB_HOST",
    "cloudops-enterprise-db.cze44e2myaqb.eu-north-1.rds.amazonaws.com"
)
DB_NAME = os.getenv("DB_NAME", "cloudops")
DB_USER = os.getenv("DB_USER", "cloudopsadmin")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")


def get_connection():
    if not DB_PASSWORD:
        raise RuntimeError("DB_PASSWORD environment variable is not set")

    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )


def initialize_database():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS service_requests (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            status VARCHAR(50) NOT NULL DEFAULT 'OPEN',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    connection.commit()
    cursor.close()
    connection.close()


@app.route("/")
def home():
    return jsonify({
        "application": "CloudOps Enterprise Platform",
        "status": "running",
        "version": "2.0.0",
        "database": "PostgreSQL RDS",
        "timestamp": datetime.now(timezone.utc).isoformat()
    })


@app.route("/health")
def health():
    try:
        connection = get_connection()
        cursor = connection.cursor()

        cursor.execute("SELECT 1")
        cursor.fetchone()

        cursor.close()
        connection.close()

        return jsonify({
            "status": "healthy",
            "service": "cloudops-api",
            "database": "connected"
        })

    except Exception:
        return jsonify({
            "status": "unhealthy",
            "service": "cloudops-api",
            "database": "disconnected"
        }), 500


@app.route("/requests", methods=["GET"])
def get_requests():
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT id, title, description, status, created_at
        FROM service_requests
        ORDER BY id
    """)

    rows = cursor.fetchall()

    requests_data = []

    for row in rows:
        requests_data.append({
            "id": row[0],
            "title": row[1],
            "description": row[2],
            "status": row[3],
            "created_at": row[4].isoformat()
        })

    cursor.close()
    connection.close()

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

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        INSERT INTO service_requests (title, description)
        VALUES (%s, %s)
        RETURNING id, title, description, status, created_at
    """, (
        data["title"],
        data.get("description", "")
    ))

    row = cursor.fetchone()

    connection.commit()
    cursor.close()
    connection.close()

    return jsonify({
        "id": row[0],
        "title": row[1],
        "description": row[2],
        "status": row[3],
        "created_at": row[4].isoformat()
    }), 201


@app.route("/requests/<int:request_id>", methods=["GET"])
def get_request(request_id):
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT id, title, description, status, created_at
        FROM service_requests
        WHERE id = %s
    """, (request_id,))

    row = cursor.fetchone()

    cursor.close()
    connection.close()

    if not row:
        return jsonify({
            "error": "request not found"
        }), 404

    return jsonify({
        "id": row[0],
        "title": row[1],
        "description": row[2],
        "status": row[3],
        "created_at": row[4].isoformat()
    })


if __name__ == "__main__":
    initialize_database()
    app.run(host="0.0.0.0", port=5000)