resource "kubernetes_namespace" "ghost-ns" {
  metadata {
    labels = {
      app = "ghost"
    }
    name = "ghost-ns"
  }
}

resource "kubernetes_persistent_volume_claim" "ghost-pvc" {
  metadata {
    name = "ghost-pvc"
    annotations = {
      "volume.beta.kubernetes.io/storage-class" = "ghost-efs-sc"
    }
    namespace = "ghost-ns"
    labels = {
      vol = "ghost-pvc"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
  timeouts {
    create = "60m"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "ghost-server"
    namespace = "ghost-ns"
    labels    = {
      app = "ghost"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "ghost"
      }
    }

    template {
      metadata {
        labels = {
          app = "ghost"
        }
      }

      spec {
        container {
          image = "ghost"
          name  = "ghost-server"

          port {
            container_port = 2368
          }

          volume_mount {
            name = "ghost-persistent-storage"
            mount_path = "/var/lib/ghost/content"
          }

          env {
            name  = "database__client"
            value = "mysql"
          }
          env {
            name  = "database__connection__host"
            value = "${var.database_host}"
          }
          env {
            name  = "database__connection__user"
            value = "dbadmin"
          }
          env {
            name  = "database__connection__password"
            value = "${var.database_password}"
          }
          env {
            name  = "database__connection__database"
            value = "ghost"
          }
          env {
            name  = "url"
            value = "${var.ghost_domain}"
          }
        }
        volume {
          name = "ghost-persistent-storage"
          persistent_volume_claim {
            claim_name = "ghost-pvc"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.ghost-ns
  ]
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "ghost-service"
    namespace = "ghost-ns"
  }
  spec {
    selector = {
      app = "ghost"
    }

    port {
      port        = 80
      target_port = 2368
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_deployment.app]
}

resource "kubernetes_ingress" "app" {
  metadata {
    name      = "ghost-lb"
    namespace = "ghost-ns"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
    labels = {
        "app" = "ghost"
    }
  }

  spec {
      backend {
        service_name = "ghost-service"
        service_port = 80
      }
    rule {
      http {
        path {
          path = "/"
          backend {
            service_name = "ghost-service"
            service_port = 80
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.app]
}