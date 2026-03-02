#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  destroy-eks.sh – Destruir TODA la infraestructura AWS                      ║
# ║                                                                             ║
# ║  ⚠️  CUIDADO: Este script elimina TODOS los recursos creados por Terraform. ║
# ║  Esto incluye: VPC, EKS, nodos EC2, NLB, discos EBS, etc.                  ║
# ║  Úsalo cuando quieras dejar de pagar por la infraestructura.               ║
# ║                                                                             ║
# ║  Pasos:                                                                     ║
# ║    1. Elimina todas las releases de Helm (para liberar PVCs/EBS)            ║
# ║    2. Ejecuta terraform destroy                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  ⚠️  ATENCIÓN: Vas a DESTRUIR toda la infraestructura AWS${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Esto eliminará:"
echo "    - Cluster EKS y todos sus nodos"
echo "    - Todas las bases de datos desplegadas"
echo "    - Todos los volúmenes de datos (EBS)"
echo "    - VPC, subnets, NAT Gateway, NLB"
echo ""
read -p "  ¿Estás seguro? Escribe 'si' para continuar: " confirm
echo ""

if [ "$confirm" != "si" ]; then
  info "Operación cancelada."
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  1. Limpiar releases de Helm (para que los PVC se liberen)
# ═══════════════════════════════════════════════════════════════════════════════
info "Eliminando releases de Helm existentes..."

RELEASES=$(helm list --all-namespaces --short 2>/dev/null || echo "")
if [ -n "$RELEASES" ]; then
  for release in $RELEASES; do
    NS=$(helm list --all-namespaces --filter "$release" -o json 2>/dev/null | \
         python3 -c "import sys,json;r=json.load(sys.stdin);print(r[0]['namespace'] if r else 'default')" 2>/dev/null || echo "default")
    info "Eliminando release '$release' del namespace '$NS'..."
    helm uninstall "$release" --namespace "$NS" 2>/dev/null || warn "No se pudo eliminar '$release'"
  done
  success "Releases eliminadas."
else
  info "No hay releases de Helm activas."
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  2. Terraform destroy
# ═══════════════════════════════════════════════════════════════════════════════
info "Ejecutando terraform destroy..."

cd "$SCRIPT_DIR"
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Infraestructura AWS eliminada completamente${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
