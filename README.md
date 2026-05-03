# Comic Reader — ENG23 3074

แพทฟอร์มสำหรับอ่านการ์ตูนออนไลน์ พัฒนาด้วย SvelteKit Golang; containerzed ด้วย Docker และ deployed บน Kubernetes ผ่าน CI/CD pipeline บน Jenkins

## ภาพรวมระบบ
- **ชื่อ:** Comic Reader
- **ประเภท:** Web Application
- **ภาษา / Framework:** SvelteKit, Golang
- **คำอธิบาย:** แพทฟอร์มสำหรับอ่านการ์ตูนออนไลน์ ช่วยให้ผู้ใช้สามารถเข้าถึงและอ่านการ์ตูนได้อย่างสะดวกและรวดเร็ว มีฟีเจอร์ประวัติการอ่านและแนะบุคมาร์คการ์ตูนที่ชื่นชอบ

## Development

### Setup

Install dependencies for both frontend and backend:

```bash
# Frontend
cd frontend
npm install

# Backend
cd backend
go mod tidy
```

---

### Run Locally

Start all required services and applications:

```bash
# Frontend
cd frontend
npm run dev -- --host
```

```bash
# Backend
cd backend

# Start dependency services (e.g. database, MinIO)
docker compose up -d  # ⚠️ Development only

# Run database migrations
go run ./cmd/migrate

# Start backend server
go run ./cmd/api
```

## Deployment

### Prerequisites

Ensure the following tools are installed and configured:

* Kubernetes cluster (e.g. kind, minikube, k3d)
* `kubectl` configured to access your cluster
* Terraform

### Bootstrap Infrastructure

Provision base infrastructure using Terraform:

```bash
cd infra/bootstrap

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars

# Initialize and apply Terraform
terraform init
terraform apply
```

Setup Ingress

ensure your cluster has an Ingress controller (e.g. NGINX Ingress Controller) installed and running.
see [Ingress Controller Installation](https://kubernetes.github.io/ingress-nginx/deploy/) for installation instructions.

Configure local DNS so your domains resolve to the Minikube cluster.


Option 1: /etc/hosts (Quick Setup)

Add entries manually:
```
{CLUSTER_IP} jenkins.devtool.local
{CLUSTER_IP} grafana.devtool.local
{CLUSTER_IP} cdn.app.local
{CLUSTER_IP} cdn-console.app.local
```


Option 2: NetworkManager + dnsmasq (Linux)
```bash
# get minikube ip
MINIKUBE_IP=$(minikube ip)

# configure dnsmasq for local domains
sudo mkdir -p /etc/NetworkManager/dnsmasq.d/

cat <<EOF | sudo tee /etc/NetworkManager/dnsmasq.d/minikube.conf
server=/local/${MINIKUBE_IP}
server=/app.local/${MINIKUBE_IP}
server=/devtool.local/${MINIKUBE_IP}
EOF

# enable dnsmasq in NetworkManager
cat <<EOF | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf
[main]
dns=dnsmasq
EOF

# restart NetworkManager
sudo systemctl restart NetworkManager
```
Verify
```
curl jenkins.devtool.local
```

Domains
- jenkins.devtool.local
- grafana.devtool.local
- cdn.app.local
- cdn-console.app.local

---

### Configure CI/CD (Jenkins)

1. Add a builder node:

   * Must have Docker and `kubectl` installed
   * Label it as: `builder`
   > You can use the cluster host as the builder node for simplicity

2. Create credentials:

   * Type: Docker registry (e.g. Docker Hub)
   * ID: `dockerhub-creds`

3. Create a pipeline job:

   * Use "Pipeline from SCM"
   * Point to this repository
   * Jenkinsfile path:

     ```
     infra/app/ci/Jenkinsfile
     ```
---

### Deploy Application

Deployment is handled via the Jenkins pipeline:

1. Go to the Jenkins dashboard
2. Open the pipeline job
3. Click **"Build with Parameters"**
4. Enter an image tag (e.g. `1.0.0`)
5. Click **Build**