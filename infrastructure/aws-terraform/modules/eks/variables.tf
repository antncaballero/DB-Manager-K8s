# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/eks/variables.tf – Variables de entrada del módulo EKS             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

variable "project_name" {
  description = "Prefijo para nombrar los recursos."
  type        = string
}

variable "cluster_version" {
  description = "Versión de Kubernetes para EKS."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde crear el cluster."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subnets públicas (para el Load Balancer)."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas (donde irán los nodos worker)."
  type        = list(string)
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 para los nodos."
  type        = list(string)
}

variable "node_desired" {
  description = "Número deseado de nodos."
  type        = number
}

variable "node_min" {
  description = "Mínimo de nodos."
  type        = number
}

variable "node_max" {
  description = "Máximo de nodos."
  type        = number
}

variable "node_disk_size" {
  description = "Tamaño del disco de cada nodo (GB)."
  type        = number
}

variable "mysql_port_range_start" {
  description = "Primer puerto del rango TCP para MySQL."
  type        = number
}

variable "mysql_port_range_end" {
  description = "Último puerto del rango TCP para MySQL."
  type        = number
}

variable "mongo_port_range_start" {
  description = "Primer puerto del rango TCP para MongoDB."
  type        = number
}

variable "mongo_port_range_end" {
  description = "Último puerto del rango TCP para MongoDB."
  type        = number
}

variable "redis_port_range_start" {
  description = "Primer puerto del rango TCP para Redis."
  type        = number
  default     = 6379
}

variable "redis_port_range_end" {
  description = "Último puerto del rango TCP para Redis."
  type        = number
  default     = 6404
}

variable "cassandra_port_range_start" {
  description = "Primer puerto del rango TCP para Cassandra."
  type        = number
  default     = 9042
}

variable "cassandra_port_range_end" {
  description = "Último puerto del rango TCP para Cassandra."
  type        = number
  default     = 9067
}
