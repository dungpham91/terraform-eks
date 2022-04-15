output "load_balancer_hostname" {
  value = kubernetes_ingress.app.status.0.load_balancer.0.ingress.0.hostname
}

output "load_balancer_ip" {
  value = kubernetes_ingress.app.status.0.load_balancer.0.ingress.0.ip
}