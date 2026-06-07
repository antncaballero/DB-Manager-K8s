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
#  3. CLUSTER AUTOSCALER – Escalado automático de nodos EKS
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
#  4. PLATAFORMA KUBERNETES – Addons comunes del proyecto
# ═══════════════════════════════════════════════════════════════════════════════
module "platform" {
  source = "../modules/k8s-platform"

  storage_class_name             = var.storage_class_name
  storage_provisioner            = var.storage_provisioner
  storage_parameters             = var.storage_parameters
  storage_reclaim_policy         = var.storage_reclaim_policy
  storage_allow_volume_expansion = var.storage_allow_volume_expansion
  storage_volume_binding_mode    = var.storage_volume_binding_mode
  storage_is_default_class       = var.storage_is_default_class

  ingress_namespace                  = var.ingress_namespace
  ingress_release_name               = var.ingress_release_name
  ingress_repository                 = var.ingress_repository
  ingress_chart                      = var.ingress_chart
  ingress_chart_version              = var.ingress_chart_version
  ingress_wait                       = var.ingress_wait
  ingress_timeout                    = var.ingress_timeout
  ingress_service_type               = var.ingress_service_type
  ingress_service_annotations        = var.ingress_service_annotations
  ingress_tcp_configmap_name         = var.ingress_tcp_configmap_name
  ingress_admission_webhooks_enabled = var.ingress_admission_webhooks_enabled

  monitoring_namespace                   = var.monitoring_namespace
  monitoring_release_name                = var.monitoring_release_name
  monitoring_repository                  = var.monitoring_repository
  monitoring_chart                       = var.monitoring_chart
  monitoring_chart_version               = var.monitoring_chart_version
  monitoring_wait                        = var.monitoring_wait
  monitoring_timeout                     = var.monitoring_timeout
  monitoring_alertmanager_enabled        = var.monitoring_alertmanager_enabled
  monitoring_prometheus_retention        = var.monitoring_prometheus_retention
  monitoring_prometheus_storage_size     = var.monitoring_prometheus_storage_size
  monitoring_grafana_admin_password      = var.monitoring_grafana_admin_password
  monitoring_grafana_persistence_enabled = var.monitoring_grafana_persistence_enabled
  monitoring_grafana_service_type        = var.monitoring_grafana_service_type

  keda_namespace     = var.keda_namespace
  keda_release_name  = var.keda_release_name
  keda_repository    = var.keda_repository
  keda_chart         = var.keda_chart
  keda_chart_version = var.keda_chart_version
  keda_wait          = var.keda_wait
  keda_timeout       = var.keda_timeout

  depends_on = [module.eks, module.cluster_autoscaler]
}

module "db_manager_app" {
  count = var.deploy_db_manager_app ? 1 : 0

  source = "../modules/db-manager-app"

  namespace                  = var.db_manager_app_namespace
  release_name               = var.db_manager_app_release_name
  backend_image_repository   = var.db_manager_backend_image_repository
  backend_image_tag          = var.db_manager_backend_image_tag
  backend_image_pull_policy  = var.db_manager_backend_image_pull_policy
  frontend_image_repository  = var.db_manager_frontend_image_repository
  frontend_image_tag         = var.db_manager_frontend_image_tag
  frontend_image_pull_policy = var.db_manager_frontend_image_pull_policy
  storage_class_name         = var.storage_class_name
  ingress_enabled            = var.db_manager_app_ingress_enabled
  ingress_class_name         = var.db_manager_app_ingress_class_name
  ingress_annotations        = var.db_manager_app_ingress_annotations
  ingress_host               = var.db_manager_app_ingress_host
  ingress_path               = var.db_manager_app_ingress_path
  wait                       = var.db_manager_app_wait
  timeout                    = var.db_manager_app_timeout

  depends_on = [module.platform]
}
