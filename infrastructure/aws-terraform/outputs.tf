# ╔═════════════════════════════════════════════════════════════════════════════╗
# ║  outputs.tf – Valores de salida tras aplicar la infraestructura             ║
# ║                                                                             ║
# ║  Después de ejecutar `terraform apply`, estos valores se muestran en        ║
# ║  pantalla. Necesaria para:                                                  ║
# ║    - Configurar kubectl para hablar con el cluster                          ║
# ║    - Saber dónde se conectarán los alumnos                                  ║
# ║    - Lanzar la app con docker-compose                                       ║
# ╚═════════════════════════════════════════════════════════════════════════════╝

output "cluster_name" {
  description = "Nombre del cluster EKS. Úsalo con: aws eks update-kubeconfig --name <este-valor>"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "URL del API server del cluster. El backend se conecta aquí."
  value       = module.eks.cluster_endpoint
}

output "aws_region" {
  description = "Región de AWS donde está desplegado todo."
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID de la VPC creada."
  value       = module.vpc.vpc_id
}

output "storage_class" {
  description = "Nombre lógico del StorageClass para los PVC."
  value       = module.platform.storage_class_name
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl en tu máquina local."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "nlb_dns_note" {
  description = "Nota sobre el NLB DNS."
  value       = <<-EOT
    El hostname del NLB (Network Load Balancer) se obtiene con:
      kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

    Los alumnos se conectarán usando:
      <hostname_del_nlb>:<puerto_asignado>
  EOT
}

output "monitoring_namespace" {
  description = "Namespace donde está desplegado el stack de monitoring."
  value       = module.platform.monitoring_namespace
}

output "monitoring_release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  value       = module.platform.monitoring_release_name
}

output "monitoring_release_status" {
  description = "Estado del release Helm de monitoring."
  value       = module.platform.monitoring_release_status
}

output "grafana_access" {
  description = "Comando de acceso a Grafana por port-forward y credenciales de login."
  value       = "kubectl port-forward svc/${var.monitoring_release_name}-grafana 33000:80 -n ${var.monitoring_namespace}  |  URL: http://localhost:33000  |  usuario: admin  |  contraseña: (valor de TF_VAR_monitoring_grafana_admin_password)"
}

output "cluster_autoscaler_namespace" {
  description = "Namespace donde está desplegado Cluster Autoscaler."
  value       = module.cluster_autoscaler.namespace
}

output "cluster_autoscaler_release_name" {
  description = "Nombre del release Helm de Cluster Autoscaler."
  value       = module.cluster_autoscaler.release_name
}

output "cluster_autoscaler_release_status" {
  description = "Estado del release Helm de Cluster Autoscaler."
  value       = module.cluster_autoscaler.release_status
}

output "keda_namespace" {
  description = "Namespace donde está desplegado KEDA."
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

output "db_manager_app_namespace" {
  description = "Namespace donde está desplegada la app DB Manager."
  value       = try(module.db_manager_app[0].namespace, "")
}

output "db_manager_app_release_name" {
  description = "Nombre del release Helm de la app DB Manager."
  value       = try(module.db_manager_app[0].release_name, "")
}

output "db_manager_app_release_status" {
  description = "Estado del release Helm de la app DB Manager."
  value       = try(module.db_manager_app[0].release_status, "")
}

output "db_manager_app_access" {
  description = "Ruta de acceso esperada a la app DB Manager."
  value       = var.deploy_db_manager_app ? "Accede usando el DNS/IP externo de ingress-nginx en path /" : "Despliegue in-cluster deshabilitado (deploy_db_manager_app=false)."
}
