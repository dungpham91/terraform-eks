data "aws_eks_cluster" "cluster" {
  name = var.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_id
}

data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_service_account" "ghost-efs-provisioner" {
  metadata {
    name      = "ghost-efs-provisioner"
    namespace = "ghost-ns"
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "ghost-efs-provisioner-runner" {
  metadata {
    name = "ghost-efs-provisioner-runner"
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "update"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "ghost-efs-rb" {
  metadata {
    name = "ghost-efs-rb"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "ghost-efs-provisioner-runner"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "ghost-efs-provisioner"
    namespace = "ghost-ns"
  }
}

resource "kubernetes_role" "leader-locking-efs-provisioner" {
  metadata {
    name      = "leader-locking-efs-provisioner"
    namespace = "ghost-ns"
  }
  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "leader-locking-efs-provisioner" {
  metadata {
    name      = "leader-locking-efs-provisioner"
    namespace = "ghost-ns"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "leader-locking-efs-provisioner"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "ghost-efs-provisioner"
    namespace = "ghost-ns"
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_storage_class" "ghost-efs-sc" {
  metadata {
    name = "ghost-efs-sc"
  }
  storage_provisioner = "example.com/aws-efs"
  reclaim_policy      = "Retain"
}

resource "kubernetes_deployment" "ghost-efs-provisioner" {

  depends_on = [
    kubernetes_storage_class.ghost-efs-sc
  ]

  metadata {
    name = "ghost-efs-provisioner"
    namespace = "ghost-ns"
  }

  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = {
        app = "ghost-efs-provisioner"
      }
    }

    template {
      metadata {
        labels = {
          app = "ghost-efs-provisioner"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          image = "quay.io/external_storage/efs-provisioner:latest"
          name  = "ghost-efs-provisioner"
          env {
            name  = "FILE_SYSTEM_ID"
            value = aws_efs_file_system.ghost-efs.id
          }
          env {
            name  = "AWS_REGION"
            value = "ap-southeast-1"
          }
          env {
            name  = "PROVISIONER_NAME"
            value = kubernetes_storage_class.ghost-efs-sc.storage_provisioner
          }
          volume_mount {
            name       = "pv-volume"
            mount_path = "/persistentvolumes"
          }
        }
        volume {
          name = "pv-volume"
          nfs {
            server = aws_efs_file_system.ghost-efs.dns_name
            path   = "/persistentvolumes"
          }
        }
      }
    }
  }
}

resource "aws_security_group" "ghost-efs-sg" {
  name        = "ghost-efs-sg"
  description = "Communication to EFS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ghost-efs-sg"
  }
}

resource "aws_efs_file_system" "ghost-efs" {
  creation_token = "ghost-efs"
  tags = {
    Name = "ghost-efs"
  }
}

resource "aws_efs_mount_target" "ghost_efs_mnt_target" {
  count = length(var.private_subnets_cidr)
  file_system_id = aws_efs_file_system.ghost-efs.id
  subnet_id      = element(var.private_subnets, count.index)
  security_groups = [aws_security_group.ghost-efs-sg.id]
}

resource "aws_efs_access_point" "ghost-efs-access-point" {
  file_system_id = aws_efs_file_system.ghost-efs.id
}