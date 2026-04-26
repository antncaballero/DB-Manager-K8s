# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/nginx-ingress/main.tf – NGINX Ingress Controller en EKS             ║
# ║                                                                              ║
# ║  Instala el mismo NGINX Ingress Controller que se usa en k3d,                ║
# ║    - En AWS:     Service tipo LoadBalancer → AWS crea un NLB automático      ║
# ║                                                                              ║
# ║  El NLB (Network Load Balancer) es el punto de entrada desde internet.       ║
# ║  Los alumnos se conectarán a la IP/DNS del NLB con su puerto asignado        ║
# ║  y el tráfico fluye:                                                         ║
# ║    Internet → NLB → NGINX Ingress → Service → Pod MySQL/MongoDB              ║
# ║                                                                              ║
# ║  También crea el ConfigMap tcp-services que el backend actualiza             ║
# ║  dinámicamente (igual que en local).                                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── ConfigMap tcp-services (inicialmente vacío) ──────────────────────────────
# El backend lo rellena dinámicamente al hacer deploy/destroy.
# Se crea aquí para que exista ANTES de que NGINX intente leerlo.
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_config_map" "tcp_services" {
  metadata {
    name      = "tcp-services"
    namespace = "ingress-nginx"
  }

  # Sin data inicial – el backend lo rellena
  data = {}

  depends_on = [kubernetes_namespace.ingress_nginx]
}

# ── Instalación de NGINX Ingress Controller via Helm ─────────────────────────
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.12.0" # Versión estable del chart

  # Esperar a que los pods estén ready
  wait    = true
  timeout = 900 # 15 min – el NLB de AWS puede tardar en provisionarse

  # ── Configuración del Service como NLB de AWS ──────────────────────
  # En AWS, cuando creas un Service tipo LoadBalancer, AWS provisiona
  # automáticamente un NLB. Estas anotaciones controlan el comportamiento.

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Usar NLB (Network Load Balancer) en vez de CLB (Classic Load Balancer)
  # NLB es más eficiente para tráfico TCP (nuestro caso: puertos de DB)
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  # Esquema "internet-facing" para que sea accesible desde internet
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  # Le decimos al controller de NGINX qué ConfigMap contiene las reglas TCP.
  # El ConfigMap lo crea Terraform (vacío) y el backend lo rellena
  # dinámicamente al desplegar bases de datos (k8s_manager.py).
  set {
    name  = "controller.extraArgs.tcp-services-configmap"
    value = "ingress-nginx/tcp-services"
  }

  # ── Admission Webhooks deshabilitados ──────────────────────────────
  # En EKS, el API server puede no alcanzar el webhook en la red de pods
  # (especialmente con nodos en subnets privadas), bloqueando el despliegue.
  # No son necesarios para nuestro caso de uso (solo TCP passthrough).
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

  # ── Puertos TCP del Service ────────────────────────────────────────
  # NO se pre-abren puertos TCP con backends placeholder aquí.
  # El backend (k8s_manager.py → _sync_ingress_service_ports) gestiona
  # dinámicamente los puertos del Service al hacer deploy/destroy:
  #   1. Actualiza el ConfigMap tcp-services → NGINX recarga config
  #   2. Parchea el Service para añadir/quitar puertos → NLB actualiza listeners

  depends_on = [
    kubernetes_config_map.tcp_services,
  ]
}
