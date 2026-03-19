## Gateway:

CRDS de Gateway API:
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
kubectl get crd | grep gateway


# Instalar el controller
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml

# Verificar que el pod esté Running
kubectl get pods -n nginx-gateway


# Parchar para que gateway sea mediante NodePort
kubectl patch svc nginx-gateway -n nginx-gateway \
  -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30080, "targetPort": 80, "protocol": "TCP"}]}}'
# Razon: El Service del NGINX Gateway es LoadBalancer pero kubeadm no tiene asignador de IPs

# Verificar el nodePort asignado
kubectl get svc -n nginx-gateway


# Instalar gateway y routes
#kubectl apply -f gatewayclass.yml # ya no es necesario
kubectl apply -f gateway.yml
kubectl apply -f gateway-routes.yml

# Ejecutar stern
stern web

# Probar
curl --header 'Host: hello-world.info' 192.168.2.72:30080/
curl --header 'Host: hello-world.info' 192.168.2.72:30080/v2

# Canary
kubectl delete -f gateway-routes.yml
kubectl apply -f gateway-routes-canary.yml
curl --header 'Host: hello-world.info' 192.168.2.72:30080
curl --header 'Host: hello-world.info' --header 'X-Canary: true'  192.168.2.72:30080


# Opcional en lugar de usar NodePort en gatewayclass:
Instalar MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

# Esperar pods Ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s



# TOP:

Instalar metric server:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml


Problema común en kubeadm: TLS error
En clusters kubeadm los kubelets usan certificados self-signed, por lo que el Metrics Server falla al verificarlos. Verifica si ocurre:
kubectl logs -n kube-system deploy/metrics-server

kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }]'

kubectl get deployment metrics-server -n kube-system \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n'


kubectl rollout status deploy/metrics-server -n kube-system

kubectl logs -n kube-system deploy/metrics-server -f


Probar:
kubectl top nodes

# Validando Limits de CPU
kubectl apply -f pod-limits-cpu.yml
kubectl top pod-limits-cpu

# Validando Limits de Memory
kubectl apply -f pod-limits-memory.yml
kubectl top pod-limits-memory

# Nota: validar si es exacto, poco, demasiado, etc.
