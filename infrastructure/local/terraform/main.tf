module "platform" {
  source = "../../modules/k8s-platform"

  storage_class_name                = var.storage_class_name
  storage_provisioner               = var.storage_provisioner
  storage_parameters                = var.storage_parameters
  storage_reclaim_policy            = var.storage_reclaim_policy
  storage_allow_volume_expansion    = var.storage_allow_volume_expansion
  storage_volume_binding_mode       = var.storage_volume_binding_mode
  storage_is_default_class          = var.storage_is_default_class

  ingress_namespace                 = var.ingress_namespace
  ingress_release_name              = var.ingress_release_name
  ingress_repository                = var.ingress_repository
  ingress_chart                     = var.ingress_chart
  ingress_chart_version             = var.ingress_chart_version
  ingress_wait                      = var.ingress_wait
  ingress_timeout                   = var.ingress_timeout
  ingress_service_type              = var.ingress_service_type
  ingress_service_annotations       = var.ingress_service_annotations
  ingress_tcp_configmap_name        = var.ingress_tcp_configmap_name
  ingress_admission_webhooks_enabled = var.ingress_admission_webhooks_enabled

  monitoring_namespace              = var.monitoring_namespace
  monitoring_release_name           = var.monitoring_release_name
  monitoring_repository             = var.monitoring_repository
  monitoring_chart                  = var.monitoring_chart
  monitoring_chart_version          = var.monitoring_chart_version
  monitoring_wait                   = var.monitoring_wait
  monitoring_timeout                = var.monitoring_timeout
  monitoring_alertmanager_enabled   = var.monitoring_alertmanager_enabled
  monitoring_prometheus_retention   = var.monitoring_prometheus_retention
  monitoring_prometheus_storage_size = var.monitoring_prometheus_storage_size
  monitoring_grafana_admin_password = var.monitoring_grafana_admin_password
  monitoring_grafana_persistence_enabled = var.monitoring_grafana_persistence_enabled
  monitoring_grafana_service_type   = var.monitoring_grafana_service_type

  keda_namespace                    = var.keda_namespace
  keda_release_name                 = var.keda_release_name
  keda_repository                   = var.keda_repository
  keda_chart                        = var.keda_chart
  keda_chart_version                = var.keda_chart_version
  keda_wait                         = var.keda_wait
  keda_timeout                      = var.keda_timeout
}
