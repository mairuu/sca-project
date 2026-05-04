resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "app-ingress"
    namespace = "app"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "8m"
    }
  }

  spec {
    # frontend — app.local
    rule {
      host = "app.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.frontend.metadata[0].name
              port { number = 3000 }
            }
          }
        }
      }
    }

    # backend — api.app.local
    rule {
      host = "api.app.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.backend.metadata[0].name
              port { number = 8080 }
            }
          }
        }
      }
    }
  }
}

