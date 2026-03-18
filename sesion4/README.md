# Ingress

1. Instalar controller:
```
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml

kubectl -n ingress-nginx get svc,pods
```

Con baremetal el Service queda como NodePort, así que prueba con ese puerto:


NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

echo $NODEPORT

curl --header 'Host: hello-world.info' 192.168.2.71:$NODEPORT/
curl --header 'Host: hello-world.info' 192.168.2.71:$NODEPORT/v2/


