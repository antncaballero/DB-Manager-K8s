# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  versions.tf – Versiones requeridas de Terraform y proveedores              ║
# ║                                                                             ║
# ║  Define qué versión mínima de Terraform necesitas y qué proveedores         ║
# ║  (plugins) se van a usar: AWS para la infraestructura cloud,                ║
# ║  Kubernetes y Helm para interactuar con el cluster EKS una vez creado.      ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Proveedor de AWS: crea VPC, subnets, EKS, IAM, security groups, etc.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Proveedor de Kubernetes: permite crear recursos K8s (ConfigMaps, etc.)
    # directamente desde Terraform después de crear el cluster EKS.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }

    # Proveedor de Helm: permite instalar charts de Helm (como NGINX Ingress)
    # directamente desde Terraform sobre el cluster EKS recién creado.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}
