output "db_host" {
  value = "${module.database.db_host}"
}

output "db_name" {
  value = "${module.database.db_name}"
}

output "db_user" {
  value = "${module.database.db_username}"
}

output "db_password" {
  value = "${module.database.db_password}"
}

output "alb_hostname" {
  value = "${module.ghost.load_balancer_hostname}"
}

output "alb_ip" {
  value = "${module.ghost.load_balancer_ip}"
}

output "eks_cluster_id" {
  value = "${module.eks.cluster_id}"
}

output "eks_cluster_name" {
  value = "${module.eks.cluster_name}"
}

data "aws_region" "current" {}

output "eks_region" {
  value = "${data.aws_region.current.name}"
}