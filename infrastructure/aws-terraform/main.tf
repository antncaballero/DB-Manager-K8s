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
  lab_mode            = var.aws_lab_mode
  cluster_role_name   = var.eks_cluster_role_name
  node_role_name      = var.eks_node_role_name
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired        = var.eks_node_desired
  node_min            = var.eks_node_min
  node_max            = var.eks_node_max
  node_disk_size      = var.eks_node_disk_size

  mysql_port_range_start     = var.mysql_port_range_start
  mysql_port_range_end       = var.mysql_port_range_end
  mongo_port_range_start     = var.mongo_port_range_start
  mongo_port_range_end       = var.mongo_port_range_end
  redis_port_range_start     = var.redis_port_range_start
  redis_port_range_end       = var.redis_port_range_end
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
locals {
  platform = {
    storage = {
      class_name             = var.storage_class_name
      provisioner            = var.storage_provisioner
      parameters             = var.storage_parameters
      reclaim_policy         = var.storage_reclaim_policy
      allow_volume_expansion = var.storage_allow_volume_expansion
      volume_binding_mode    = var.storage_volume_binding_mode
      is_default_class       = var.storage_is_default_class
    }
    ingress = {
      namespace                  = var.ingress_namespace
      release_name               = var.ingress_release_name
      repository                 = var.ingress_repository
      chart                      = var.ingress_chart
      chart_version              = var.ingress_chart_version
      wait                       = var.ingress_wait
      timeout                    = var.ingress_timeout
      service_type               = var.ingress_service_type
      service_annotations        = var.ingress_service_annotations
      tcp_configmap_name         = var.ingress_tcp_configmap_name
      admission_webhooks_enabled = var.ingress_admission_webhooks_enabled
    }
    monitoring = {
      namespace                   = var.monitoring_namespace
      release_name                = var.monitoring_release_name
      repository                  = var.monitoring_repository
      chart                       = var.monitoring_chart
      chart_version               = var.monitoring_chart_version
      wait                        = var.monitoring_wait
      timeout                     = var.monitoring_timeout
      alertmanager_enabled        = var.monitoring_alertmanager_enabled
      prometheus_retention        = var.monitoring_prometheus_retention
      prometheus_storage_size     = var.monitoring_prometheus_storage_size
      grafana_admin_password      = var.monitoring_grafana_admin_password
      grafana_persistence_enabled = var.monitoring_grafana_persistence_enabled
      grafana_service_type        = var.monitoring_grafana_service_type
    }
    keda = {
      namespace     = var.keda_namespace
      release_name  = var.keda_release_name
      repository    = var.keda_repository
      chart         = var.keda_chart
      chart_version = var.keda_chart_version
      wait          = var.keda_wait
      timeout       = var.keda_timeout
    }
  }

  db_manager_app = {
    deploy       = var.deploy_db_manager_app
    namespace    = var.db_manager_app_namespace
    release_name = var.db_manager_app_release_name
    backend = {
      image_repository  = var.db_manager_backend_image_repository
      image_tag         = var.db_manager_backend_image_tag
      image_pull_policy = var.db_manager_backend_image_pull_policy
    }
    frontend = {
      image_repository  = var.db_manager_frontend_image_repository
      image_tag         = var.db_manager_frontend_image_tag
      image_pull_policy = var.db_manager_frontend_image_pull_policy
    }
    ingress = {
      enabled     = var.db_manager_app_ingress_enabled
      class_name  = var.db_manager_app_ingress_class_name
      annotations = var.db_manager_app_ingress_annotations
      host        = var.db_manager_app_ingress_host
      path        = var.db_manager_app_ingress_path
    }
    wait    = var.db_manager_app_wait
    timeout = var.db_manager_app_timeout
  }
}

module "kubernetes_stack" {
  source = "../kubernetes/terraform"

  platform       = local.platform
  db_manager_app = local.db_manager_app

  depends_on = [module.eks, module.cluster_autoscaler]
}

resource "terraform_data" "setup_eks" {
  count = var.run_setup_eks_after_apply ? 1 : 0

  triggers_replace = [
    module.eks.cluster_name,
    var.aws_region,
  ]

  provisioner "local-exec" {
    command = "${path.module}/setup-eks.sh"
    environment = {
      CLUSTER_NAME = module.eks.cluster_name
      AWS_REGION   = var.aws_region
    }
  }

  depends_on = [module.kubernetes_stack]
}
