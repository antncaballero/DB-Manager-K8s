output "storage_class_name" {
  description = "Nombre lógico de la StorageClass usada por la plataforma."
  value       = module.platform.storage_class_name
}

output "ingress_namespace" {
  description = "Namespace donde está desplegado ingress-nginx."
  value       = module.platform.ingress_namespace
}

output "ingress_release_name" {
  description = "Nombre del release Helm de ingress-nginx."
  value       = module.platform.ingress_release_name
}

output "ingress_release_status" {
  description = "Estado del release Helm de ingress-nginx."
  value       = module.platform.ingress_release_status
}

output "monitoring_namespace" {
  description = "Namespace donde se despliega el stack de monitoring."
  value       = module.platform.monitoring_namespace
}

output "monitoring_release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  value       = module.platform.monitoring_release_name
}

output "monitoring_release_status" {
  description = "Estado del release Helm de kube-prometheus-stack."
  value       = module.platform.monitoring_release_status
}

output "keda_namespace" {
  description = "Namespace donde está instalado KEDA."
  value       = module.platform.keda_namespace
}

output "keda_release_name" {
  description = "Nombre del release Helm de KEDA."
  value       = module.platform.keda_release_name
}

output "keda_release_status" {
  description = "Estado del release Helm de KEDA."
  value       = module.platform.keda_release_status
}

output "db_manager_app_enabled" {
  description = "Si la aplicación DB Manager está habilitada en este despliegue."
  value       = try(var.db_manager_app.deploy, false)
}

output "db_manager_app_namespace" {
  description = "Namespace donde se despliega la aplicación."
  value       = try(module.db_manager_app[0].namespace, "")
}

output "db_manager_app_release_name" {
  description = "Nombre del release Helm de la aplicación."
  value       = try(module.db_manager_app[0].release_name, "")
}

output "db_manager_app_release_status" {
  description = "Estado del release Helm de la aplicación."
  value       = try(module.db_manager_app[0].release_status, "")
}
