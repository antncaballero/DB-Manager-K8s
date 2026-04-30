variable "namespace" {
  description = "Namespace donde se instala KEDA."
  type        = string
  default     = "keda"
}

variable "release_name" {
  description = "Nombre del release Helm de KEDA."
  type        = string
  default     = "keda"
}

variable "repository" {
  description = "Repositorio Helm del chart de KEDA."
  type        = string
  default     = "https://kedacore.github.io/charts"
}

variable "chart" {
  description = "Nombre del chart Helm de KEDA."
  type        = string
  default     = "keda"
}

variable "chart_version" {
  description = "Versión del chart Helm de KEDA."
  type        = string
  default     = "2.16.1"
}

variable "wait" {
  description = "Si Terraform debe esperar a que KEDA esté listo."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout en segundos para instalar KEDA."
  type        = number
  default     = 600
}
