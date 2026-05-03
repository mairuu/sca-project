# MinIO CDN — cdn.app.local/{PATH} -> my-minio:9000/mp-api-public/{PATH}
resource "kubernetes_ingress_v1" "minio_cdn" {
  metadata {
    name      = "minio-cdn-ingress"
    namespace = "app"
    annotations = {
      "kubernetes.io/ingress.class"                    = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target"     = "/mp-api-public/$2"
      "nginx.ingress.kubernetes.io/use-regex"          = "true"
    }
  }

  spec {
    rule {
      host = "cdn.app.local"
      http {
        path {
          path      = "/()(.*)"   # capture group $2 = the path after /
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "my-minio"
              port { number = 9000 }
            }
          }
        }
      }
    }
  }
}

# MinIO Console — cdn-console.app.local -> my-minio-console:9001
resource "kubernetes_ingress_v1" "minio_console" {
  metadata {
    name      = "minio-console-ingress"
    namespace = "app"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      host = "cdn-console.app.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "my-minio-console"
              port { number = 9001 }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "devops" {
  metadata {
    name      = "devops-ingress"
    namespace = "devops"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    # Grafana - grafana.devtool.local
    rule {
      host = "grafana.devtool.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-grafana"
              port { number = 80 }
            }
          }
        }
      }
    }

    # Jenkins - jenkins.devtool.local
    rule {
      host = "jenkins.devtool.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "jenkins"
              port { number = 8080 }
            }
          }
        }
      }
    }
  }
}
