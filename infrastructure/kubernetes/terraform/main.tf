module "platform" {
  source = "../../modules/k8s-platform"

  create_storage_class           = try(var.platform.storage.create_class, true)
  storage_class_name             = var.platform.storage.class_name
  storage_provisioner            = var.platform.storage.provisioner
  storage_parameters             = try(var.platform.storage.parameters, {})
  storage_reclaim_policy         = try(var.platform.storage.reclaim_policy, "Delete")
  storage_allow_volume_expansion = try(var.platform.storage.allow_volume_expansion, true)
  storage_volume_binding_mode    = try(var.platform.storage.volume_binding_mode, "WaitForFirstConsumer")
  storage_is_default_class       = try(var.platform.storage.is_default_class, false)

  ingress_namespace                  = try(var.platform.ingress.namespace, "ingress-nginx")
  ingress_release_name               = try(var.platform.ingress.release_name, "ingress-nginx")
  ingress_repository                 = try(var.platform.ingress.repository, "https://kubernetes.github.io/ingress-nginx")
  ingress_chart                      = try(var.platform.ingress.chart, "ingress-nginx")
  ingress_chart_version              = try(var.platform.ingress.chart_version, "4.12.0")
  ingress_wait                       = try(var.platform.ingress.wait, true)
  ingress_timeout                    = try(var.platform.ingress.timeout, 900)
  ingress_service_type               = try(var.platform.ingress.service_type, "LoadBalancer")
  ingress_service_annotations        = try(var.platform.ingress.service_annotations, {})
  ingress_tcp_configmap_name         = try(var.platform.ingress.tcp_configmap_name, "tcp-services")
  ingress_admission_webhooks_enabled = try(var.platform.ingress.admission_webhooks_enabled, true)

  monitoring_namespace                   = try(var.platform.monitoring.namespace, "monitoring")
  monitoring_release_name                = try(var.platform.monitoring.release_name, "kube-prometheus-stack")
  monitoring_repository                  = try(var.platform.monitoring.repository, "https://prometheus-community.github.io/helm-charts")
  monitoring_chart                       = try(var.platform.monitoring.chart, "kube-prometheus-stack")
  monitoring_chart_version               = try(var.platform.monitoring.chart_version, "69.3.2")
  monitoring_wait                        = try(var.platform.monitoring.wait, true)
  monitoring_timeout                     = try(var.platform.monitoring.timeout, 600)
  monitoring_alertmanager_enabled        = try(var.platform.monitoring.alertmanager_enabled, false)
  monitoring_prometheus_retention        = try(var.platform.monitoring.prometheus_retention, "7d")
  monitoring_prometheus_storage_size     = try(var.platform.monitoring.prometheus_storage_size, "5Gi")
  monitoring_grafana_admin_password      = try(var.platform.monitoring.grafana_admin_password, "admin")
  monitoring_grafana_persistence_enabled = try(var.platform.monitoring.grafana_persistence_enabled, false)
  monitoring_grafana_service_type        = try(var.platform.monitoring.grafana_service_type, "ClusterIP")

  keda_namespace     = try(var.platform.keda.namespace, "keda")
  keda_release_name  = try(var.platform.keda.release_name, "keda")
  keda_repository    = try(var.platform.keda.repository, "https://kedacore.github.io/charts")
  keda_chart         = try(var.platform.keda.chart, "keda")
  keda_chart_version = try(var.platform.keda.chart_version, "2.16.1")
  keda_wait          = try(var.platform.keda.wait, true)
  keda_timeout       = try(var.platform.keda.timeout, 600)
}

module "db_manager_app" {
  count = try(var.db_manager_app.deploy, false) ? 1 : 0

  source = "../../modules/db-manager-app"

  namespace                  = try(var.db_manager_app.namespace, "db-manager-system")
  release_name               = try(var.db_manager_app.release_name, "db-manager-app")
  backend_image_repository   = var.db_manager_app.backend.image_repository
  backend_image_tag          = try(var.db_manager_app.backend.image_tag, "latest")
  backend_image_pull_policy  = try(var.db_manager_app.backend.image_pull_policy, "IfNotPresent")
  frontend_image_repository  = var.db_manager_app.frontend.image_repository
  frontend_image_tag         = try(var.db_manager_app.frontend.image_tag, "latest")
  frontend_image_pull_policy = try(var.db_manager_app.frontend.image_pull_policy, "IfNotPresent")
  storage_class_name         = var.platform.storage.class_name
  ingress_enabled            = try(var.db_manager_app.ingress.enabled, true)
  ingress_class_name         = try(var.db_manager_app.ingress.class_name, "nginx")
  ingress_annotations        = try(var.db_manager_app.ingress.annotations, {})
  ingress_host               = try(var.db_manager_app.ingress.host, "")
  ingress_path               = try(var.db_manager_app.ingress.path, "/")
  wait                       = try(var.db_manager_app.wait, true)
  timeout                    = try(var.db_manager_app.timeout, 600)

  depends_on = [module.platform]
}
