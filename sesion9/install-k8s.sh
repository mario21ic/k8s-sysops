#!/bin/bash
# ------------------------------------------------------------
# Instalación de Kubernetes 1.25 en CentOS Stream 9 con kubeadm
# ------------------------------------------------------------
# Uso:    sudo ./install-k8s.sh <IP_MASTER> <IP_WORKER> <TIPO>
# Master: sudo ./install-k8s.sh 192.168.2.104 192.168.2.105 m
# Worker: sudo ./install-k8s.sh 192.168.2.104 192.168.2.105 w

set -e

MASTER_IP="$1"
WORKER_IP="$2"
NODE_TYPE="$3"
PASSWORD="somepass" # cambiar clave
HOSTNAME_MASTER="master.tech.local"
HOSTNAME_WORKER="worker.tech.local"

if [ -z "$MASTER_IP" ] || [ -z "$WORKER_IP" ] || [ -z "$NODE_TYPE" ]; then
  echo "Uso: ./install-k8s <IP_MASTER> <IP_WORKER> <TIPO>"
  echo "  Ejemplo: ./install-k8s 192.168.101.100 192.168.101.101 m"
  exit 1
fi

echo "[INFO] Configurando /etc/hosts con:"
echo "  Master: $MASTER_IP"
echo "  Worker: $WORKER_IP"
echo

# Hacemos backup por seguridad
cp /etc/hosts /etc/hosts.bak_$(date +%Y%m%d_%H%M%S)

cat <<EOF >> /etc/hosts
${MASTER_IP}   ${HOSTNAME_MASTER}
${WORKER_IP}   ${HOSTNAME_WORKER}
EOF

# Configuramos el hostname según el tipo de nodo
if [ "$NODE_TYPE" == "m" ]; then
  hostnamectl set-hostname ${HOSTNAME_MASTER}
elif [ "$NODE_TYPE" == "w" ]; then
  hostnamectl set-hostname ${HOSTNAME_WORKER}
else
  echo "[ERROR] Tipo de nodo inválido. Usa 'm' para master o 'w' para worker."
  exit 1
fi

# Configuración de llaves para ingresar a worker
dnf install -y sshpass
ssh-keygen -t ed25519 -C "mario21ic@k8s" -f ~/.ssh/id_ed25519 -q -N ""

if [ "$NODE_TYPE" == "m" ]; then
  sshpass -p ${PASSWORD} ssh-copy-id -i ~/.ssh/id_ed25519.pub -o StrictHostKeyChecking=no root@${WORKER_IP}
elif [ "$NODE_TYPE" == "w" ]; then
  sshpass -p ${PASSWORD} ssh-copy-id -i ~/.ssh/id_ed25519.pub -o StrictHostKeyChecking=no root@${MASTER_IP}
fi



CRI_SOCKET="unix:///run/containerd/containerd.sock"

echo "[1/11] Deshabilitando swap..."
swapoff -a
sed -i '/swap/d' /etc/fstab

echo "[2/11] Cargando módulos del kernel..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[3/11] Configurando sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "[4/11] Instalando dependencias..."
dnf install -y yum-utils device-mapper-persistent-data lvm2 curl gnupg2

echo "[5/11] Agregando repositorio oficial de Docker..."
cat <<EOF | tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/centos/9/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

echo "[6/11] Instalando containerd.io..."
dnf install -y containerd.io

echo "[7/11] Configurando containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd

echo "[8/11] Agregando repositorio de Kubernetes 1.25..."
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.25/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.25/rpm/repodata/repomd.xml.key
EOF


if [ "$NODE_TYPE" == "m" ]; then
  echo "[9/11] Instalando kubelet, kubeadm y kubectl..."
  dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
elif [ "$NODE_TYPE" == "w" ]; then
  echo "[9/11] Instalando kubelet, kubeadm y kubectl..."
  dnf install -y kubelet kubeadm --disableexcludes=kubernetes
fi

echo "[10/11] Configurando SELinux y firewall..."
setenforce 0 || true
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

if systemctl list-unit-files | grep -q firewalld; then
  echo "Configurando firewall..."
  systemctl stop firewalld
  systemctl disable firewalld
fi

systemctl enable kubelet


if [ "$NODE_TYPE" == "m" ]; then
  echo "Descarga de imagenes..."
  kubeadm config images pull

  echo "Inicio de cluster..."
  kubeadm init --cri-socket=${CRI_SOCKET}

  echo "Configuración de kubeconfig"
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

  echo "Despliegue red de pods"
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml

elif [ "$NODE_TYPE" == "w" ]; then
  CA_HASH=$(ssh root@${MASTER_IP} "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
  KUBE_TOKEN=$(ssh root@${MASTER_IP} "kubeadm token create")
  kubeadm join ${MASTER_IP}:6443 --token ${KUBE_TOKEN} --discovery-token-ca-cert-hash sha256:${CA_HASH}
fi

if [ "$NODE_TYPE" == "m" ]; then
  echo "Esperar que el nodo esté con estado Ready"
    while [[ $(kubectl get node ${HOSTNAME_MASTER} --no-headers 2>/dev/null | grep -c " Ready ") -eq 0 ]]; do
    echo "[INFO] Esperando que el nodo esté Ready..."
    sleep 10
  done
  kubectl get nodes -owide
elif [ "$NODE_TYPE" == "w" ]; then
  echo "Esperar que el nodo esté con estado Ready"
    while [[ $(ssh root@${MASTER_IP} "kubectl get nodes ${HOSTNAME_WORKER}  --no-headers 2>/dev/null | grep -c ' Ready '") -eq 0 ]]; do
    ssh root@${MASTER_IP} "kubectl get nodes -owide"
    echo "[INFO] Esperando que el nodo esté Ready..."
    sleep 10
  done
  ssh root@${MASTER_IP} "kubectl get nodes -owide"
fi

echo "[11/11] Instalación completada"
