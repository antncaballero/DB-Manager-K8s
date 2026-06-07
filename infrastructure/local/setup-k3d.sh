#!/bin/bash
# setup-k3d.sh

echo "---- Creando cluster k3d..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/bootstrap"
TF_DIR="${SCRIPT_DIR}/terraform"

echo "---- Inicializando Terraform de bootstrap local..."
bootstrap_tf_cmd=(terraform -chdir="$BOOTSTRAP_DIR")
"${bootstrap_tf_cmd[@]}" init

echo "---- Creando cluster k3d y preparando imágenes con Terraform..."
"${bootstrap_tf_cmd[@]}" apply -auto-approve

echo "---- Inicializando Terraform de addons de Kubernetes..."
tf_cmd=(terraform -chdir="$TF_DIR")
"${tf_cmd[@]}" init

echo "---- Aplicando Terraform..."
"${tf_cmd[@]}" apply -auto-approve

echo "---- Entorno listo."
echo "# Frontend DB Manager: http://localhost:30080/"
echo "# Para grafana ejecuta esto en una terminal: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3300:80"
echo "# Y abre http://localhost:3300 con user: admin y password: admin"
