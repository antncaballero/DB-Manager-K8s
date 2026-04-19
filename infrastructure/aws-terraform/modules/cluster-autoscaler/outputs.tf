output "namespace" {
  description = "Namespace donde está instalado Cluster Autoscaler."
  value       = var.namespace
}

output "release_name" {
  description = "Nombre del release Helm de Cluster Autoscaler."
  value       = helm_release.cluster_autoscaler.name
}

output "release_status" {
  description = "Estado del release Helm de Cluster Autoscaler."
  value       = helm_release.cluster_autoscaler.status
}
