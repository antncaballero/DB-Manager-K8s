#!/bin/bash
# destroy-k3d.sh

echo "---- Destruyendo recursos con Terraform..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"
BOOTSTRAP_DIR="${SCRIPT_DIR}/bootstrap"

tf_cmd=(terraform -chdir="$TF_DIR")
"${tf_cmd[@]}" destroy -auto-approve

echo "---- Borrando cluster k3d con Terraform..."
bootstrap_tf_cmd=(terraform -chdir="$BOOTSTRAP_DIR")
"${bootstrap_tf_cmd[@]}" destroy -auto-approve

echo "---- Entorno destruido."
