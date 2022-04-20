data "aws_efs_file_system" "ghost-efs" {
  creation_token = "ghost-efs"
}

resource "kubernetes_storage_class" "ghost-efs-sc" {
  metadata {
    name = "ghost-efs-sc"
  }
  storage_provisioner = "aws-efs/tf-eks-sc"
  reclaim_policy      = "Retain"
}

resource "kubernetes_cluster_role_binding" "ghost-efs-rb" {
  metadata {
    name = "ghost-efs-rb"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "ghost-ns"
  }
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
        app = "ghost-efs"
      }
    }

    template {
      metadata {
        labels = {
          app = "ghost-efs"
        }
      }

      spec {
        automount_service_account_token = true
        container {
          image = "quay.io/external_storage/efs-provisioner:v0.1.0"
          name  = "ghost-efs-provision"
          env {
            name  = "FILE_SYSTEM_ID"
            value = data.aws_efs_file_system.ghost-efs.file_system_id
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
            server = data.aws_efs_file_system.ghost-efs.dns_name
            path   = "/"
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