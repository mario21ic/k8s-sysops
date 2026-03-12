"""
api-healthchecker v3.0
Endpoints: /, /health, /ready, /info  ← nuevo
Novedad:
  - Agrega /info con metadata de la app
  - Warmup reducido a 10 s (mejora respecto a v2)
  - Sin fallo simulado (versión estable)
Usado en: Rolling Update (target) y Rollback (destino)
"""
import time
import socket
from flask import Flask, jsonify

app = Flask(__name__)
START    = time.time()
HOSTNAME = socket.gethostname()
VERSION  = "3.0"


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
    uptime = time.time() - START
    if uptime < 10:
        remaining = round(10 - uptime, 1)
        return jsonify(ready=False, warmup_remaining=remaining, version=VERSION, pod=HOSTNAME), 503
    return jsonify(ready=True, version=VERSION, pod=HOSTNAME)


@app.route("/info")
def info():
    """Nuevo en v3.0: metadata pública de la aplicación."""
    return jsonify(
        app="api-healthchecker",
        version=VERSION,
        pod=HOSTNAME,
        env="production",
        uptime=round(time.time() - START, 1),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
