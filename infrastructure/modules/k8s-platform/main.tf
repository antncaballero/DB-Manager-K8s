locals {
  storage_class_annotations = var.storage_is_default_class ? {
    "storageclass.kubernetes.io/is-default-class" = "true"
  } : {}
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.ingress_namespace
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.keda_namespace
  }
}

resource "kubernetes_config_map" "tcp_services" {
  metadata {
    name      = var.ingress_tcp_configmap_name
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }

  data = {}
}

resource "kubernetes_storage_class" "logical" {
  count = var.create_storage_class ? 1 : 0

  metadata {
    name        = var.storage_class_name
    annotations = local.storage_class_annotations
  }

  storage_provisioner    = var.storage_provisioner
  reclaim_policy         = var.storage_reclaim_policy
  allow_volume_expansion = var.storage_allow_volume_expansion
  volume_binding_mode    = var.storage_volume_binding_mode
  parameters             = var.storage_parameters
}

resource "helm_release" "ingress_nginx" {
  name       = var.ingress_release_name
  repository = var.ingress_repository
  chart      = var.ingress_chart
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = var.ingress_chart_version

  wait    = var.ingress_wait
  timeout = var.ingress_timeout

  set {
    name  = "controller.service.type"
    value = var.ingress_service_type
  }

  set {
    name  = "controller.extraArgs.tcp-services-configmap"
    value = "${var.ingress_namespace}/${var.ingress_tcp_configmap_name}"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = tostring(var.ingress_admission_webhooks_enabled)
  }

  dynamic "set" {
    for_each = var.ingress_service_annotations
    content {
      name  = "controller.service.annotations.${replace(set.key, ".", "\\.")}"
      value = set.value
    }
  }

  depends_on = [kubernetes_config_map.tcp_services]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.monitoring_release_name
  repository = var.monitoring_repository
  chart      = var.monitoring_chart
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.monitoring_chart_version

  wait    = var.monitoring_wait
  timeout = var.monitoring_timeout

  set {
    name  = "alertmanager.enabled"
    value = tostring(var.monitoring_alertmanager_enabled)
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.monitoring_prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.storage_class_name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.monitoring_prometheus_storage_size
  }

  set {
    name  = "grafana.adminPassword"
    value = var.monitoring_grafana_admin_password
  }

  set {
    name  = "grafana.persistence.enabled"
    value = tostring(var.monitoring_grafana_persistence_enabled)
  }

  set {
    name  = "grafana.service.type"
    value = var.monitoring_grafana_service_type
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_storage_class.logical,
  ]
}

resource "helm_release" "keda" {
  name       = var.keda_release_name
  repository = var.keda_repository
  chart      = var.keda_chart
  namespace  = kubernetes_namespace.keda.metadata[0].name
  version    = var.keda_chart_version

  wait    = var.keda_wait
  timeout = var.keda_timeout

  depends_on = [kubernetes_namespace.keda]
}
