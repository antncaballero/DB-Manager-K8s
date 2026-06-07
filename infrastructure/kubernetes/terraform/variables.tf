variable "platform" {
  description = "Logical Kubernetes platform entities with provider-specific implementations."
  type = object({
    storage = object({
      class_name             = string
      provisioner            = string
      create_class           = optional(bool, true)
      parameters             = optional(map(string), {})
      reclaim_policy         = optional(string, "Delete")
      allow_volume_expansion = optional(bool, true)
      volume_binding_mode    = optional(string, "WaitForFirstConsumer")
      is_default_class       = optional(bool, false)
    })
    ingress = object({
      namespace                  = optional(string, "ingress-nginx")
      release_name               = optional(string, "ingress-nginx")
      repository                 = optional(string, "https://kubernetes.github.io/ingress-nginx")
      chart                      = optional(string, "ingress-nginx")
      chart_version              = optional(string, "4.12.0")
      wait                       = optional(bool, true)
      timeout                    = optional(number, 900)
      service_type               = optional(string, "LoadBalancer")
      service_annotations        = optional(map(string), {})
      tcp_configmap_name         = optional(string, "tcp-services")
      admission_webhooks_enabled = optional(bool, true)
    })
    monitoring = object({
      namespace                   = optional(string, "monitoring")
      release_name                = optional(string, "kube-prometheus-stack")
      repository                  = optional(string, "https://prometheus-community.github.io/helm-charts")
      chart                       = optional(string, "kube-prometheus-stack")
      chart_version               = optional(string, "69.3.2")
      wait                        = optional(bool, true)
      timeout                     = optional(number, 600)
      alertmanager_enabled        = optional(bool, false)
      prometheus_retention        = optional(string, "7d")
      prometheus_storage_size     = optional(string, "5Gi")
      grafana_admin_password      = optional(string, "admin")
      grafana_persistence_enabled = optional(bool, false)
      grafana_service_type        = optional(string, "ClusterIP")
    })
    keda = object({
      namespace     = optional(string, "keda")
      release_name  = optional(string, "keda")
      repository    = optional(string, "https://kedacore.github.io/charts")
      chart         = optional(string, "keda")
      chart_version = optional(string, "2.16.1")
      wait          = optional(bool, true)
      timeout       = optional(number, 600)
    })
  })
}

variable "db_manager_app" {
  description = "Logical DB Manager application entity deployed on top of the platform."
  type = object({
    deploy       = optional(bool, false)
    namespace    = optional(string, "db-manager-system")
    release_name = optional(string, "db-manager-app")
    backend = object({
      image_repository  = string
      image_tag         = optional(string, "latest")
      image_pull_policy = optional(string, "IfNotPresent")
    })
    frontend = object({
      image_repository  = string
      image_tag         = optional(string, "latest")
      image_pull_policy = optional(string, "IfNotPresent")
    })
    ingress = object({
      enabled     = optional(bool, true)
      class_name  = optional(string, "nginx")
      annotations = optional(map(string), {})
      host        = optional(string, "")
      path        = optional(string, "/")
    })
    wait    = optional(bool, true)
    timeout = optional(number, 600)
  })
}
