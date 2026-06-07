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
  source = "../../kubernetes/terraform"

  platform       = local.platform
  db_manager_app = local.db_manager_app
}
