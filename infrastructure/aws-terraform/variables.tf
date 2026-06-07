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
  default     = "1.35"
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
# PLATAFORMA KUBERNETES COMÚN
# ─────────────────────────────────────────────────────────────────────────────

variable "storage_class_name" {
  description = "Nombre lógico de la StorageClass usada por la aplicación y monitoring."
  type        = string
  default     = "db-manager-default"
}

variable "storage_provisioner" {
  description = "Provisioner real que implementa la StorageClass lógica en EKS."
  type        = string
  default     = "ebs.csi.aws.com"
}

variable "storage_parameters" {
  description = "Parámetros específicos del provisioner EBS."
  type        = map(string)
  default = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }
}

variable "storage_reclaim_policy" {
  description = "Política de borrado de volúmenes para la StorageClass lógica."
  type        = string
  default     = "Delete"
}

variable "storage_allow_volume_expansion" {
  description = "Si la StorageClass lógica permite expandir volúmenes."
  type        = bool
  default     = true
}

variable "storage_volume_binding_mode" {
  description = "Modo de binding de volúmenes para la StorageClass lógica."
  type        = string
  default     = "WaitForFirstConsumer"
}

variable "storage_is_default_class" {
  description = "Si la StorageClass lógica debe marcarse como default."
  type        = bool
  default     = false
}

variable "ingress_namespace" {
  description = "Namespace donde se instalará ingress-nginx."
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
  description = "Anotaciones específicas de AWS para el Service de ingress-nginx."
  type        = map(string)
  default = {
    "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
  }
}

variable "ingress_tcp_configmap_name" {
  description = "Nombre del ConfigMap tcp-services."
  type        = string
  default     = "tcp-services"
}

variable "ingress_admission_webhooks_enabled" {
  description = "Si se habilitan los admission webhooks de ingress-nginx."
  type        = bool
  default     = false
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

# ─────────────────────────────────────────────────────────────────────────────
# KEDA (HIBERNACIÓN POR ESCALADO A CERO)
# ─────────────────────────────────────────────────────────────────────────────

variable "keda_namespace" {
  description = "Namespace donde se desplegará KEDA."
  type        = string
  default     = "keda"
}

variable "keda_release_name" {
  description = "Nombre del release Helm de KEDA."
  type        = string
  default     = "keda"
}

variable "keda_repository" {
  description = "Repositorio Helm de KEDA."
  type        = string
  default     = "https://kedacore.github.io/charts"
}

variable "keda_chart" {
  description = "Nombre del chart Helm de KEDA."
  type        = string
  default     = "keda"
}

variable "keda_chart_version" {
  description = "Versión del chart Helm de KEDA."
  type        = string
  default     = "2.16.1"
}

variable "keda_wait" {
  description = "Si Terraform debe esperar a que KEDA esté listo."
  type        = bool
  default     = true
}

variable "keda_timeout" {
  description = "Timeout (segundos) para instalar KEDA."
  type        = number
  default     = 900
}

# ─────────────────────────────────────────────────────────────────────────────
# APP DB MANAGER DESPLEGADA EN KUBERNETES
# ─────────────────────────────────────────────────────────────────────────────

variable "deploy_db_manager_app" {
  description = "Si se debe desplegar la app frontend/backend dentro del cluster."
  type        = bool
  default     = false
}

variable "db_manager_app_namespace" {
  description = "Namespace donde se desplegará la aplicación."
  type        = string
  default     = "db-manager-system"
}

variable "db_manager_app_release_name" {
  description = "Nombre del release Helm de la aplicación."
  type        = string
  default     = "db-manager-app"
}

variable "db_manager_backend_image_repository" {
  description = "Repositorio de la imagen del backend para despliegue in-cluster."
  type        = string
  default     = "db-manager-backend"
}

variable "db_manager_backend_image_tag" {
  description = "Tag de la imagen del backend."
  type        = string
  default     = "latest"
}

variable "db_manager_backend_image_pull_policy" {
  description = "Image pull policy del backend."
  type        = string
  default     = "IfNotPresent"
}

variable "db_manager_frontend_image_repository" {
  description = "Repositorio de la imagen del frontend para despliegue in-cluster."
  type        = string
  default     = "db-manager-frontend"
}

variable "db_manager_frontend_image_tag" {
  description = "Tag de la imagen del frontend."
  type        = string
  default     = "latest"
}

variable "db_manager_frontend_image_pull_policy" {
  description = "Image pull policy del frontend."
  type        = string
  default     = "IfNotPresent"
}

variable "db_manager_app_ingress_enabled" {
  description = "Si la app debe exponerse por Ingress."
  type        = bool
  default     = true
}

variable "db_manager_app_ingress_class_name" {
  description = "IngressClass usada por la app."
  type        = string
  default     = "nginx"
}

variable "db_manager_app_ingress_annotations" {
  description = "Anotaciones del Ingress de la app."
  type        = map(string)
  default     = {}
}

variable "db_manager_app_ingress_host" {
  description = "Host opcional del Ingress de la app. Vacío = sin host."
  type        = string
  default     = ""
}

variable "db_manager_app_ingress_path" {
  description = "Path del Ingress de la app."
  type        = string
  default     = "/"
}

variable "db_manager_app_wait" {
  description = "Si Terraform debe esperar a que la app esté lista."
  type        = bool
  default     = true
}

variable "db_manager_app_timeout" {
  description = "Timeout en segundos para instalar la app."
  type        = number
  default     = 600
}
