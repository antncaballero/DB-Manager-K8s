# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  variables.tf – Variables de entrada para personalizar la infraestructura   ║
# ║                                                                             ║
# ║  Estas variables permiten configurar el despliegue sin tocar el código.     ║
# ║  Se pueden establecer mediante:                                             ║
# ║    - Un archivo terraform.tfvars                                            ║
# ║    - Variables de entorno: TF_VAR_nombre_variable                           ║
# ║    - Flag -var en la línea de comandos                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# GENERALES
# ─────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Nombre del proyecto. Se usa como prefijo en todos los recursos de AWS para identificarlos fácilmente."
  type        = string
  default     = "tfg-db-manager"
}

variable "aws_region" {
  description = "Región de AWS donde se desplegará toda la infraestructura (VPC, EKS, etc.)."
  type        = string
  default     = "us-east-1" # AWS Academy solo permite us-east-1 y us-west-2
}

variable "environment" {
  description = "Nombre del entorno (dev, staging, prod). Se añade a los tags de los recursos."
  type        = string
  default     = "dev"
}

# ─────────────────────────────────────────────────────────────────────────────
# NETWORKING (VPC)
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = <<-EOT
    Rango CIDR para la VPC.
    Define cuántas IPs privadas tendrá disponible toda tu red en AWS.
    10.0.0.0/16 = 65.536 IPs, suficiente de sobra para el proyecto.
  EOT
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = <<-EOT
    Número de zonas de disponibilidad a usar.
    EKS requiere MÍNIMO 2 AZs para alta disponibilidad.
    Usamos 2 para mantener costes bajos.
  EOT
  type        = number
  default     = 2
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS (Cluster de Kubernetes gestionado)
# ─────────────────────────────────────────────────────────────────────────────

variable "eks_cluster_version" {
  description = "Versión de Kubernetes para el cluster EKS. Debe ser una versión soportada por AWS."
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = <<-EOT
    Tipos de instancia EC2 para los nodos worker del cluster.
    t3.small = 2 vCPUs, 2 GB RAM → suficiente para un proyecto académico con pocas DBs.
    Si necesitas más memoria, sube a t3.medium (2 vCPU, 4 GB, ~el doble de coste).
  EOT
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired" {
  description = "Número deseado de nodos worker. 2 para tener holgura (los pods de sistema consumen ~600 MB RAM/nodo)."
  type        = number
  default     = 2
}

variable "eks_node_min" {
  description = "Mínimo de nodos worker (el autoscaler no bajará de aquí)."
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Máximo de nodos worker (el autoscaler no subirá de aquí). 3 para limitar costes."
  type        = number
  default     = 3
}

variable "eks_node_disk_size" {
  description = "Tamaño del disco (GB) de cada nodo worker. 20 GB es el mínimo requerido por la AMI AL2023."
  type        = number
  default     = 20
}

# ─────────────────────────────────────────────────────────────────────────────
# PUERTOS TCP PARA BASES DE DATOS
# ─────────────────────────────────────────────────────────────────────────────

variable "mysql_port_range_start" {
  description = "Primer puerto del rango TCP expuesto para MySQL (debe coincidir con models.py)."
  type        = number
  default     = 3306
}

variable "mysql_port_range_end" {
  description = "Último puerto del rango TCP expuesto para MySQL."
  type        = number
  default     = 3330
}

variable "mongo_port_range_start" {
  description = "Primer puerto del rango TCP expuesto para MongoDB."
  type        = number
  default     = 27017
}

variable "mongo_port_range_end" {
  description = "Último puerto del rango TCP expuesto para MongoDB."
  type        = number
  default     = 27040
}
