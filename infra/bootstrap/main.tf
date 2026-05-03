resource "kubernetes_namespace_v1" "app" {
  metadata { name = "app" }
}

resource "kubernetes_namespace_v1" "devops" {
  metadata { name = "devops" }
}

resource "helm_release" "postgres" {
  name       = "my-postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace_v1.app.metadata[0].name

  set = [
    { name = "auth.username",                     value = "app_user" },
    { name = "auth.password",                     value = var.postgres_password },
    { name = "auth.postgresUsername",             value = "postgres" },
    { name = "auth.postgresPassword",             value = var.postgres_password },
    { name = "auth.database",                     value = "app_db" },
    { name = "primary.persistence.size",          value = "2Gi" },
    { name = "persistence.storageClass",          value = var.storage_class },
    { name = "primary.resources.requests.memory", value = "256Mi" },
    { name = "primary.resources.requests.cpu",    value = "200m" },
    { name = "primary.resources.limits.memory",   value = "512Mi" },
    { name = "primary.resources.limits.cpu",      value = "500m" }
  ]
}

# minio
resource "helm_release" "minio" {
  name       = "my-minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.app.metadata[0].name

  set = [
    { name = "mode",                       value = "standalone" },
    { name = "replicas",                   value = "1" },
    { name = "rootUser",                   value = "minioadmin" },
    { name = "rootPassword",               value = var.minio_password },
    { name = "persistence.size",           value = "2Gi" },
    { name = "persistence.storageClass",   value = var.storage_class },
    { name = "resources.requests.memory",  value = "256Mi" },
    { name = "resources.requests.cpu",     value = "200m" },
    { name = "resources.limits.memory",    value = "512Mi" },
    { name = "resources.limits.cpu",       value = "500m" },
    { name = "buckets[0].name",            value = "mp-api-public" },
    { name = "buckets[0].policy",          value = "public" },
    { name = "buckets[1].name",            value = "mp-api-temp" },
    { name = "buckets[1].policy",          value = "none" }
  ]
}

# prometheus + grafana
resource "helm_release" "monitoring" {
  name       = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.devops.metadata[0].name

  set = [
    { name = "alertmanager.alertmanagerSpec.replicas",              value = "1" },
    { name = "prometheus.prometheusSpec.replicas",                  value = "1" },
    { name = "prometheus.prometheusSpec.resources.requests.memory", value = "256Mi" },
    { name = "prometheus.prometheusSpec.resources.requests.cpu",    value = "200m" },
    { name = "prometheus.prometheusSpec.resources.limits.memory",   value = "512Mi" },
    { name = "prometheus.prometheusSpec.resources.limits.cpu",      value = "500m" },
    { name = "grafana.resources.requests.memory",                   value = "256Mi" },
    { name = "grafana.resources.requests.cpu",                      value = "200m" },
    { name = "grafana.resources.limits.memory",                     value = "512Mi" },
    { name = "grafana.resources.limits.cpu",                        value = "500m" },
    { name = "grafana.adminPassword",                               value = var.grafana_password }
  ]
}

# jenkins
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace_v1.devops.metadata[0].name

  set = [
    { name = "controller.initializeOnce",      value = "true" },
    { name = "controller.admin.username",      value = "admin" },
    { name = "controller.admin.password",      value = var.jenkins_password },
    { name = "persistence.size",               value = "2Gi" },
    { name = "persistence.storageClass",       value = var.storage_class },
    { name = "resources.requests.memory",      value = "256Mi" },
    { name = "resources.requests.cpu",         value = "200m" },
    { name = "resources.limits.memory",        value = "512Mi" },
    { name = "resources.limits.cpu",           value = "500m" },
    { name = "controller.installPlugins[0]",   value = "kubernetes" },
    { name = "controller.installPlugins[1]",   value = "workflow-aggregator" },
    { name = "controller.installPlugins[2]",   value = "git" },
    { name = "controller.installPlugins[3]",   value = "configuration-as-code" },
    { name = "controller.installPlugins[4]",   value = "ssh-credentials" },
    { name = "controller.installPlugins[5]",   value = "ssh-slaves" },
    { name = "controller.installPlugins[6]",   value = "ws-cleanup" },
    { name = "controller.installPlugins[7]",   value = "pipeline-graph-view" }
  ]
}