# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/vpc/outputs.tf – Valores que expone el módulo VPC                  ║
# ║                                                                             ║
# ║  Otros módulos (como EKS) necesitan estos IDs para crear sus recursos       ║
# ║  dentro de esta red.                                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

output "vpc_id" {
  description = "ID de la VPC creada."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Lista de IDs de las subnets públicas (para el Load Balancer)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Lista de IDs de las subnets privadas (para los nodos EKS)."
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "Bloque CIDR de la VPC."
  value       = aws_vpc.main.cidr_block
}
