#!/bin/bash

THIS_SCRIPT=`basename "$0"`
MODE="$1"
MASTER_IP="$2"
TOKEN_INPUT="$3"


apt-get remove docker docker-engine docker.io containerd runc
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
systemctl restart docker
iptables -F
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
if [ "$MODE" == "master" ]; then
    curl -sfL https://get.k3s.io | sh -
    MACHINE_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    read -r TOKEN < /var/lib/rancher/k3s/server/node-token
    cp /var/lib/rancher/k3s/server/node-token /home/ubuntu/
    chmod 777 /etc/rancher/k3s/k3s.yaml
    cd /home/ubuntu
    mkdir .kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    mkdir k9s
    wget -c https://github.com/derailed/k9s/releases/download/v0.24.15/k9s_Linux_x86_64.tar.gz -O - | tar xz -C /home/ubuntu/k9s
    mv /home/ubuntu/k9s/k9s /usr/bin/
    chmod 777 /usr/bin/k9s
    rm -rf /home/ubuntu/k9s

    MASTER_NODE=$(kubectl get nodes --selector=node-role.kubernetes.io/master -o name)
    echo $MASTER_NODE
    kubectl taint node $MASTER_NODE node-role.kubernetes.io/master:NoSchedule

    echo "On the node please run:"
    echo "sudo ./$THIS_SCRIPT node $MACHINE_IP $TOKEN"
else
    curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN_INPUT sh -
fi


echo "Please reboot the machine before proceeding"
