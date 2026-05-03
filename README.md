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

---

## Deployment

### Prerequisites

Ensure the following tools are installed and configured:

* Kubernetes cluster (e.g. kind, minikube, k3d)
* `kubectl` configured to access your cluster
* Terraform

---

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

---

### Configure CI/CD (Jenkins)

1. Add a builder node:

   * Must have Docker and `kubectl` installed
   * Label it as: `builder`

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