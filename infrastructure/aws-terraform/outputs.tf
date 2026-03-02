# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  outputs.tf – Valores de salida tras aplicar la infraestructura             ║
# ║                                                                             ║
# ║  Después de ejecutar `terraform apply`, estos valores se muestran en        ║
# ║  pantalla. Necesaria para:                           ║
# ║    - Configurar kubectl para hablar con el cluster                          ║
# ║    - Saber dónde se conectarán los alumnos                                  ║
# ║    - Lanzar la app con docker-compose                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

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
  description = "Nombre del StorageClass para los PVC (gp3)."
  value       = module.storage.storage_class_name
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
