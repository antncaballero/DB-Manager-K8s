# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  main.tf – Orquestación principal de la infraestructura AWS                 ║
# ║                                                                             ║
# ║  Este archivo conecta todos los módulos en el orden correcto:               ║
# ║    1. VPC (red)          → se crea primero porque todo lo demás vive dentro ║
# ║    2. EKS (cluster K8s)  → necesita la VPC y sus subnets                   ║
# ║    3. Storage (EBS)      → necesita el cluster EKS funcionando             ║
# ║    4. NGINX Ingress      → necesita el cluster EKS funcionando             ║
# ║                                                                             ║
# ║  Es el equivalente de tu setup-minikube.sh pero para AWS, declarativo      ║
# ║  e idempotente (puedes ejecutarlo varias veces sin romper nada).            ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝


# ═══════════════════════════════════════════════════════════════════════════════
#  1. VPC – Red privada virtual
# ═══════════════════════════════════════════════════════════════════════════════
module "vpc" {
  source = "./modules/vpc"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  availability_zones_count = var.availability_zones_count
}


# ═══════════════════════════════════════════════════════════════════════════════
#  2. EKS – Cluster de Kubernetes
# ═══════════════════════════════════════════════════════════════════════════════
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired        = var.eks_node_desired
  node_min            = var.eks_node_min
  node_max            = var.eks_node_max
  node_disk_size      = var.eks_node_disk_size

  mysql_port_range_start = var.mysql_port_range_start
  mysql_port_range_end   = var.mysql_port_range_end
  mongo_port_range_start = var.mongo_port_range_start
  mongo_port_range_end   = var.mongo_port_range_end
}


# ═══════════════════════════════════════════════════════════════════════════════
#  3. STORAGE – StorageClass gp3 para volúmenes persistentes
# ═══════════════════════════════════════════════════════════════════════════════
module "storage" {
  source = "./modules/storage"

  depends_on = [module.eks]
}


# ═══════════════════════════════════════════════════════════════════════════════
#  4. NGINX INGRESS – Punto de entrada para el tráfico TCP
# ═══════════════════════════════════════════════════════════════════════════════
module "nginx_ingress" {
  source = "./modules/nginx-ingress"

  # No necesita variables de puertos – el backend los gestiona dinámicamente

  depends_on = [module.eks]
}
