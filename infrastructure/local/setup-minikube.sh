#!/bin/bash
# setup-minikube.sh

echo "---- Arrancando Minikube..."
minikube start --cpus 4 --memory 6g

echo "---- Instalando NGINX Ingress Controller (con soporte TCP)..."
# Usamos Helm para instalarlo limpio y configurado
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.tcp.configMapNamespace="ingress-nginx" \
  --set controller.tcp.configMapName="tcp-services"

echo "---- Creando el ConfigMap para los puertos TCP..."
kubectl create configmap tcp-services -n ingress-nginx

echo "---- Entorno listo."
echo "----  IMPORTANTE: Abre OTRA terminal y ejecuta 'minikube tunnel' para que funcione la red."