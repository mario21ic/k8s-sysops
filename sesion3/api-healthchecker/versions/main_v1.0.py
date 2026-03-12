"""
api-healthchecker v1.0
Endpoints: /, /health, /ready
Usado en: Pod Multi-container, Init Containers, ReplicaSet, Deployment
"""
import time
import socket
from flask import Flask, jsonify

app = Flask(__name__)
START     = time.time()
HOSTNAME  = socket.gethostname()
VERSION   = "1.0"


@app.route("/")
def home():
    return jsonify({"message": "Hello from api-healthchecker v1.0!"})


@app.route("/health")
def health():
    return jsonify(
        status="ok",
        version=VERSION,
        pod=HOSTNAME,
        uptime=round(time.time() - START, 1),
    )


@app.route("/ready")
def ready():
    return jsonify(ready=True, version=VERSION, pod=HOSTNAME)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
