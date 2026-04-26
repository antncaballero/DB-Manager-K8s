# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  main.tf – Orquestación principal de la infraestructura AWS                 ║
# ║                                                                             ║
# ║  Este archivo conecta todos los módulos en el orden correcto:               ║
# ║    1. VPC (red)          → se crea primero porque todo lo demás vive dentro ║
# ║    2. EKS (cluster K8s)  → necesita la VPC y sus subnets                   ║
# ║    3. Storage (EBS)      → necesita el cluster EKS funcionando             ║
# ║    4. NGINX Ingress      → necesita el cluster EKS funcionando             ║
# ║    5. Monitoring         → Prometheus + Grafana (usa StorageClass gp3)     ║
# ║                                                                             ║
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
  redis_port_range_start = var.redis_port_range_start
  redis_port_range_end   = var.redis_port_range_end
  cassandra_port_range_start = var.cassandra_port_range_start
  cassandra_port_range_end   = var.cassandra_port_range_end
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


# ═══════════════════════════════════════════════════════════════════════════════
#  5. CLUSTER AUTOSCALER – Escalado automático de nodos EKS
# ═══════════════════════════════════════════════════════════════════════════════
module "cluster_autoscaler" {
  source = "./modules/cluster-autoscaler"

  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  namespace          = var.cluster_autoscaler_namespace
  release_name       = var.cluster_autoscaler_release_name
  repository         = var.cluster_autoscaler_repository
  chart              = var.cluster_autoscaler_chart
  chart_version      = var.cluster_autoscaler_chart_version
  kubernetes_version = var.eks_cluster_version
  wait               = var.cluster_autoscaler_wait
  timeout            = var.cluster_autoscaler_timeout

  depends_on = [module.eks]
}


# ═══════════════════════════════════════════════════════════════════════════════
#  6. MONITORING – Prometheus + Grafana
# ═══════════════════════════════════════════════════════════════════════════════
# Instala kube-prometheus-stack en el namespace "monitoring".
# Acceso a Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana 33000:80 -n monitoring
# URL: http://localhost:33000  |  usuario: admin  |  contraseña: admin
module "monitoring" {
  source = "./modules/monitoring"

  namespace                  = var.monitoring_namespace
  release_name               = var.monitoring_release_name
  repository                 = var.monitoring_repository
  chart                      = var.monitoring_chart
  chart_version              = var.monitoring_chart_version
  wait                       = var.monitoring_wait
  timeout                    = var.monitoring_timeout
  alertmanager_enabled       = var.monitoring_alertmanager_enabled
  prometheus_retention       = var.monitoring_prometheus_retention
  prometheus_storage_class_name = var.monitoring_prometheus_storage_class_name
  prometheus_storage_size    = var.monitoring_prometheus_storage_size
  grafana_admin_password     = var.monitoring_grafana_admin_password
  grafana_persistence_enabled = var.monitoring_grafana_persistence_enabled
  grafana_service_type       = var.monitoring_grafana_service_type

  depends_on = [module.storage, module.cluster_autoscaler]
}
