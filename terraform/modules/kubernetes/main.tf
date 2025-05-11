# Create kube-system namespace if it doesn't exist
resource "kubernetes_namespace" "kube_system" {
  metadata {
    name = "kube-system"
  }
}

# Create MongoDB deployment
resource "kubernetes_deployment" "mongodb" {
  metadata {
    name = "mongodb"
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }
      spec {
        container {
          image = "mongo:latest"
          name  = "mongodb"
          port {
            container_port = 27017
          }

          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = "root"
          }

          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
            value = "example"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Create MongoDB service
resource "kubernetes_service" "mongodb" {
  metadata {
    name = "mongodb"
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
    }
  }
}

# Create Backend deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name = "backend"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          image = "myselfabii/mern-backend:latest"
          name  = "backend"

          port {
            container_port = 5001
          }

          env {
            name  = "MONGODB_URI"
            value = "mongodb://root:example@mongodb:27017/mern-crud?authSource=admin"
          }

          env {
            name  = "PORT"
            value = "5001"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name  = "CORS_ORIGIN"
            value = "*"
          }

          env {
            name  = "CORS_METHODS"
            value = "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS"
          }

          env {
            name  = "CORS_CREDENTIALS"
            value = "true"
          }

          env {
            name  = "CORS_ALLOWED_HEADERS"
            value = "Content-Type,Authorization,X-Requested-With,Accept,Origin"
          }

          env {
            name  = "CORS_EXPOSED_HEADERS"
            value = "Content-Range,X-Content-Range"
          }

          env {
            name  = "CORS_MAX_AGE"
            value = "86400"
          }

          env {
            name  = "CORS_PREFLIGHT_CONTINUE"
            value = "false"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 5001
            }

            initial_delay_seconds = 30
            period_seconds       = 10
            timeout_seconds      = 1
            failure_threshold    = 3
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 5001
            }

            initial_delay_seconds = 5
            period_seconds       = 5
            timeout_seconds      = 1
            failure_threshold    = 3
          }
        }
      }
    }
  }
}

# Create Backend service
resource "kubernetes_service" "backend" {
  metadata {
    name = "backend"
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 80
      target_port = 5001
    }
  }
}

# Create Frontend deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name = "frontend"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          image = "myselfabii/mern-frontend:latest"
          name  = "frontend"

          port {
            container_port = 3000
          }

          env {
            name  = "NEXT_PUBLIC_API_URL"
            value = "http://k8s-mernapp-10da5b7777-954776261.us-east-1.elb.amazonaws.com/api"
          }

          env {
            name  = "NODE_ENV"
            value = "production"
          }

          env {
            name  = "NEXT_TELEMETRY_DISABLED"
            value = "1"
          }

          env {
            name  = "HOSTNAME"
            value = "0.0.0.0"
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          env {
            name  = "NEXT_PUBLIC_BASE_PATH"
            value = ""
          }

          env {
            name  = "NEXT_PUBLIC_ASSET_PREFIX"
            value = ""
          }

          env {
            name  = "NEXT_PUBLIC_STATIC_URL"
            value = "/_next/static"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }

            initial_delay_seconds = 30
            period_seconds       = 10
            timeout_seconds      = 1
            failure_threshold    = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 3000
            }

            initial_delay_seconds = 5
            period_seconds       = 5
            timeout_seconds      = 1
            failure_threshold    = 3
          }
        }
      }
    }
  }
}

# Create frontend service
resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend"
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

# Create Ingress
resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name = "app-ingress"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/group.name"      = "mern-app"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true"
      "alb.ingress.kubernetes.io/success-codes"   = "200-399"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/_next/static"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/_next/data"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/_next/image"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/static"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "backend"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} 