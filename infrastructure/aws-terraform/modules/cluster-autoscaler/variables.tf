variable "cluster_name" {
  description = "Nombre del cluster EKS donde se instalará Cluster Autoscaler."
  type        = string
}

variable "aws_region" {
  description = "Región de AWS del cluster EKS."
  type        = string
}

variable "namespace" {
  description = "Namespace donde se instala Cluster Autoscaler."
  type        = string
  default     = "kube-system"
}

variable "release_name" {
  description = "Nombre del release Helm de Cluster Autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

variable "repository" {
  description = "Repositorio Helm del chart de Cluster Autoscaler."
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
}

variable "chart" {
  description = "Nombre del chart Helm de Cluster Autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

variable "chart_version" {
  description = "Versión del chart Helm de Cluster Autoscaler."
  type        = string
  default     = "9.46.6"
}

variable "kubernetes_version" {
  description = "Versión menor de Kubernetes (ej: 1.35) para fijar la imagen compatible de Cluster Autoscaler."
  type        = string
  default     = "1.35"
}

variable "wait" {
  description = "Si Terraform debe esperar a que el release esté listo."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout en segundos para instalar Cluster Autoscaler."
  type        = number
  default     = 600
}
