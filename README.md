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
# frontend
cd frontend
npm install

# backend
cd backend
go mod tidy
```

---

### Run Locally

Start all required services and applications:

```bash
# frontend
cd frontend
npm run dev -- --host
```

```bash
# backend
cd backend

# start dependency services (e.g. database, MinIO)
docker compose up -d  # ⚠️ Development only

# run database migrations
go run ./cmd/migrate

# start backend server
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

# copy and configure variables
cp terraform.tfvars.example terraform.tfvars

# initialize and apply terraform
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
# /etc/hosts
{CLUSTER_IP} jenkins.devtool.local
{CLUSTER_IP} grafana.devtool.local
{CLUSTER_IP} cdn.app.local
{CLUSTER_IP} cdn-console.app.local
```

Option 2: NetworkManager + dnsmasq (Linux)
```bash
# get minikube ip
MINIKUBE_IP=$(minikube ip) # or your cluster's IP address

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

### Credential Flow

Credentials flow through the system as follows:

1. **Bootstrap** → Terraform reads `terraform.tfvars` and seeds Jenkins via JCasC with all credentials
2. **Jenkins** → CI/CD pipelines pull credentials from Jenkins Credentials Store
3. **CD Pipeline** → Injects credentials as Terraform variables to `terraform plan/apply`
4. **Kubernetes** → Terraform creates ConfigMaps and Secrets with the injected values

---

### Configure CI/CD (Jenkins)

Jenkins is automatically configured during bootstrap using JCasC (Jenkins Configuration as Code). All credentials and jobs are seeded from `infra/bootstrap/main.tf`.

#### Prerequisites:

1. Add a builder node to your cluster:
   * Must have Docker and `kubectl` installed
   * Label it as: `builder`
   > You can use the cluster host as the builder node for simplicity

2. Verify credentials are automatically seeded:
   Go to Jenkins dashboard > Credentials > System > Global credentials and confirm:
   * `dockerhub-creds` - DockerHub username and password
   * `MINIO_PASSWORD` - MinIO password
   * `POSTGRES_PASSWORD` - PostgreSQL password
   * `JWT_SECRET` - JWT signing secret
   * `POSTGRES_USERNAME` - PostgreSQL username
   * `POSTGRES_DB_NAME` - PostgreSQL database name
   * `POSTGRES_PORT` - PostgreSQL port
   * `MINIO_ROOT_USER` - MinIO root username
   * `builder-ssh-key` - SSH key for builder agent

3. Verify pipeline jobs are automatically created:
   Go to Jenkins dashboard and confirm the following jobs exist:
   * `build-and-push` - CI pipeline (builds and pushes Docker images)
   * `pull-and-deploy` - CD pipeline (deploys to Kubernetes)

---

### Building Application

Building is handled via the Jenkins pipeline:

1. Go to the Jenkins dashboard
2. Open the CI pipeline job
3. Click **"Build with Parameters"**
4. Enter an image tag (e.g. `1.0.0`)
5. Click **Build**
> you can trigger the CI pipeline with hook or manually after code changes

### Deploy Application

1. After the build pipeline completes successfully, open the CD pipeline job
2. Click **"Build with Parameters"**
3. Enter the same image tag used in the build step
4. Click **Build**
> you can also trigger the CD pipeline manually after the build completes

Domains
- app.local     # frontend
- api.app.local # backend