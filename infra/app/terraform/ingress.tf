resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "app-ingress"
    namespace = "app"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    # Backend — api.app.local
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

