# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/nginx-ingress/variables.tf                                         ║
# ║                                                                             ║
# ║  Este módulo no necesita variables de puertos TCP porque el backend          ║
# ║  (k8s_manager.py) gestiona dinámicamente los puertos del ConfigMap           ║
# ║  tcp-services y del Service ingress-nginx-controller.                        ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
