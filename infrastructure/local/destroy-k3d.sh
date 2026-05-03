#!/bin/bash
# destroy-k3d.sh

echo "---- Destruyendo recursos con Terraform..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"

tf_cmd=(terraform -chdir="$TF_DIR")
"${tf_cmd[@]}" destroy -auto-approve

echo "---- Borrando cluster k3d..."
k3d cluster delete tfg-cluster

echo "---- Entorno destruido."
