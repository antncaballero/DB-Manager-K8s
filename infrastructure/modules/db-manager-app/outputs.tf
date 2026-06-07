output "namespace" {
  description = "Namespace donde se despliega la aplicación."
  value       = var.namespace
}

output "release_name" {
  description = "Nombre del release Helm de la aplicación."
  value       = helm_release.app.name
}

output "release_status" {
  description = "Estado del release Helm de la aplicación."
  value       = try(helm_release.app.status, "pending")
}
