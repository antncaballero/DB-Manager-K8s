resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "keda" {
  name       = var.release_name
  repository = var.repository
  chart      = var.chart
  namespace  = var.namespace
  version    = var.chart_version

  wait    = var.wait
  timeout = var.timeout

  depends_on = [kubernetes_namespace.keda]
}
