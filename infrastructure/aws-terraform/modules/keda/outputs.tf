output "namespace" {
  description = "Namespace donde está instalado KEDA."
  value       = kubernetes_namespace.keda.metadata[0].name
}

output "release_name" {
  description = "Nombre del release Helm de KEDA."
  value       = helm_release.keda.name
}

output "release_status" {
  description = "Estado del release Helm de KEDA."
  value       = helm_release.keda.status
}
