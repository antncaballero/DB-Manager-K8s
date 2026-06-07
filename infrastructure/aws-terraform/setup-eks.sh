#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  setup-eks.sh – Configuración post-Terraform para usar el cluster EKS       ║
# ║                                                                             ║
# ║  Este script se ejecuta DESPUÉS de `terraform apply` para:                  ║
# ║    1. Configurar kubectl para hablar con el cluster EKS                     ║
# ║    2. Verificar la conexión al cluster                                      ║
# ║    3. Verificar que NGINX Ingress está funcionando                          ║
# ║    4. Mostrar la información de conexión (hostname del NLB)                 ║
# ║                                                                             ║
# ║  Prerrequisitos:                                                            ║
# ║    - AWS CLI configurado (aws configure)                                    ║
# ║    - Terraform aplicado con éxito (terraform apply)                         ║
# ║    - kubectl instalado                                                      ║
# ║    - helm instalado                                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

log()   { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }
warn()  { echo "[WARN] $*"; }
error() { echo "[ERROR] $*"; exit 1; }

# ── Directorio del script (para leer outputs de Terraform) ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}"

# ═══════════════════════════════════════════════════════════════════════════════
#  0. Verificar prerrequisitos
# ═══════════════════════════════════════════════════════════════════════════════
log "Verificando prerrequisitos..."

command -v aws    >/dev/null 2>&1 || error "AWS CLI no encontrado. Instálalo: https://aws.amazon.com/cli/"
command -v kubectl >/dev/null 2>&1 || error "kubectl no encontrado. Instálalo: https://kubernetes.io/docs/tasks/tools/"
command -v helm   >/dev/null 2>&1 || error "Helm no encontrado. Instálalo: https://helm.sh/docs/intro/install/"
command -v terraform >/dev/null 2>&1 || error "Terraform no encontrado. Instálalo: https://developer.hashicorp.com/terraform/install"

# Verificar que las credenciales AWS están configuradas
aws sts get-caller-identity >/dev/null 2>&1 || error "Las credenciales de AWS no están configuradas. Ejecuta 'aws configure'."
ok "Prerrequisitos verificados."

# ═══════════════════════════════════════════════════════════════════════════════
#  1. Leer outputs de Terraform
# ═══════════════════════════════════════════════════════════════════════════════
log "Leyendo datos del cluster EKS..."

cd "$TF_DIR"

if [ -z "${CLUSTER_NAME:-}" ]; then
  CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null) || error "No se pudo leer 'cluster_name'. ¿Has ejecutado 'terraform apply'?"
fi

if [ -z "${AWS_REGION:-}" ]; then
  AWS_REGION=$(terraform output -raw aws_region 2>/dev/null) || error "No se pudo leer 'aws_region'."
fi

ok "Cluster: $CLUSTER_NAME | Región: $AWS_REGION"

# ═══════════════════════════════════════════════════════════════════════════════
#  2. Configurar kubectl para EKS
# ═══════════════════════════════════════════════════════════════════════════════
log "Configurando kubectl para el cluster EKS..."

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

ok "kubectl configurado correctamente."

# ═══════════════════════════════════════════════════════════════════════════════
#  3. Verificar conexión al cluster
# ═══════════════════════════════════════════════════════════════════════════════
log "Verificando conexión al cluster..."

NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODES" -gt 0 ]; then
  ok "Conectado al cluster. Nodos activos: $NODES"
  kubectl get nodes
else
  error "No se detectaron nodos en el cluster."
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#  4. Verificar NGINX Ingress Controller
# ═══════════════════════════════════════════════════════════════════════════════
log "Verificando NGINX Ingress Controller..."

# Esperar a que el pod del ingress esté Running
echo -n "Esperando a que los pods del Ingress estén listos"
for i in $(seq 1 60); do
  READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep "Running" | wc -l)
  if [ "$READY" -gt 0 ]; then
    echo ""
    ok "NGINX Ingress Controller está corriendo."
    break
  fi
  echo -n "."
  sleep 5
done

if [ "$READY" -eq 0 ]; then
  warn "El Ingress Controller aún no está listo. Puede tardar unos minutos más."
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  5. Obtener hostname del NLB
# ═══════════════════════════════════════════════════════════════════════════════
log "Obteniendo hostname del NLB (Network Load Balancer)..."

NLB_HOSTNAME=""
for i in $(seq 1 30); do
  NLB_HOSTNAME=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ -n "$NLB_HOSTNAME" ]; then
    break
  fi
  echo -n "."
  sleep 10
done

echo ""

if [ -n "$NLB_HOSTNAME" ]; then
  ok "NLB Hostname: $NLB_HOSTNAME"
else
  warn "El NLB aún no tiene hostname asignado. Puede tardar unos minutos."
  warn "Comprueba más tarde con: kubectl get svc ingress-nginx-controller -n ingress-nginx"
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  6. Verificar StorageClass
# ═══════════════════════════════════════════════════════════════════════════════
log "Verificando StorageClass..."

kubectl get storageclass
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
#  7. Resumen final
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cluster EKS configurado y listo para usar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Cluster:     $CLUSTER_NAME"
echo "  Región:      $AWS_REGION"
if [ -n "$NLB_HOSTNAME" ]; then
  echo "  NLB:         $NLB_HOSTNAME"
fi
echo ""
echo "  Siguiente paso:"
echo "    Ejecuta la aplicación con docker-compose en modo AWS:"
echo ""
echo "    cd ../../app"
echo "    docker compose -f docker-compose.aws.yaml up -d"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
