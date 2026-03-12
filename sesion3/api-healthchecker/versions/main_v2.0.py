"""
api-healthchecker v2.0
Endpoints: /, /health, /ready
Novedad:
  - /ready  devuelve 503 durante los primeros 15 s (simula warmup)
  - /health devuelve 500 a partir del segundo 90   (simula fallo fatal)
Usado en: Liveness & Readiness Probes
"""
import time
import socket
import threading
from flask import Flask, jsonify

app = Flask(__name__)
START    = time.time()
HOSTNAME = socket.gethostname()
VERSION  = "2.0"
_alive   = True


def _kill_after(seconds: int) -> None:
    """Simula un fallo irrecuperable para que liveness lo detecte."""
    time.sleep(seconds)
    global _alive
    _alive = False
    print(f"[v{VERSION}] SIMULANDO FALLO FATAL — liveness probe fallará", flush=True)


# Dispara el "fallo" en un hilo background
threading.Thread(target=_kill_after, args=(90,), daemon=True).start()


@app.route("/")
def home():
    return jsonify({"message": "Hello from api-healthchecker v2.0!"})


@app.route("/health")
def health():
    """Liveness probe: falla cuando _alive es False."""
    if not _alive:
        return jsonify(status="dead", version=VERSION, pod=HOSTNAME), 500
    return jsonify(
        status="ok",
        version=VERSION,
        pod=HOSTNAME,
        uptime=round(time.time() - START, 1),
    )


@app.route("/ready")
def ready():
    """Readiness probe: no lista hasta completar 15 s de warmup."""
    uptime = time.time() - START
    if uptime < 15:
        remaining = round(15 - uptime, 1)
        return jsonify(ready=False, warmup_remaining=remaining, version=VERSION, pod=HOSTNAME), 503
    return jsonify(ready=True, version=VERSION, pod=HOSTNAME)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
