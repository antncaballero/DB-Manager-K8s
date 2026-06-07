#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BACKEND_IMAGE="${BACKEND_IMAGE:-db-manager-backend:latest}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-db-manager-frontend:latest}"
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-tfg-cluster}"

echo "---- Building backend image: ${BACKEND_IMAGE}"
docker build \
  -f "${REPO_ROOT}/app/backend/Dockerfile.k8s" \
  -t "${BACKEND_IMAGE}" \
  "${REPO_ROOT}"

echo "---- Building frontend image: ${FRONTEND_IMAGE}"
docker build \
  -f "${REPO_ROOT}/app/frontend/Dockerfile.k8s" \
  -t "${FRONTEND_IMAGE}" \
  "${REPO_ROOT}"

echo "---- Importing images into k3d cluster: ${K3D_CLUSTER_NAME}"
k3d image import "${BACKEND_IMAGE}" -c "${K3D_CLUSTER_NAME}"
k3d image import "${FRONTEND_IMAGE}" -c "${K3D_CLUSTER_NAME}"

echo "---- Images ready inside k3d."
