resource "kubernetes_namespace_v1" "app" {
  metadata { name = "app" }
}

resource "kubernetes_namespace_v1" "devops" {
  metadata { name = "devops" }
}

# postgres
resource "helm_release" "postgres" {
  name       = "my-postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace_v1.app.metadata[0].name

  values = [yamlencode({
    auth = {
      username         = "app_user"
      password         = var.postgres_password
      postgresUsername = var.postgres_username
      postgresPassword = var.postgres_password
      database         = "app_db"
    }
    primary = {
      persistence = {
        size         = "2Gi"
        storageClass = var.storage_class
      }
      resources = {
        requests = { memory = "256Mi", cpu = "200m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
  })]
}

# minio
resource "helm_release" "minio" {
  name       = "my-minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.app.metadata[0].name

  values = [yamlencode({
    mode         = "standalone"
    replicas     = 1
    rootUser     = var.minio_root_user
    rootPassword = var.minio_password

    persistence = {
      size         = "2Gi"
      storageClass = var.storage_class
    }
    resources = {
      requests = { memory = "256Mi", cpu = "200m" }
      limits   = { memory = "512Mi", cpu = "500m" }
    }

    buckets = [
      { name = "mp-api-public", policy = "public" },
      { name = "mp-api-temp",   policy = "none"   },
    ]
  })]
}

# monitoring (Prometheus + Grafana)
resource "helm_release" "monitoring" {
  name       = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.devops.metadata[0].name

  values = [yamlencode({
    alertmanager = {
      alertmanagerSpec = { replicas = 1 }
    }
    prometheus = {
      prometheusSpec = {
        replicas  = 1
        resources = {
          requests = { memory = "256Mi", cpu = "200m" }
          limits   = { memory = "512Mi", cpu = "500m" }
        }
      }
    }
    grafana = {
      adminPassword = var.grafana_password
      resources = {
        requests = { memory = "256Mi", cpu = "200m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
  })]
}

locals {
  jenkins_values = yamlencode({
    controller = {
      initializeOnce = true
      admin = {
        username = "admin"
        password = var.jenkins_password
      }
      resources = {
        requests = { memory = "512Mi",  cpu = "500m" }
        limits   = { memory = "2048Mi", cpu = "2000m" }
      }
      installPlugins = [
        "kubernetes",
        "workflow-aggregator",
        "git",
        "configuration-as-code",
        "ssh-credentials",
        "ssh-slaves",
        "ws-cleanup",
        "pipeline-graph-view",
        "job-dsl",
      ]

      JCasC = {
        defaultConfig = false
        configScripts = {
          "main" = local.casc_yaml
        }
      }
    }

    persistence = {
      size         = "2Gi"
      storageClass = var.storage_class
    }
  })

  casc_yaml = <<-YAML
    jenkins:
      systemMessage: "Configured by JCasC — do not edit manually."

      securityRealm:
        local:
          allowsSignup: false
          users:
            - id: "admin"
              password: "${var.jenkins_password}"

      authorizationStrategy:
        loggedInUsersCanDoAnything:
          allowAnonymousRead: false

      nodes:
        - permanent:
            name: "builder"
            labelString: "builder host-agent"
            remoteFS: ${var.builder_remote_fs}
            numExecutors: 2
            retentionStrategy: "always"
            launcher:
              ssh:
                host: "${var.builder_host}"
                port: 22
                credentialsId: "builder-ssh-key"
                launchTimeoutSeconds: 60
                maxNumRetries: 3
                retryWaitTime: 30
                sshHostKeyVerificationStrategy:
                  manuallyTrustedKeyVerificationStrategy:
                    requireInitialManualTrust: false

    credentials:
      system:
        domainCredentials:
          - credentials:
              - usernamePassword:
                  id: "dockerhub-creds"
                  description: "DockerHub username + password"
                  username: "${var.dockerhub_username}"
                  password: "${var.dockerhub_password}"
                  scope: GLOBAL

              - basicSSHUserPrivateKey:
                  id: "builder-ssh-key"
                  description: "SSH key for builder agent"
                  username: "${var.builder_username}"
                  privateKeySource:
                    directEntry:
                      privateKey: |
                        ${indent(24, var.builder_ssh_private_key)}
                  scope: GLOBAL

              - string:
                  id: "MINIO_PASSWORD"
                  description: "MinIO secret key"
                  secret: "${var.minio_password}"
                  scope: GLOBAL

              - string:
                  id: "POSTGRES_PASSWORD"
                  description: "PostgreSQL password"
                  secret: "${var.postgres_password}"
                  scope: GLOBAL

              - string:
                  id: "JWT_SECRET"
                  description: "JWT signing secret"
                  secret: "${var.jwt_secret}"
                  scope: GLOBAL

              - string:
                  id: "POSTGRES_USERNAME"
                  description: "PostgreSQL username"
                  secret: "${var.postgres_username}"
                  scope: GLOBAL

              - string:
                  id: "MINIO_ROOT_USER"
                  description: "MinIO root username"
                  secret: "${var.minio_root_user}"
                  scope: GLOBAL

    jobs:
      - script: |
          pipelineJob('build-and-push') {
            description('CI — build Docker image and push to registry')
            definition {
              cpsScm {
                scm {
                  git {
                    remote { url('https://github.com/mairuu/sca-project') }
                    branch('*/main')
                  }
                }
                scriptPath('infra/app/ci/Jenkinsfile.ci')
                lightweight(true)
              }
            }
          }

      - script: |
          pipelineJob('pull-and-deploy') {
            description('CD — pull image and deploy to cluster')
            definition {
              cpsScm {
                scm {
                  git {
                    remote { url('https://github.com/mairuu/sca-project') }
                    branch('*/main')
                  }
                }
                scriptPath('infra/app/cd/Jenkinsfile.cd')
                lightweight(true)
              }
            }
          }
  YAML
}

# jenkins
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace_v1.devops.metadata[0].name
  values     = [local.jenkins_values]
}