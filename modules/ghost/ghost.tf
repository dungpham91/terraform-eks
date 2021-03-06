data "terraform_remote_state" "main" {
  backend = "s3"
  config = {
    bucket  = "eks-cluster-s3-backend"
    key     = "eks-cluster"
    region  = "ap-southeast-1"
  }
}

resource "kubernetes_namespace" "fargate" {
  metadata {
    labels = {
      app = "ghost"
    }
    name = "fargate-node"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "ghost-server"
    namespace = "fargate-node"
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

          env {
            name  = "database__client"
            value = "mysql"
          }
          env {
            name  = "database__connection__host"
            value = "${data.terraform_remote_state.main.outputs.db_host}"
          }
          env {
            name  = "database__connection__user"
            value = "dbadmin"
          }
          env {
            name  = "database__connection__password"
            value = "${data.terraform_remote_state.main.outputs.db_password}"
          }
          env {
            name  = "database__connection__database"
            value = "ghost"
          }
          env {
            name  = "url"
            value = "${data.terraform_remote_state.main.outputs.alb_hostname}"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.fargate]
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "ghost-service"
    namespace = "fargate-node"
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
    namespace = "fargate-node"
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