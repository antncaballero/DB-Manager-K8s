# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  terraform.tfvars – Valores por defecto para el despliegue                  ║
# ║                                                                             ║
# ║  Personaliza estos valores según tus necesidades.                           ║
# ║  Este archivo se lee automáticamente al hacer `terraform plan/apply`.       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ── Generales ─────────────────────────────────────────────────────────────────
project_name = "tfg-db-manager"
aws_region   = "us-east-1"
environment  = "dev"

# ── Networking ────────────────────────────────────────────────────────────────
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 2

# ── EKS ──────────────────────────────────────────────────────────────────────
eks_cluster_version     = "1.31"
eks_node_instance_types = ["t3.small"] # 2 vCPU, 2 GB RAM – lo mínimo para un cluster EKS funcional
eks_node_desired        = 3  # 3 nodos para tener holgura (sistema consume ~600 MB por nodo)
eks_node_min            = 1
eks_node_max            = 5
eks_node_disk_size      = 20 # Mínimo requerido por la AMI AL2023

# ── Puertos TCP (deben coincidir con models.py del backend) ──────────────────
mysql_port_range_start = 3306
mysql_port_range_end   = 3330
mongo_port_range_start = 27017
mongo_port_range_end   = 27040
