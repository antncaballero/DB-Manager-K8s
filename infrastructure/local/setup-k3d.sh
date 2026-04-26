#!/bin/bash
# setup-k3d.sh

echo "---- Creando cluster k3d..."
# Exponemos: 
# - 80/443 para el tráfico web/API
# - 3306-3330 para instancias SQL
# - 27017-27040 para instancias NoSQL (Mongo)
k3d cluster create tfg-cluster \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  -p "3306-3330:3306-3330@loadbalancer" \
  -p "27017-27040:27017-27040@loadbalancer" \
  --agents 1

echo "---- Instalando NGINX Ingress Controller..."
# k3d viene con Traefik por defecto, pero como tu script usa Nginx, 
# lo instalamos y k3d se encarga de mapear el puerto.
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.tcp-services-configmap=ingress-nginx/tcp-services

echo "---- Creando el ConfigMap para los puertos TCP..."
kubectl create configmap tcp-services -n ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

echo "---- Instalando Prometheus + Grafana..."
# Cambiamos el service type a ClusterIP o LoadBalancer ya que k3d 
# gestiona mejor el tráfico mediante Ingress o mapeo de puertos.
helm upgrade --install kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.retention=6h \
  --set grafana.adminPassword=admin \
  --set grafana.persistence.enabled=false \
  --set grafana.service.type=LoadBalancer

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
echo "# Para grafana: Ejecuta esto en una terminal: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3300:80"