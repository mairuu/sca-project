locals {
  frontend_image = "${var.docker_hub_user}/sca-frontend:${var.image_tag}"
  backend_image  = "${var.docker_hub_user}/sca-backend:${var.image_tag}"
}

# -------------------------
# Secrets
# -------------------------

resource "kubernetes_secret_v1" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = "app"
  }

  data = {
    POSTGRES_PASSWORD   = var.postgres_password
    MINIO_ROOT_PASSWORD = var.minio_password
    JWT_SECRET          = var.jwt_secret
  }
}

# -------------------------
# ConfigMaps
# -------------------------

resource "kubernetes_config_map_v1" "backend_config" {
  metadata {
    name      = "backend-config"
    namespace = "app"
  }

  data = {
    APP_LOG_LEVEL    = "debug"
    HTTP_ADDR        = ":8080"
    DB_LOG_LEVEL     = "info"

    JWT_ACCESS_TOKEN_TTL  = "24h"
    JWT_REFRESH_TOKEN_TTL = "168h"

    PUBLIC_STORAGE_TYPE        = "minio"
    PUBLIC_MINIO_ENDPOINT      = "my-minio.app.svc.cluster.local:9000"
    PUBLIC_MINIO_BUCKET_NAME   = "mp-api-public"
    PUBLIC_MINIO_USE_SSL       = "false"

    TEMPORARY_STORAGE_TYPE      = "minio"
    TEMPORARY_MINIO_ENDPOINT    = "my-minio.app.svc.cluster.local:9000"
    TEMPORARY_MINIO_BUCKET_NAME = "mp-api-temp"
    TEMPORARY_MINIO_USE_SSL     = "false"

    CLEANUP_INTERVAL     = "1h"
    TEMPORARY_FILE_TTL   = "24h"
  }
}

resource "kubernetes_config_map_v1" "frontend_config" {
  metadata {
    name      = "frontend-config"
    namespace = "app"
  }

  data = {
    PUBLIC_API_BASE_URL = "http://api.app.local"
    PUBLIC_CDN_BASE_URL = "http://cdn.app.local"
  }
}

# -------------------------
# Backend
# -------------------------

resource "kubernetes_deployment_v1" "backend" {
  metadata {
    name      = "backend"
    namespace = "app"
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "backend" }
    }

    template {
      metadata {
        labels = { app = "backend" }
      }

      spec {
        // todo: turn this into a job
        init_container {
          name    = "run-migrations"
          image   = local.backend_image
          command = ["./migrate"]

          env_from {
            config_map_ref { name = kubernetes_config_map_v1.backend_config.metadata[0].name }
          }

          env {
            name = "SECRET_PG_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_secrets.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name  = "DB_DSN"
            value = "host=my-postgres-postgresql.app.svc.cluster.local user=${var.postgres_username} password=$(SECRET_PG_PASS) dbname=app_db port=5432 sslmode=disable"
          }
        }

        container {
          name  = "backend"
          image = local.backend_image

          port { container_port = 8080 }

          liveness_probe {
             http_get {
               path = "/health"
               port = 8080
             }
             initial_delay_seconds = 10
             period_seconds = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds = 5
          }

          env_from {
            config_map_ref { name = kubernetes_config_map_v1.backend_config.metadata[0].name }
          }

          env {
            name = "SECRET_PG_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_secrets.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name = "SECRET_MINIO_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_secrets.metadata[0].name
                key  = "MINIO_ROOT_PASSWORD"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_secrets.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          env {
            name  = "DB_DSN"
            value = "host=my-postgres-postgresql.app.svc.cluster.local user=${var.postgres_username} password=$(SECRET_PG_PASS) dbname=app_db port=5432 sslmode=disable"
          }

          env {
            name  = "PUBLIC_MINIO_ACCESS_KEY_ID"
            value = var.minio_root_user
          }
          env {
            name  = "PUBLIC_MINIO_SECRET_ACCESS_KEY"
            value = "$(SECRET_MINIO_PASS)"
          }
          env {
            name  = "TEMPORARY_MINIO_ACCESS_KEY_ID"
            value = var.minio_root_user
          }
          env {
            name  = "TEMPORARY_MINIO_SECRET_ACCESS_KEY"
            value = "$(SECRET_MINIO_PASS)"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "backend-service"
    namespace = "app"
  }

  spec {
    selector = { app = "backend" }
    type     = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# -------------------------
# Frontend
# -------------------------

resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name      = "frontend"
    namespace = "app"
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "frontend" }
    }

    template {
      metadata {
        labels = { app = "frontend" }
      }

      spec {
        container {
          name  = "frontend"
          image = local.frontend_image

          port { container_port = 3000 }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds = 5
          }

          env_from {
            config_map_ref { name = kubernetes_config_map_v1.frontend_config.metadata[0].name }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "frontend" {
  metadata {
    name      = "frontend-service"
    namespace = "app"
    labels    = { app = "frontend" }
  }

  spec {
    selector = { app = "frontend" }
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
  }
}

resource "kubernetes_manifest" "frontend_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "frontend-servicemonitor"
      namespace = "app"
      labels = {
        release = "monitoring"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "frontend"
        }
      }
      endpoints = [
        {
          port = "http"
          path = "/metrics"
        }
      ]
    }
  }
}

resource "kubernetes_config_map" "frontend_dashboard" {
  metadata {
    name      = "frontend-dashboard-config"
    namespace = "devops"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "frontend-dashboard.json" = file("${path.module}/frontend-dashboard.json")
  }
}
