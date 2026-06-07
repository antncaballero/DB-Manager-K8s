#!/bin/bash
# setup-k3d.sh

echo "---- Creando cluster k3d..."
# Exponemos: 
# - 80/443 para el tráfico web/API
# - 3306-3330 para instancias SQL
# - 27017-27040 para instancias NoSQL (Mongo)
# - 6379-6404 para instancias Redis
# - 9042-9067 para instancias Cassandra
k3d cluster create tfg-cluster --k3s-arg "--disable=traefik@server:0" \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  -p "3306-3330:3306-3330@loadbalancer" \
  -p "27017-27040:27017-27040@loadbalancer" \
  -p "6379-6404:6379-6404@loadbalancer" \
  -p "9042-9067:9042-9067@loadbalancer" \
  --agents 1

echo "---- Inicializando Terraform..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"
APP_DIR="${SCRIPT_DIR}/../../app"

echo "---- Construyendo e importando imágenes de la app en k3d..."
"${APP_DIR}/build-k8s-images.sh"

tf_cmd=(terraform -chdir="$TF_DIR")
"${tf_cmd[@]}" init

echo "---- Aplicando Terraform..."
"${tf_cmd[@]}" apply -auto-approve

# 1. Crear una copia específica para el contenedor del backend
cp ~/.kube/config ~/.kube/config-backend

# 2. Extraer el puerto dinámico que k3d asignó al servidor (ej. 43155)
CLUSTER_PORT=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="k3d-tfg-cluster")].cluster.server}' | cut -d: -f3)

# 3. Modificar LA COPIA para que apunte al nombre del contenedor en la red de Docker
# En lugar de buscar en 0.0.0.0, buscará al servidor de k3d por su nombre DNS interno
sed -i "s/0.0.0.0:${CLUSTER_PORT}/k3d-tfg-cluster-server-0:6443/g" ~/.kube/config-backend
sed -i "s/127.0.0.1:${CLUSTER_PORT}/k3d-tfg-cluster-server-0:6443/g" ~/.kube/config-backend

echo "---- Copia de seguridad del config lista para el Backend."

echo "---- Entorno listo."
echo "# Frontend DB Manager: http://localhost/"
echo "# Para grafana ejecuta esto en una terminal: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3300:80"
echo "# Y abre http://localhost:3300 con user: admin y password: admin"
