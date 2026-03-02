# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  providers.tf – Configuración de los proveedores de Terraform               ║
# ║                                                                             ║
# ║  Aquí se configura CÓMO se conecta Terraform a cada servicio:               ║
# ║    - AWS: región y tags por defecto                                         ║
# ║    - Kubernetes: se conecta al cluster EKS recién creado                    ║
# ║    - Helm: usa la misma conexión para instalar charts                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ── Proveedor AWS ─────────────────────────────────────────────────────────────
# Terraform usará las credenciales de ~/.aws/credentials o variables de entorno
# (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) que ya tengas configuradas.
provider "aws" {
  region = var.aws_region

  # Tags que se aplican automáticamente a TODOS los recursos creados.
  # Así es fácil identificar qué creó Terraform y para qué proyecto.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ── Proveedor Kubernetes ──────────────────────────────────────────────────────
# Se configura para hablar con el cluster EKS que creamos en eks.tf.
# Usa el endpoint del cluster y un token temporal obtenido vía AWS CLI.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ── Proveedor Helm ────────────────────────────────────────────────────────────
# Misma lógica: se conecta al EKS para poder instalar charts.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
