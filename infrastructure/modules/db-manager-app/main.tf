resource "kubernetes_namespace" "app" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "app" {
  name      = var.release_name
  namespace = var.namespace
  chart     = "${path.module}/../../../charts/db-manager-app"

  wait    = var.wait
  timeout = var.timeout

  values = [
    yamlencode({
      backend = {
        image = {
          repository = var.backend_image_repository
          tag        = var.backend_image_tag
          pullPolicy = var.backend_image_pull_policy
        }
        storageClassName = var.storage_class_name
      }
      frontend = {
        image = {
          repository = var.frontend_image_repository
          tag        = var.frontend_image_tag
          pullPolicy = var.frontend_image_pull_policy
        }
        ingress = {
          enabled     = var.ingress_enabled
          className   = var.ingress_class_name
          annotations = var.ingress_annotations
          host        = var.ingress_host
          path        = var.ingress_path
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.app]
}
