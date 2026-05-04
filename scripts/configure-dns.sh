#/bin/sh

# this script configures dnsmasq to resolve *.local domains to the minikube IP address

MINIKUBE_IP=$(minikube ip)

sudo mkdir -p /etc/NetworkManager/dnsmasq.d/

cat <<EOF | sudo tee /etc/NetworkManager/dnsmasq.d/minikube.conf
server=/local/${MINIKUBE_IP}
server=/app.local/${MINIKUBE_IP}
server=/devtool.local/${MINIKUBE_IP}
EOF

sudo systemctl restart NetworkManager