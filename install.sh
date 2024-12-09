#!/bin/bash

set -e

# Configurações iniciais
echo "Atualizando o sistema..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Instalação de dependências
echo "Instalando dependências..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg

# Configurando o container runtime (containerd)
echo "Instalando o containerd..."
sudo apt-get install -y containerd

# Configurando o containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

# Configurando o Kubernetes

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Configurando os módulos do kernel
echo "Configurando os módulos do kernel..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Inicializando o cluster Kubernetes
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
CONTROL_PLANE_ENDPOINT=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 -H "X-aws-ec2-metadata-token: $TOKEN")
echo "Inicializando o cluster Kubernetes..."
sudo kubeadm init --control-plane-endpoint $CONTROL_PLANE_ENDPOINT --pod-network-cidr=192.168.0.0/16

# Configurando o kubectl para o usuário atual
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Removendo taint do nó de controle para permitir workloads..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Instalando o plugin de rede Calico
echo "Instalando o Calico..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Verificando o status do cluster
echo "Verificando o status do cluster..."
kubectl get nodes

echo "Cluster Kubernetes configurado com sucesso!"
