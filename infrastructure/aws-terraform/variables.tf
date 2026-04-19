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
  default     = 5
}

variable "eks_node_disk_size" {
  description = "Tamaño del disco (GB) de cada nodo worker. 20 GB es el mínimo requerido por la AMI AL2023."
  type        = number
  default     = 20
}

# ─────────────────────────────────────────────────────────────────────────────
# CLUSTER AUTOSCALER
# ─────────────────────────────────────────────────────────────────────────────

variable "cluster_autoscaler_namespace" {
  description = "Namespace donde se instalará Cluster Autoscaler."
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_release_name" {
  description = "Nombre del release Helm de Cluster Autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_repository" {
  description = "Repositorio Helm del chart de Cluster Autoscaler."
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
}

variable "cluster_autoscaler_chart" {
  description = "Nombre del chart Helm de Cluster Autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_version" {
  description = "Versión del chart Helm de Cluster Autoscaler."
  type        = string
  default     = "9.46.6"
}

variable "cluster_autoscaler_wait" {
  description = "Si Terraform debe esperar a que Cluster Autoscaler esté listo."
  type        = bool
  default     = true
}

variable "cluster_autoscaler_timeout" {
  description = "Timeout en segundos para instalar Cluster Autoscaler."
  type        = number
  default     = 600
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

# ─────────────────────────────────────────────────────────────────────────────
# MONITORING (Prometheus + Grafana)
# ─────────────────────────────────────────────────────────────────────────────

variable "monitoring_namespace" {
  description = "Namespace donde se desplegará kube-prometheus-stack."
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_repository" {
  description = "Repositorio Helm para kube-prometheus-stack."
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "monitoring_chart" {
  description = "Nombre del chart Helm de monitoring."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Versión del chart Helm de monitoring."
  type        = string
  default     = "69.3.2"
}

variable "monitoring_wait" {
  description = "Si Terraform debe esperar a que el release de monitoring esté listo."
  type        = bool
  default     = true
}

variable "monitoring_timeout" {
  description = "Timeout (segundos) para instalar el stack de monitoring."
  type        = number
  default     = 600
}

variable "monitoring_alertmanager_enabled" {
  description = "Habilita/deshabilita AlertManager."
  type        = bool
  default     = false
}

variable "monitoring_prometheus_retention" {
  description = "Retención de Prometheus."
  type        = string
  default     = "7d"
}

variable "monitoring_prometheus_storage_class_name" {
  description = "StorageClass para el volumen de Prometheus."
  type        = string
  default     = "gp3"
}

variable "monitoring_prometheus_storage_size" {
  description = "Tamaño del volumen persistente de Prometheus."
  type        = string
  default     = "5Gi"
}

variable "monitoring_grafana_admin_password" {
  description = "Contraseña del usuario admin de Grafana."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "monitoring_grafana_persistence_enabled" {
  description = "Activa o no persistencia en Grafana."
  type        = bool
  default     = false
}

variable "monitoring_grafana_service_type" {
  description = "Tipo de Service para Grafana."
  type        = string
  default     = "ClusterIP"
}
