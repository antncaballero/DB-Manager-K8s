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

echo "---- Instalando Prometheus + Grafana (kube-prometheus-stack)..."
# Instala Prometheus, Grafana, Node Exporter y kube-state-metrics en un solo chart.
# - Sin persistencia (los datos se pierden al reiniciar Minikube, ok para desarrollo local)
# - AlertManager deshabilitado (no necesario)
# - Grafana accesible en NodePort 30300
helm upgrade --install kube-prometheus-stack kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --namespace monitoring --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.retention=6h \
  --set grafana.adminPassword=admin \
  --set grafana.persistence.enabled=false \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300

echo "---- Entorno listo."
echo ""
echo "---- IMPORTANTE: Abre OTRA terminal y ejecuta 'minikube tunnel' para que funcione la red."
echo ""
echo "---- Grafana disponible en: http://\$(minikube ip):30300"
echo "     Usuario: admin  |  Contraseña: admin"