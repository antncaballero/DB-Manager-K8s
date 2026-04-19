resource "helm_release" "cluster_autoscaler" {
  name       = var.release_name
  repository = var.repository
  chart      = var.chart
  namespace  = var.namespace
  version    = var.chart_version

  wait    = var.wait
  timeout = var.timeout

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "image.tag"
    value = "v${var.kubernetes_version}.0"
  }
}
