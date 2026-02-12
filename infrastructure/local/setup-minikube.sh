#!/bin/bash
# setup-minikube.sh

echo "---- Arrancando Minikube..."
minikube start --cpus 4 --memory 6g

echo "---- Instalando NGINX Ingress Controller (con soporte TCP)..."
# Usamos Helm para instalarlo limpio y configurado
# controller.extraArgs.tcp-services-configmap indica al controller qué ConfigMap
# vigilar para las reglas de proxy TCP (se actualiza dinámicamente por el backend).
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.extraArgs.tcp-services-configmap=ingress-nginx/tcp-services

echo "---- Creando el ConfigMap para los puertos TCP (si no existe)..."
kubectl create configmap tcp-services -n ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

echo "---- Entorno listo."
echo "----  IMPORTANTE: Abre OTRA terminal y ejecuta 'minikube tunnel' para que funcione la red."