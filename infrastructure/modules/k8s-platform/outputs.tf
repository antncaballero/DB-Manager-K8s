output "storage_class_name" {
  description = "Nombre lógico de la StorageClass usada por la plataforma."
  value       = var.storage_class_name
}

output "ingress_namespace" {
  description = "Namespace donde está desplegado ingress-nginx."
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "ingress_release_name" {
  description = "Nombre del release Helm de ingress-nginx."
  value       = helm_release.ingress_nginx.name
}

output "ingress_release_status" {
  description = "Estado del release Helm de ingress-nginx."
  value       = try(helm_release.ingress_nginx.status, "pending")
}

output "monitoring_namespace" {
  description = "Namespace donde se despliega el stack de monitoring."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "monitoring_release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  value       = helm_release.kube_prometheus_stack.name
}

output "monitoring_release_status" {
  description = "Estado del release Helm de kube-prometheus-stack."
  value       = try(helm_release.kube_prometheus_stack.status, "pending")
}

output "keda_namespace" {
  description = "Namespace donde está instalado KEDA."
  value       = kubernetes_namespace.keda.metadata[0].name
}

output "keda_release_name" {
  description = "Nombre del release Helm de KEDA."
  value       = helm_release.keda.name
}

output "keda_release_status" {
  description = "Estado del release Helm de KEDA."
  value       = helm_release.keda.status
}
