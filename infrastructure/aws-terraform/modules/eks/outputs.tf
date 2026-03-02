# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/eks/outputs.tf – Valores que expone el módulo EKS                  ║
# ║                                                                             ║
# ║  Estos valores los usan los proveedores de Kubernetes/Helm para             ║
# ║  conectarse al cluster, y el script de post-despliegue.                     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "URL del API server de Kubernetes (endpoint del cluster)."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificado CA del cluster (base64) para verificar la conexión TLS."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_name" {
  description = "Nombre del grupo de nodos."
  value       = aws_eks_node_group.main.node_group_name
}

output "cluster_security_group_id" {
  description = "ID del Security Group del cluster."
  value       = aws_security_group.eks_nodes.id
}
