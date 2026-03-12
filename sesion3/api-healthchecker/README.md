# api-healthchecker — Lab de Kubernetes

Aplicación Flask minimalista que evoluciona a lo largo de 6 temas de Kubernetes.
Cada tema agrega complejidad sobre el mismo objeto, sin romper lo anterior.

---

## Estructura del proyecto

```
api-healthchecker/
├── Dockerfile
├── requirements.txt
├── app/
│   └── main.py          ← versión activa (se reemplaza antes de cada build)
├── versions/
│   ├── main_v1.0.py     ← base: /health, /ready
│   ├── main_v2.0.py     ← probes: warmup 15s + fallo simulado a 90s
│   └── main_v3.0.py     ← rolling update: agrega /info
└── k8s/
    ├── 01-pod-multicontainer.yaml
    ├── 02-pod-initcontainers.yaml
    ├── 03-replicaset.yaml
    ├── 04-deployment-v1.0.yaml
    ├── 05-deployment-v2.0-probes.yaml
    ├── 06a-deployment-v3.0-rollingupdate.yaml
    └── 06b-deployment-v4.0-broken.yaml
```

---

## Construcción de imágenes

Ejecutar desde la raíz del proyecto. En minikube usar `minikube docker-env` primero.

```bash
# minikube (apuntar al daemon de minikube)
eval $(minikube docker-env)

# Imagen v1.0 — usada en temas 1, 2, 3, 4
cp versions/main_v1.0.py app/main.py
docker build -t api-healthchecker:1.0 .

# Imagen v2.0 — usada en tema 5 (Probes)
cp versions/main_v2.0.py app/main.py
docker build -t api-healthchecker:2.0 .

# Imagen v3.0 — usada en tema 6 (Rolling Update)
cp versions/main_v3.0.py app/main.py
docker build -t api-healthchecker:3.0 .
```

---

## Tema 1 — Pod Multi-containers

**Concepto:** dos contenedores comparten red (`localhost`) y ciclo de vida.

```bash
kubectl apply -f k8s/01-pod-multicontainer.yaml

kubectl get pod api-healthchecker
kubectl logs api-healthchecker -c api
kubectl logs api-healthchecker -c sidecar-logger

# El sidecar alcanza la API por localhost — misma red del Pod
kubectl exec -it api-healthchecker -c api -- wget -qO- localhost:5001/health
```

**Limpiar antes del siguiente tema:**
```bash
kubectl delete pod api-healthchecker
```

---

## Tema 2 — Init Containers

**Concepto:** los init containers corren en orden y deben completar con éxito
antes de que arranquen los containers principales.

```bash
kubectl apply -f k8s/02-pod-initcontainers.yaml

# Observar la progresión de estados
kubectl get pod api-healthchecker -w
# Init:0/2 → Init:1/2 → PodInitializing → Running

kubectl logs api-healthchecker -c init-check-network
kubectl logs api-healthchecker -c init-write-config
kubectl logs api-healthchecker -c api
```

**Limpiar:**
```bash
kubectl delete pod api-healthchecker
```

---

## Tema 3 — ReplicaSet

**Concepto:** garantiza N réplicas. Auto-recuperación si un Pod muere.

```bash
kubectl apply -f k8s/03-replicaset.yaml

kubectl get pods -l app=api-healthchecker
kubectl get rs api-healthchecker-rs

# Demostrar auto-recuperación
kubectl delete pod <nombre-de-un-pod>
kubectl get pods -w    # aparece un Pod nuevo automáticamente

# Escalar
kubectl scale rs api-healthchecker-rs --replicas=5
kubectl scale rs api-healthchecker-rs --replicas=2
```

**Limpiar:**
```bash
kubectl delete rs api-healthchecker-rs
```

---

## Tema 4 — Deployment

**Concepto:** envuelve al ReplicaSet. Agrega historial, estrategia de update
y comandos `rollout`.

```bash
kubectl apply -f k8s/04-deployment-v1.0.yaml

kubectl get deployment api-healthchecker
kubectl get rs          # RS creado automáticamente por el Deployment
kubectl get pods

kubectl rollout status deployment/api-healthchecker
kubectl rollout history deployment/api-healthchecker
kubectl describe deployment api-healthchecker
```

---

## Tema 5 — Liveness & Readiness Probes

**Concepto:**
- `readinessProbe` → ¿puede recibir tráfico? Falla: Pod fuera del pool.
- `livenessProbe`  → ¿sigue vivo? Falla: reinicio del contenedor.

**Comportamiento de v2.0:**
- `/ready` → 503 durante los primeros 15 s (warmup)
- `/health` → 500 a partir del segundo 90 (fallo simulado → reinicio)

```bash
kubectl apply -f k8s/05-deployment-v2.0-probes.yaml

# Observar el warmup (READY 0/1 → 1/1)
kubectl get pods -w

# A los ~90s el contenedor se reinicia (columna RESTARTS sube)
kubectl get pods

# Ver eventos de las probes
kubectl describe pod <nombre> | grep -A 20 "Events:"
```

---

## Tema 6 — Rolling Update & Rollback

### 6a — Rolling Update a v3.0

**Concepto:** actualización gradual sin downtime.
- `maxSurge: 1`      → máximo 4 Pods a la vez
- `maxUnavailable: 0` → nunca baja de 3 Pods disponibles

```bash
kubectl apply -f k8s/06a-deployment-v3.0-rollingupdate.yaml

# Observar sustitución gradual de Pods
kubectl rollout status deployment/api-healthchecker
kubectl get pods -w

# Ver historial con change-cause
kubectl rollout history deployment/api-healthchecker
```

### 6b — Despliegue roto + Rollback

```bash
# 1. Aplicar versión rota (imagen inexistente)
kubectl apply -f k8s/06b-deployment-v4.0-broken.yaml

# 2. Observar estado bloqueado
kubectl get pods
# Pods v3 → Running  |  Pods v4 → ErrImagePull / ImagePullBackOff

kubectl rollout status deployment/api-healthchecker
# Waiting for rollout to finish... (bloqueado)

# 3. Ver historial
kubectl rollout history deployment/api-healthchecker

# 4. Rollback a la revisión anterior
kubectl rollout undo deployment/api-healthchecker

# 5. O a una revisión específica
kubectl rollout undo deployment/api-healthchecker --to-revision=2

# 6. Confirmar recuperación
kubectl rollout status deployment/api-healthchecker
kubectl get pods
```

---

## Resumen de evolución

| # | Tema                   | Imagen | Lo que se agrega                                    |
|---|------------------------|--------|-----------------------------------------------------|
| 1 | Pod Multi-containers   | v1.0   | API Flask + sidecar busybox compartiendo localhost  |
| 2 | Init Containers        | v1.0   | 2 inits: verificar DNS y generar config             |
| 3 | ReplicaSet             | v1.0   | 3 réplicas, auto-recuperación y escalado            |
| 4 | Deployment             | v1.0   | Historial, gestión declarativa del RS               |
| 5 | Probes                 | v2.0   | readiness (warmup 15s) + liveness (fallo a 90s)     |
| 6 | Rolling Update/Rollback| v3.0   | Update gradual sin downtime, rollback ante fallo     |
