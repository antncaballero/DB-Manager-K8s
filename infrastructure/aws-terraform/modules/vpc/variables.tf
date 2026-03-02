# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/vpc/variables.tf – Variables de entrada del módulo VPC             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

variable "project_name" {
  description = "Prefijo para nombrar los recursos de red."
  type        = string
}

variable "vpc_cidr" {
  description = "Rango CIDR de la VPC."
  type        = string
}

variable "availability_zones_count" {
  description = "Número de AZs a utilizar."
  type        = number
}
