# Comic Reader — ENG23 3074

> แพทฟอร์มสำหรับอ่านการ์ตูนออนไลน์ พัฒนาด้วย SvelteKit Golang; containerzed ด้วย Docker และ deployed บน Kubernetes ผ่าน CI/CD pipeline บน Jenkins
---

## สมาชิกในกลุ่ม

| รหัสนักศึกษา | ชื่อ-นามสกุล | ความรับผิดชอบ |
|-------------|-------------|---------------|
| B6603946 | นายสุรเกียรติ์ สิงขรอาสน์ | Git, App Development, Jenkins, Docker, Terraform |
| B6618643 | นายกิตตินันท์ ปัจจัยโคถา | Prometheus, Grafana (Frontend)|
| B6627713 | นายทองนรินทร์ แย้มศรี | Prometheus, Grafana (Backend)|

---
## ภาพรวมระบบ
- **ชื่อ:** Comic Reader
- **ประเภท:** Web Application
- **ภาษา / Framework:** SvelteKit, Golang
- **คำอธิบาย:** แพทฟอร์มสำหรับอ่านการ์ตูนออนไลน์ ช่วยให้ผู้ใช้สามารถเข้าถึงและอ่านการ์ตูนได้อย่างสะดวกและรวดเร็ว มีฟีเจอร์ประวัติการอ่านและบุคมาร์คการ์ตูนที่ชื่นชอบ

---
## Architecture Diagram

```
Developer
    |
    ▼  git push
GitHub ── webhook ──▶ Jenkins CI/CD
                           |
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Checkout      Build       Docker Build
                      (parallel)         |
                    Frontend+Backend     ▼
                                    Docker Hub
                                         |
                                         ▼
                                     Terraform
                                   (K8s resources)
                                         |
                                         ▼
                        Kubernetes Cluster
                   ┌────────────────────────┐
                   │  Frontend   Backend    │
                   │   [Pod]      [Pod]     │
                   │  SvelteKit  Golang/Gin │
                   │                       │
                   │  PostgreSQL   MinIO    │
                   │   [Pod]       [Pod]    │
                   │                       │
                   │  Nginx Ingress         │
                   │  app.local             │
                   │  api.app.local         │
                   └────────────────────────┘
                           │          │
              ┌────────────┘          └────────────┐
              ▼                                    ▼
        Prometheus                             Grafana
      (scrape /metrics)  ─────────────▶    (dashboard)
```

> **Ansible** ใช้สำหรับ provision Builder Node (ติดตั้ง Docker, kubectl, Terraform) แบบ manual ก่อน bootstrap

---
## โครงสร้าง Repository

```
[sca-project]/
├── backend/
│   ├── cmd/                    # Entry point ของแอปพลิเคชัน (เช่น api, migrate)
│   ├── internal/               # โค้ดการทำงานหลักของระบบแบ่งตาม components
│   ├── Dockerfile              # คำสั่งสร้าง Docker image สำหรับ backend
│   ├── compose.yml             # สำหรับรัน Dependency services (DB, MinIO)
│   └── go.mod                  # จัดการ Go dependencies
├── frontend/
│   ├── src/                    # โค้ดหลักของแอปพลิเคชันส่วนหน้า (SvelteKit)
│   ├── static/                 # ไฟล์ที่ไม่มีการเปลี่ยนแปลง (เช่น รูปภาพ)
│   ├── Dockerfile              # คำสั่งสร้าง Docker image สำหรับ frontend
│   └── package.json            # Node.js dependencies
├── infra/
│   ├── ansible/                # Ansible playbook สำหรับตั้งค่า Builder Node (รันก่อน bootstrap)
│   │   ├── site.yml            # Main playbook (configure builder node)
│   │   ├── ansible.cfg         # Ansible config
│   │   ├── inventory.ini       # Inventory (กำหนด host ของ builder)
│   │   └── roles/
│   │       ├── common/         # ติดตั้ง packages พื้นฐาน (curl, git, unzip)
│   │       ├── docker/         # ติดตั้ง Docker Engine + เพิ่ม user group
│   │       ├── kubectl/        # ติดตั้ง kubectl binary
│   │       └── terraform/      # ติดตั้ง Terraform binary
│   ├── app/
│   │   ├── cd/                 # Jenkinsfile.cd — CD pipeline (Terraform deploy to K8s)
│   │   ├── ci/                 # Jenkinsfile.ci — CI pipeline (Build & Push Docker image)
│   │   └── terraform/          # K8s resources: Deployments, Services, Secrets, ConfigMaps
│   └── bootstrap/              # Bootstrap infrastructure ด้วย Terraform (Jenkins, DB, Monitoring)
├── scripts/
│   └── configure-dns.sh        # สคริปต์อัตโนมัติสำหรับตั้งค่า DNS
├── refs.md                     # แหล่งอ้างอิง
└── README.md                   # เอกสารอธิบายโปรเจคนี้
```

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

