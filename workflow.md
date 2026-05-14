# Workflow — Comic Reader (SCA Project)

> เอกสารอธิบายการทำงานของแต่ละ Phase ในโปรเจค ตั้งแต่การพัฒนาแอปพลิเคชัน จนถึงการ Deploy และ Monitor บน Kubernetes

---

## สารบัญ

1. [โครงสร้างโปรเจค](#โครงสร้างโปรเจค)
2. [ภาพรวม Phase ทั้งหมด](#ภาพรวม-phase-ทั้งหมด)
3. [Phase 1 — Application Development](#phase-1--application-development)
4. [Phase 2 — Containerization (Docker)](#phase-2--containerization-docker)
5. [Phase 3 — CI/CD Pipeline (Jenkins)](#phase-3--cicd-pipeline-jenkins)
6. [Phase 4 — Kubernetes Deployment](#phase-4--kubernetes-deployment)
7. [Phase 5 — Monitoring (Prometheus + Grafana)](#phase-5--monitoring-prometheus--grafana)
8. [Phase 6 — Configuration Management (Ansible)](#phase-6--configuration-management-ansible)
9. [ลำดับการ Deploy ทั้งระบบ](#ลำดับการ-deploy-ทั้งระบบ)
10. [Credential Flow](#credential-flow)

---

## โครงสร้างโปรเจค

```
sca-project/
├── backend/                          # แอปพลิเคชันฝั่ง Backend (Golang/Gin)
│   ├── cmd/
│   │   ├── api/                      #   → Entry point: HTTP server
│   │   └── migrate/                  #   → Entry point: Database migration
│   ├── internal/
│   │   ├── app/                      #   → Application wiring
│   │   ├── features/                 #   → Business logic (แยกตาม feature)
│   │   ├── persistence/              #   → Database layer
│   │   └── platform/                 #   → Shared utilities
│   ├── Dockerfile                    #   → Multi-stage build image
│   └── compose.yml                   #   → Dev dependencies (Postgres, MinIO)
│
├── frontend/                         # แอปพลิเคชันฝั่ง Frontend (SvelteKit)
│   ├── src/
│   │   ├── routes/                   #   → Pages & API routes
│   │   ├── lib/                      #   → Shared components
│   │   └── hooks.server.ts           #   → Server hooks (metrics)
│   └── Dockerfile                    #   → Multi-stage build image
│
├── infra/                            # Infrastructure ทั้งหมด
│   ├── ansible/                      #   → Phase 6: Configuration Management
│   │   ├── site.yml                  #     Main playbook
│   │   ├── inventory.ini             #     กำหนด host ของ builder node
│   │   ├── ansible.cfg               #     Ansible config
│   │   └── roles/
│   │       ├── common/tasks/main.yml #     ติดตั้ง packages พื้นฐาน
│   │       ├── docker/tasks/main.yml #     ติดตั้ง Docker Engine
│   │       ├── kubectl/tasks/main.yml#     ติดตั้ง kubectl
│   │       └── terraform/tasks/main.yml#   ติดตั้ง Terraform
│   │
│   ├── bootstrap/                    #   → Phase 3+4+5: Bootstrap infrastructure
│   │   ├── main.tf                   #     สร้าง Jenkins, PostgreSQL, MinIO, Monitoring
│   │   ├── ingress.tf                #     Ingress สำหรับ Jenkins, Grafana, MinIO
│   │   ├── variables.tf              #     ตัวแปรทั้งหมด (passwords, keys)
│   │   └── versions.tf               #     Terraform + Helm providers
│   │
│   └── app/                          #   → Phase 3+4: Application CI/CD + K8s
│       ├── ci/Jenkinsfile.ci         #     CI pipeline (build & push Docker image)
│       ├── cd/Jenkinsfile.cd         #     CD pipeline (deploy to K8s via Terraform)
│       └── terraform/
│           ├── main.tf               #     K8s Deployments, Services, Secrets, ConfigMaps
│           ├── ingress.tf            #     Ingress สำหรับ app.local, api.app.local
│           ├── variables.tf          #     ตัวแปร (image_tag, credentials)
│           ├── versions.tf           #     Kubernetes provider + backend
│           ├── frontend-dashboard.json#    Grafana dashboard (Frontend)
│           └── backend-dashboard.json #    Grafana dashboard (Backend)
│
└── scripts/
    └── configure-dns.sh              # สคริปต์ตั้งค่า DNS (*.local → Minikube)
```

---

## ภาพรวม Phase ทั้งหมด

```
Phase 6 (Ansible)          Phase 1 (Dev)           Phase 2 (Docker)
Provision Builder    →    พัฒนา App          →    สร้าง Docker Image
                          Frontend + Backend
                               │
                               ▼
                     Phase 3 (CI/CD — Jenkins)
                     ┌─────────────────────────┐
                     │  CI: Build & Push Image  │
                     │  CD: Deploy to K8s       │
                     └────────────┬────────────┘
                                  ▼
                     Phase 4 (Kubernetes)
                     ┌─────────────────────────┐
                     │  Deployments, Services   │
                     │  Secrets, ConfigMaps     │
                     │  Ingress (Nginx)         │
                     └────────────┬────────────┘
                                  ▼
                     Phase 5 (Monitoring)
                     ┌─────────────────────────┐
                     │  Prometheus → scrape     │
                     │  Grafana → dashboard     │
                     └─────────────────────────┘
```

---

## Phase 1 — Application Development

### หน้าที่
พัฒนา Web Application สำหรับอ่านการ์ตูนออนไลน์ แบ่งเป็น Frontend และ Backend

### Frontend (SvelteKit)

| รายการ | รายละเอียด |
|--------|------------|
| Framework | SvelteKit + TypeScript |
| Port | 3000 |
| ไฟล์หลัก | `frontend/src/routes/` (pages), `frontend/src/lib/` (components) |
| Metrics | `frontend/src/hooks.server.ts` — expose `/metrics` ด้วย `prom-client` |
| รัน Dev | `cd frontend && npm run dev -- --host` |

### Backend (Golang/Gin)

| รายการ | รายละเอียด |
|--------|------------|
| Framework | Go + Gin |
| Port | 8080 |
| Entry points | `backend/cmd/api/` (HTTP server), `backend/cmd/migrate/` (DB migration) |
| Business logic | `backend/internal/features/` |
| Database layer | `backend/internal/persistence/` |
| Metrics | expose `/metrics` ด้วย `gin-contrib/prom` |
| Dependencies | PostgreSQL (ฐานข้อมูล), MinIO (object storage) |
| รัน Dev | `cd backend && docker compose up -d && go run ./cmd/migrate && go run ./cmd/api` |

### ไฟล์ที่เกี่ยวข้อง
- `backend/compose.yml` — รัน PostgreSQL + MinIO สำหรับ development
- `backend/.env` — Environment variables สำหรับ dev

---

## Phase 2 — Containerization (Docker)

### หน้าที่
สร้าง Docker Image สำหรับ Frontend และ Backend เพื่อให้พร้อม deploy บน Kubernetes

### Frontend Dockerfile (`frontend/Dockerfile`)

```
Stage 1 (builder): node:24-alpine
  → npm ci → npm run build

Stage 2 (production): node:24-alpine
  → npm ci --omit=dev → copy build/ → CMD ["node", "build"]
  → EXPOSE 3000
```

### Backend Dockerfile (`backend/Dockerfile`)

```
Stage 1 (builder): golang:1.25-alpine
  → go mod download → go build ./cmd/api → go build ./cmd/migrate

Stage 2 (production): alpine:3.23
  → copy api + migrate binaries → CMD ["./api"]
  → EXPOSE 8080
```

### ทำงานร่วมกับ
- **Phase 3 (CI)** — Jenkins CI pipeline เรียก `docker build` จาก Dockerfile เหล่านี้
- **Phase 4 (K8s)** — Kubernetes ดึง image จาก Docker Hub ไปรันเป็น Pod

---

## Phase 3 — CI/CD Pipeline (Jenkins)

### หน้าที่
สร้างระบบ CI/CD อัตโนมัติ ประกอบด้วย 2 pipeline: **CI** (build & push) และ **CD** (deploy)

### 3.1 Bootstrap — ตั้งค่า Jenkins (`infra/bootstrap/main.tf`)

Bootstrap ใช้ Terraform + Helm ติดตั้ง Jenkins ลง Kubernetes namespace `devops`:

- ติดตั้ง Jenkins ผ่าน Helm chart
- ใช้ **JCasC** (Jenkins Configuration as Code) seed ทุกอย่างอัตโนมัติ:
  - สร้าง admin user
  - สร้าง **builder node** (SSH agent เชื่อมไปยัง builder machine)
  - สร้าง **credentials** ทั้งหมด (DockerHub, SSH key, DB passwords, JWT secret)
  - สร้าง **pipeline jobs** 2 ตัว: `build-and-push` (CI) และ `pull-and-deploy` (CD)

### 3.2 CI Pipeline (`infra/app/ci/Jenkinsfile.ci`)

**Agent:** `builder` (รันบน builder node ภายนอก cluster)

| Stage | ทำอะไร |
|-------|--------|
| **Checkout** | ดึงโค้ดจาก GitHub + update submodules |
| **Build** | `docker build` Frontend และ Backend **พร้อมกัน** (parallel) |
| **Push** | Login Docker Hub → push image ด้วย tag ที่กำหนด + tag `latest` |
| **Post (always)** | ลบ image ออกจาก builder + logout + cleanWs |

**Input:** รับ parameter `IMAGE_TAG` (เช่น `1.0.0`)
**Output:** Docker images บน Docker Hub → `{user}/sca-frontend:{tag}` และ `{user}/sca-backend:{tag}`

### 3.3 CD Pipeline (`infra/app/cd/Jenkinsfile.cd`)

**Agent:** `host-agent` (รันบนเครื่องที่เข้าถึง K8s cluster ได้)

| Stage | ทำอะไร |
|-------|--------|
| **Checkout** | ดึงโค้ดล่าสุดจาก GitHub |
| **Terraform Init** | `terraform init` ใน `infra/app/terraform/` |
| **Inject Secrets & Plan** | ดึง credentials จาก Jenkins → ส่งเป็น `-var` → `terraform plan -out=tfplan` |
| **Apply** | `terraform apply -auto-approve tfplan` → สร้าง/อัปเดต K8s resources |
| **Verify Rollout** | `kubectl rollout status` ตรวจสอบว่า pods ขึ้นสำเร็จ |
| **Post (failure)** | rollback อัตโนมัติด้วย `kubectl rollout undo` |

**Input:** รับ parameter `IMAGE_TAG` (ต้องตรงกับที่ CI build ไว้)
**Output:** Application ถูก deploy/update บน Kubernetes

### ทำงานร่วมกับ
- **Phase 2** — CI ใช้ Dockerfile ของ Phase 2 ในการ build
- **Phase 4** — CD ใช้ Terraform configs ใน `infra/app/terraform/` เพื่อสร้าง K8s resources
- **Phase 6** — Builder node ต้องถูก provision ด้วย Ansible ก่อน

---

## Phase 4 — Kubernetes Deployment

### หน้าที่
จัดการ Kubernetes resources ทั้งหมดผ่าน Terraform (Infrastructure as Code)

### 4.1 Bootstrap Resources (`infra/bootstrap/`)

สร้าง infrastructure พื้นฐานใน cluster:

| Resource | Namespace | วิธีสร้าง | รายละเอียด |
|----------|-----------|-----------|------------|
| PostgreSQL | `app` | Helm (Bitnami) | ฐานข้อมูลหลัก, PVC 2Gi |
| MinIO | `app` | Helm (MinIO) | Object storage, bucket: `mp-api-public`, `mp-api-temp` |
| Jenkins | `devops` | Helm + JCasC | CI/CD server |
| Prometheus + Grafana | `devops` | Helm (kube-prometheus-stack) | Monitoring stack |
| Ingress (devops) | `devops` | Terraform | `jenkins.devtool.local`, `grafana.devtool.local` |
| Ingress (MinIO) | `app` | Terraform | `cdn.app.local`, `cdn-console.app.local` |

**ไฟล์:** `infra/bootstrap/main.tf`, `infra/bootstrap/ingress.tf`

### 4.2 Application Resources (`infra/app/terraform/`)

สร้าง resources สำหรับแอปพลิเคชัน:

| Resource | ประเภท | รายละเอียด |
|----------|--------|------------|
| `backend-secrets` | Secret | POSTGRES_PASSWORD, MINIO_ROOT_PASSWORD, JWT_SECRET |
| `backend-config` | ConfigMap | DB connection, MinIO endpoint, JWT TTL ฯลฯ |
| `frontend-config` | ConfigMap | API_BASE_URL, CDN_BASE_URL |
| `backend` | Deployment | Init container (migrate) + main container (api), port 8080 |
| `frontend` | Deployment | SvelteKit app, port 3000 |
| `backend-service` | Service (ClusterIP) | เปิด port 8080 |
| `frontend-service` | Service (ClusterIP) | เปิด port 3000 |
| `app-ingress` | Ingress | `app.local` → frontend, `api.app.local` → backend |
| ServiceMonitor (x2) | Monitoring | ให้ Prometheus scrape `/metrics` จาก frontend + backend |
| Dashboard ConfigMap (x2) | Grafana | โหลด dashboard JSON อัตโนมัติ |

**ไฟล์:** `infra/app/terraform/main.tf`, `infra/app/terraform/ingress.tf`

### Terraform State
- **Bootstrap:** state เก็บเป็นไฟล์ local (`terraform.tfstate`)
- **App:** state เก็บใน Kubernetes Secret (`backend "kubernetes"` ใน namespace `devops`)

### ทำงานร่วมกับ
- **Phase 3 (CD)** — CD pipeline เรียก `terraform apply` เพื่อสร้าง/อัปเดต resources เหล่านี้
- **Phase 5** — ServiceMonitor + Dashboard ConfigMap เชื่อม Prometheus/Grafana

---

## Phase 5 — Monitoring (Prometheus + Grafana)

### หน้าที่
เก็บ metrics จากแอปพลิเคชันและแสดงผลบน dashboard

### สถาปัตยกรรม

```
Frontend Pod (:3000/metrics)  ──┐
                                ├── ServiceMonitor ── Prometheus ── Grafana
Backend Pod  (:8080/metrics)  ──┘     (label: release=monitoring)
```

### Frontend Metrics (`prom-client`)

| Metric | Type | คำอธิบาย |
|--------|------|----------|
| `http_requests_total` | Counter | จำนวน HTTP requests ทั้งหมด |
| `http_request_duration_seconds` | Histogram | ความเร็วในการตอบสนอง |
| `nodejs_heap_size_used_bytes` | Gauge | Memory usage |
| `process_cpu_seconds_total` | Counter | CPU usage |
| `nodejs_eventloop_lag_seconds` | Gauge | Event loop lag |

### Backend Metrics (`gin-contrib/prom`)

| Metric | คำอธิบาย |
|--------|----------|
| `gin_request_duration_seconds` | HTTP request duration |
| `app_logins_total` | จำนวน login ทั้งหมด |
| `app_registrations_total` | จำนวนสมัครสมาชิก |
| `app_mangas_uploaded_total` | จำนวนมังงะที่อัปโหลด |
| `go_gc_duration_seconds` | Go GC pause duration |

### Grafana Dashboards

| Dashboard | Panels | ไฟล์ |
|-----------|--------|------|
| Frontend App Dashboard | 6 panels | `infra/app/terraform/frontend-dashboard.json` |
| Backend Services Monitoring | 7 panels | `infra/app/terraform/backend-dashboard.json` |

Dashboard ถูกโหลดอัตโนมัติผ่าน ConfigMap ที่มี label `grafana_dashboard: "1"` (Grafana sidecar ตรวจจับและ import)

### ทำงานร่วมกับ
- **Phase 1** — App เป็นผู้ expose `/metrics` endpoint
- **Phase 4** — ServiceMonitor + Dashboard ConfigMap สร้างโดย Terraform ใน `infra/app/terraform/main.tf`
- **Bootstrap** — Prometheus + Grafana ติดตั้งผ่าน `infra/bootstrap/main.tf`

---

## Phase 6 — Configuration Management (Ansible)

### หน้าที่
ตั้งค่า (provision) **Builder Node** ให้มีเครื่องมือที่จำเป็นสำหรับรัน CI/CD pipeline

### Builder Node คืออะไร?
เครื่อง Linux ภายนอก K8s cluster ที่ Jenkins ใช้เป็น agent สำหรับรัน CI pipeline (build Docker image)

### Ansible Playbook (`infra/ansible/site.yml`)

```yaml
- name: Configure Jenkins Builder Node
  hosts: builder_nodes    # กำหนดใน inventory.ini
  become: true            # รันด้วย sudo
  roles:
    - common              # 1. ติดตั้ง packages พื้นฐาน
    - docker              # 2. ติดตั้ง Docker Engine
    - kubectl             # 3. ติดตั้ง kubectl
    - terraform           # 4. ติดตั้ง Terraform
```

### Roles ทั้ง 4 ตัว

| Role | ไฟล์ | ทำอะไร |
|------|------|--------|
| **common** | `roles/common/tasks/main.yml` | `apt update` + ติดตั้ง curl, wget, git, unzip, ca-certificates, gnupg ฯลฯ |
| **docker** | `roles/docker/tasks/main.yml` | เพิ่ม Docker GPG key + apt repo → ติดตั้ง docker-ce, containerd, buildx, compose → เพิ่ม user เข้า docker group |
| **kubectl** | `roles/kubectl/tasks/main.yml` | ดาวน์โหลด kubectl v1.30.0 binary → สร้าง `.kube` directory |
| **terraform** | `roles/terraform/tasks/main.yml` | ดาวน์โหลด Terraform 1.9.0 zip → แตกไฟล์ไปที่ `/usr/local/bin/` |

### Inventory (`infra/ansible/inventory.ini`)

```ini
[builder_nodes]
builder ansible_host=172.26.51.181 ansible_user=exexpeem
```

### วิธีรัน

```bash
cd infra/ansible
ansible-playbook site.yml
```

### ทำงานร่วมกับ
- **Phase 3 (CI)** — Builder node ที่ถูก provision จะเป็น Jenkins agent สำหรับ build Docker image
- **Bootstrap** — Jenkins ใน bootstrap ถูก config ให้เชื่อมต่อ builder node ผ่าน SSH

---

## ลำดับการ Deploy ทั้งระบบ

```
ขั้นตอนที่ 1: Provision Builder Node (ครั้งเดียว)
─────────────────────────────────────────────────
  cd infra/ansible
  ansible-playbook site.yml
  → ติดตั้ง Docker, kubectl, Terraform บน builder machine

ขั้นตอนที่ 2: Bootstrap Infrastructure (ครั้งเดียว)
─────────────────────────────────────────────────
  cd infra/bootstrap
  cp terraform.tfvars.example terraform.tfvars   # แก้ค่า credentials
  terraform init
  terraform apply
  → สร้าง Jenkins, PostgreSQL, MinIO, Prometheus, Grafana บน K8s

ขั้นตอนที่ 3: ตั้งค่า DNS
─────────────────────────────────────────────────
  # เพิ่มใน /etc/hosts หรือใช้ scripts/configure-dns.sh
  {CLUSTER_IP}  jenkins.devtool.local
  {CLUSTER_IP}  grafana.devtool.local
  {CLUSTER_IP}  cdn.app.local
  {CLUSTER_IP}  cdn-console.app.local

ขั้นตอนที่ 4: รัน CI Pipeline (ทุกครั้งที่มีโค้ดใหม่)
─────────────────────────────────────────────────
  Jenkins → build-and-push → ใส่ IMAGE_TAG → Build
  → docker build frontend + backend → push to Docker Hub

ขั้นตอนที่ 5: รัน CD Pipeline (ทุกครั้งที่จะ deploy)
─────────────────────────────────────────────────
  Jenkins → pull-and-deploy → ใส่ IMAGE_TAG → Build
  → terraform plan/apply → สร้าง K8s Deployments, Services, Ingress
  → kubectl rollout status → ตรวจสอบ pods

ขั้นตอนที่ 6: เข้าใช้งาน
─────────────────────────────────────────────────
  http://app.local           → Frontend
  http://api.app.local       → Backend API
  http://grafana.devtool.local → Grafana Dashboard
```

---

## Credential Flow

```
terraform.tfvars (bootstrap)
        │
        ▼
   Terraform Apply
        │
        ├──→ Helm: PostgreSQL (password)
        ├──→ Helm: MinIO (password)
        ├──→ Helm: Jenkins (JCasC seed credentials)
        │         │
        │         ▼
        │    Jenkins Credentials Store
        │         │
        │         ├── dockerhub-creds (username/password)
        │         ├── builder-ssh-key (SSH private key)
        │         ├── POSTGRES_PASSWORD
        │         ├── POSTGRES_USERNAME
        │         ├── MINIO_PASSWORD
        │         ├── MINIO_ROOT_USER
        │         └── JWT_SECRET
        │              │
        │              ▼
        │    CD Pipeline (Jenkinsfile.cd)
        │         │
        │         ▼
        │    terraform plan -var="..." (inject credentials)
        │         │
        │         ▼
        │    K8s Secrets + ConfigMaps
        │         │
        │         ▼
        └──→ Application Pods (env vars)
```

> Credentials ไหลจาก `terraform.tfvars` → Jenkins (JCasC) → CD Pipeline → Terraform → K8s Secrets → Pods
> ไม่มี credential ถูก hardcode ในโค้ด

---

## สรุป Domain ทั้งหมด

| Domain | Service | Namespace |
|--------|---------|-----------|
| `app.local` | Frontend (SvelteKit) | app |
| `api.app.local` | Backend (Golang/Gin) | app |
| `cdn.app.local` | MinIO (public bucket) | app |
| `cdn-console.app.local` | MinIO Console | app |
| `jenkins.devtool.local` | Jenkins | devops |
| `grafana.devtool.local` | Grafana | devops |
