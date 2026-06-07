variable "namespace" {
  description = "Namespace donde desplegar la aplicación DB Manager."
  type        = string
  default     = "db-manager-system"
}

variable "release_name" {
  description = "Nombre del release Helm de la aplicación."
  type        = string
  default     = "db-manager-app"
}

variable "create_namespace" {
  description = "Si Terraform debe crear el namespace de la aplicación."
  type        = bool
  default     = true
}

variable "backend_image_repository" {
  description = "Repositorio de la imagen del backend."
  type        = string
}

variable "backend_image_tag" {
  description = "Tag de la imagen del backend."
  type        = string
  default     = "latest"
}

variable "backend_image_pull_policy" {
  description = "Image pull policy del backend."
  type        = string
  default     = "IfNotPresent"
}

variable "frontend_image_repository" {
  description = "Repositorio de la imagen del frontend."
  type        = string
}

variable "frontend_image_tag" {
  description = "Tag de la imagen del frontend."
  type        = string
  default     = "latest"
}

variable "frontend_image_pull_policy" {
  description = "Image pull policy del frontend."
  type        = string
  default     = "IfNotPresent"
}

variable "storage_class_name" {
  description = "Nombre lógico de la StorageClass usada por el backend."
  type        = string
}

variable "ingress_enabled" {
  description = "Si la app debe exponerse mediante Ingress."
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "IngressClass usada para exponer el frontend."
  type        = string
  default     = "nginx"
}

variable "ingress_annotations" {
  description = "Anotaciones del Ingress del frontend."
  type        = map(string)
  default     = {}
}

variable "ingress_host" {
  description = "Host opcional del Ingress del frontend. Vacío = sin host."
  type        = string
  default     = ""
}

variable "ingress_path" {
  description = "Path del Ingress del frontend."
  type        = string
  default     = "/"
}

variable "wait" {
  description = "Si Terraform debe esperar a que el release de la app esté listo."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout en segundos para instalar la aplicación."
  type        = number
  default     = 600
}