see [configure-dns](scripts/configure-dns.sh) for automated setup

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

Jenkins is automatically configured during bootstrap using JCasC (Jenkins Configuration as Code). All nodes credentials and jobs are seeded from `infra/bootstrap/main.tf`.

#### Verification:

1. Verify a builder agent node is automatically created:

   Go to Jenkins dashboard > Manage Jenkins > Manage Nodes and confirm a node named `builder` exists with the correct SSH credentials.

2. Verify credentials are automatically seeded:

   Go to Jenkins dashboard > Credentials > System > Global credentials and confirm:
   * `dockerhub-creds` - DockerHub username and password
   * `builder-ssh-key` - SSH key for builder agent
   * `MINIO_PASSWORD` - MinIO password
   * `POSTGRES_PASSWORD` - PostgreSQL password
   * `JWT_SECRET` - JWT signing secret
   * `POSTGRES_USERNAME` - PostgreSQL username
   * `MINIO_ROOT_USER` - MinIO root username

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

1. After the build pipeline completes successfully, open the CD pipeline job (`pull-and-deploy`)
2. Click **"Build with Parameters"**
3. Enter the same image tag used in the build step
4. Click **Build**
> you can also trigger the CD pipeline manually after the build completes

The CD pipeline runs the following stages:

| Stage | Description |
|-------|-------------|
| Checkout | ดึงโค้ดล่าสุดจาก GitHub |
| Terraform Init | เตรียม Terraform providers และ backend |
| Inject Secrets & Plan | ดึง credentials จาก Jenkins → `terraform plan` |
| Apply | `terraform apply` → สร้าง/อัปเดต K8s resources |
| Verify Rollout | `kubectl rollout status` ตรวจสอบว่า pods ขึ้นสำเร็จ |

> หาก deployment ล้มเหลว pipeline จะ rollback อัตโนมัติด้วย `kubectl rollout undo`

Domains
- app.local     # frontend
- api.app.local # backend


### Accessing the Application

After deployment, access the application at:

| Service | URL |
|---------|-----|
| Frontend | http://app.local |
| Backend API | http://api.app.local |
| CDN | http://cdn.app.local |
| CDN Console | http://cdn-console.app.local |
| Jenkins | http://jenkins.devtool.local |
| Grafana | http://grafana.devtool.local |


### Monitoring and Logging

Monitoring is powered by **Prometheus** + **Grafana** deployed via `kube-prometheus-stack` (Helm) in the `devops` namespace.

#### Metrics Collection

The **frontend** exposes a `/metrics` endpoint (Prometheus format) via `prom-client`:

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total HTTP requests (labels: method, route, status) |
| `http_request_duration_seconds` | Histogram | Request latency in seconds |
| `nodejs_heap_size_used_bytes` | Gauge | Node.js heap memory usage |
| `process_cpu_seconds_total` | Counter | CPU usage |
| `nodejs_eventloop_lag_seconds` | Gauge | Event loop lag |

The **backend** (Golang/Gin) exposes metrics via `gin-contrib/prom`:

| Metric | Description |
|--------|-------------|
| `gin_request_duration_seconds` | HTTP request duration |
| `gin_request_size_bytes` | Request body size |
| `gin_response_size_bytes` | Response body size |
| `app_logins_total` | Total user logins |
| `app_registrations_total` | Total user registrations |
| `app_mangas_uploaded_total` | Total manga uploads |
| `go_gc_duration_seconds` | Go GC pause duration |

#### How Prometheus Scrapes Metrics

Prometheus discovers targets via **ServiceMonitor** (created by Terraform):

```
Frontend Pod (:3000/metrics)
    ↑  scrape every ~15s
ServiceMonitor (label: release=monitoring)
    ↑  discovered by
Prometheus (kube-prometheus-stack, namespace: devops)
    ↓  query
Grafana Dashboards
```

#### Grafana Dashboards

Dashboards are loaded **automatically** via ConfigMap (label: `grafana_dashboard: "1"`):

| Dashboard | Panels | File |
|-----------|--------|------|
| Frontend App Dashboard | 6 panels (Requests, Latency P95, RPS, CPU, Memory, Event Loop) | `infra/app/terraform/frontend-dashboard.json` |
| Backend Services Monitoring | 7 panels (Logins, Registrations, Uploads, Error Rate, Bandwidth, GC, RPS) | `infra/app/terraform/backend-dashboard.json` |

Access Grafana at: **http://grafana.devtool.local** (admin / ค่าจาก `grafana_password` ใน tfvars)