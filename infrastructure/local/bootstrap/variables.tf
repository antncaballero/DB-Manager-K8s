variable "cluster_name" {
  description = "Nombre del cluster k3d a crear."
  type        = string
  default     = "tfg-cluster"
}

variable "agents" {
  description = "Número de nodos agente del cluster k3d."
  type        = number
  default     = 1
}

variable "http_port" {
  description = "Puerto local para HTTP del ingress del cluster."
  type        = number
  default     = 30080
}

variable "https_port" {
  description = "Puerto local para HTTPS del ingress del cluster."
  type        = number
  default     = 30443
}

variable "mysql_port_range_start" {
  description = "Primer puerto del rango TCP expuesto para MySQL."
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

variable "redis_port_range_start" {
  description = "Primer puerto del rango TCP expuesto para Redis."
  type        = number
  default     = 6379
}

variable "redis_port_range_end" {
  description = "Último puerto del rango TCP expuesto para Redis."
  type        = number
  default     = 6404
}

variable "cassandra_port_range_start" {
  description = "Primer puerto del rango TCP expuesto para Cassandra."
  type        = number
  default     = 9042
}

variable "cassandra_port_range_end" {
  description = "Último puerto del rango TCP expuesto para Cassandra."
  type        = number
  default     = 9067
}

variable "build_app_images" {
  description = "Si Terraform debe construir e importar las imágenes de la app dentro del cluster k3d."
  type        = bool
  default     = true
}

variable "prepare_backend_kubeconfig" {
  description = "Si Terraform debe generar ~/.kube/config-backend para el contenedor backend."
  type        = bool
  default     = true
}

variable "backend_kubeconfig_path" {
  description = "Ruta de la copia de kubeconfig usada por el backend en Docker."
  type        = string
  default     = "~/.kube/config-backend"
}
