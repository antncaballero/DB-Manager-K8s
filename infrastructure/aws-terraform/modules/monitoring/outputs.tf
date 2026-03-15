# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/monitoring/outputs.tf                                              ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

output "namespace" {
  description = "Namespace donde se despliega el stack de monitoring."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  value       = helm_release.kube_prometheus_stack.name
}

output "release_status" {
  description = "Estado del release Helm de kube-prometheus-stack."
  value       = try(helm_release.kube_prometheus_stack.status, "pending")
}
