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
# ║    kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# ║    URL: http://localhost:3000  usuario: admin  contraseña: admin             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "69.3.2" # Versión estable

  wait    = true
  timeout = 600 # 10 min

  # ── AlertManager: deshabilitado (no necesario para un TFG) ────────────────
  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  # ── Prometheus: retención 7 días, persistencia 5 Gi con gp3 ─────────────
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp3"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "5Gi"
  }

  # ── Grafana: sin persistencia, contraseña admin sencilla ─────────────────
  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "false"
  }

  # Grafana como ClusterIP (más seguro, usando kubectl port-forward para acceder)
  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.monitoring]
}
