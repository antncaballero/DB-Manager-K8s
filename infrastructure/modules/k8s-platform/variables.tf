variable "create_storage_class" {
  description = "Si se debe crear una StorageClass lógica para la plataforma."
  type        = bool
  default     = true
}

variable "storage_class_name" {
  description = "Nombre lógico de la StorageClass usada por la plataforma."
  type        = string
}

variable "storage_provisioner" {
  description = "Provisioner real de la StorageClass para el proveedor actual."
  type        = string
}

variable "storage_parameters" {
  description = "Parámetros específicos del provisioner de almacenamiento."
  type        = map(string)
  default     = {}
}

variable "storage_reclaim_policy" {
  description = "Política de borrado de los volúmenes al eliminar el PVC."
  type        = string
  default     = "Delete"
}

variable "storage_allow_volume_expansion" {
  description = "Si la StorageClass permite expandir volúmenes."
  type        = bool
  default     = true
}

variable "storage_volume_binding_mode" {
  description = "Modo de binding de volúmenes para la StorageClass."
  type        = string
  default     = "WaitForFirstConsumer"
}

variable "storage_is_default_class" {
  description = "Si la StorageClass lógica debe marcarse como default."
  type        = bool
  default     = false
}

variable "ingress_namespace" {
  description = "Namespace donde se instala ingress-nginx."
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_release_name" {
  description = "Nombre del release Helm de ingress-nginx."
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_repository" {
  description = "Repositorio Helm del chart ingress-nginx."
  type        = string
  default     = "https://kubernetes.github.io/ingress-nginx"
}

variable "ingress_chart" {
  description = "Nombre del chart ingress-nginx."
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_chart_version" {
  description = "Versión del chart ingress-nginx."
  type        = string
  default     = "4.12.0"
}

variable "ingress_wait" {
  description = "Si Terraform debe esperar a que ingress-nginx esté listo."
  type        = bool
  default     = true
}

variable "ingress_timeout" {
  description = "Timeout en segundos para instalar ingress-nginx."
  type        = number
  default     = 900
}

variable "ingress_service_type" {
  description = "Tipo de Service del controller de ingress-nginx."
  type        = string
  default     = "LoadBalancer"
}

variable "ingress_service_annotations" {
  description = "Anotaciones específicas del proveedor para el Service del controller."
  type        = map(string)
  default     = {}
}

variable "ingress_tcp_configmap_name" {
  description = "Nombre del ConfigMap que define el enrutado TCP de ingress-nginx."
  type        = string
  default     = "tcp-services"
}

variable "ingress_admission_webhooks_enabled" {
  description = "Si se habilitan los admission webhooks de ingress-nginx."
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace donde se despliega kube-prometheus-stack."
  type        = string
  default     = "monitoring"
}

variable "monitoring_release_name" {
  description = "Nombre del release Helm de kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_repository" {
  description = "Repositorio Helm del chart kube-prometheus-stack."
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "monitoring_chart" {
  description = "Nombre del chart kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  description = "Versión del chart kube-prometheus-stack."
  type        = string
  default     = "69.3.2"
}

variable "monitoring_wait" {
  description = "Si Terraform debe esperar a que monitoring esté listo."
  type        = bool
  default     = true
}

variable "monitoring_timeout" {
  description = "Timeout en segundos para instalar monitoring."
  type        = number
  default     = 600
}

variable "monitoring_alertmanager_enabled" {
  description = "Habilita o deshabilita AlertManager."
  type        = bool
  default     = false
}

variable "monitoring_prometheus_retention" {
  description = "Retención de Prometheus."
  type        = string
  default     = "7d"
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
  description = "Si Grafana debe tener persistencia."
  type        = bool
  default     = false
}

variable "monitoring_grafana_service_type" {
  description = "Tipo de Service para Grafana."
  type        = string
  default     = "ClusterIP"
}

variable "keda_namespace" {
  description = "Namespace donde se instala KEDA."
  type        = string
  default     = "keda"
}

variable "keda_release_name" {
  description = "Nombre del release Helm de KEDA."
  type        = string
  default     = "keda"
}

variable "keda_repository" {
  description = "Repositorio Helm del chart de KEDA."
  type        = string
  default     = "https://kedacore.github.io/charts"
}

variable "keda_chart" {
  description = "Nombre del chart de KEDA."
  type        = string
  default     = "keda"
}

variable "keda_chart_version" {
  description = "Versión del chart de KEDA."
  type        = string
  default     = "2.16.1"
}

variable "keda_wait" {
  description = "Si Terraform debe esperar a que KEDA esté listo."
  type        = bool
  default     = true
}

variable "keda_timeout" {
  description = "Timeout en segundos para instalar KEDA."
  type        = number
  default     = 600
}
