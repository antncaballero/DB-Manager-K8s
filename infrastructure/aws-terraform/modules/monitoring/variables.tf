# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/monitoring/variables.tf                                            ║
# ║                                                                             ║
# ║  Variables de configuración del stack kube-prometheus-stack.               ║
# ║  Todos los defaults mantienen exactamente el comportamiento actual.         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

variable "namespace" {
  description = "Namespace donde se instala el stack de monitoring."
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "repository" {
  description = "Repositorio Helm del chart kube-prometheus-stack."
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "chart" {
  description = "Nombre del chart Helm a instalar."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "Versión del chart Helm kube-prometheus-stack."
  type        = string
  default     = "69.3.2"
}

variable "wait" {
  description = "Si Terraform debe esperar a que el release esté listo."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout en segundos para la instalación del release Helm."
  type        = number
  default     = 600
}

variable "alertmanager_enabled" {
  description = "Habilita o deshabilita AlertManager."
  type        = bool
  default     = false
}

variable "prometheus_retention" {
  description = "Retención de métricas de Prometheus."
  type        = string
  default     = "7d"
}

variable "prometheus_storage_class_name" {
  description = "StorageClass para el volumen persistente de Prometheus."
  type        = string
  default     = "gp3"
}

variable "prometheus_storage_size" {
  description = "Tamaño del volumen persistente de Prometheus."
  type        = string
  default     = "5Gi"
}

variable "grafana_admin_password" {
  description = "Contraseña del usuario admin de Grafana."
  type        = string
  default     = "admin"
}

variable "grafana_persistence_enabled" {
  description = "Activa persistencia de datos para Grafana."
  type        = bool
  default     = false
}

variable "grafana_service_type" {
  description = "Tipo de Service de Grafana."
  type        = string
  default     = "ClusterIP"
}
