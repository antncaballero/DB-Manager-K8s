# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/monitoring/main.tf – Prometheus + Grafana en EKS                   ║
# ║                                                                              ║
# ║  Instala el stack de monitorización kube-prometheus-stack, que incluye:      ║
# ║    - Prometheus   → recolecta métricas del cluster y las bases de datos      ║
# ║    - Grafana      → dashboards visuales (acceso via kubectl port-forward)    ║
# ║    - Node Exporter → métricas de CPU/RAM/disco de cada nodo EC2              ║
# ║    - kube-state-metrics → métricas del estado de los objetos Kubernetes     ║
# ║                                                                              ║
# ║  Configuración mínima para AWS Academy:                                     ║
# ║    - AlertManager deshabilitado (no necesario para un TFG)                  ║
# ║    - Prometheus con persistencia gp3 (5 Gi)                                 ║
# ║    - Grafana sin persistencia (los dashboards se recargan al reiniciar)      ║
# ║    - Grafana expuesto como ClusterIP → acceso via: kubectl port-forward      ║
# ║                                                                              ║
# ║  Acceso a Grafana:                                                           ║
# ║    kubectl port-forward svc/kube-prometheus-stack-grafana 33000:80 -n monitoring
# ║    URL: http://localhost:33000  usuario: admin  contraseña: admin             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = var.repository
  chart      = var.chart
  namespace  = var.namespace
  version    = var.chart_version # Versión estable

  wait    = var.wait
  timeout = var.timeout # 10 min

  # ── AlertManager: deshabilitado (no necesario para un TFG) ────────────────
  set {
    name  = "alertmanager.enabled"
    value = tostring(var.alertmanager_enabled)
  }

  # ── Prometheus: retención 7 días, persistencia 5 Gi con gp3 ─────────────
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.prometheus_storage_class_name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  # ── Grafana: sin persistencia, contraseña admin sencilla ─────────────────
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.persistence.enabled"
    value = tostring(var.grafana_persistence_enabled)
  }

  # Grafana como ClusterIP (más seguro, usando kubectl port-forward para acceder)
  set {
    name  = "grafana.service.type"
    value = var.grafana_service_type
  }

  depends_on = [kubernetes_namespace.monitoring]
}
