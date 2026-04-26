# Orquestador de despliegues de bases de datos en Kubernetes

Proyecto de TFG (Ingeniería Informática, Universidad de Murcia) para gestionar despliegues de bases de datos en Kubernetes.

El proyecto está centrado en **Infraestructura como Código (IaC) con Terraform y AWS Academy (EKS)**, y también incluye una alternativa de ejecución local con **k3d**.

## Introducción

DB Manager K8s permite a un docente desplegar, visualizar, despertar y destruir entornos de bases de datos por clase de forma centralizada.

Para cada clase, el sistema despliega una release de Helm y genera instancias de MySQL o MongoDB por alumno, asignando puertos de acceso externos de forma automática.

## ¿De qué está compuesto?

```text
tfg-db-manager/
├─ app/
│  ├─ backend/                 # API FastAPI + lógica de orquestación Helm/K8s
│  ├─ frontend/                # React + Vite servido por Nginx
│  ├─ docker-compose.aws.yaml  # App conectada a EKS
│  └─ docker-compose.k3d.yaml  # App conectada a cluster local k3d
├─ charts/
│  ├─ mysql-class/             # Chart Helm para despliegues de clase MySQL
│  └─ mongo-class/             # Chart Helm para despliegues de clase MongoDB
└─ infrastructure/
   ├─ aws-terraform/           # IaC en AWS (VPC, EKS, ingress, storage, monitoring)
   └─ local/setup-k3d.sh       # Preparación del entorno local con k3d
```

## Prerrequisitos

### Comunes

- Docker + Docker Compose
- kubectl
- Helm

### Para AWS Academy (flujo principal)

- Cuenta/lab de AWS Academy activo
- AWS CLI configurado (`aws configure`)
- Terraform

### Para local

- k3d

## Ejecución en AWS Academy (Terraform + EKS)

> Flujo principal recomendado del proyecto.

### 1) Crear infraestructura en AWS con Terraform

```bash
cd infrastructure/aws-terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 2) Configurar `kubectl` y validar el cluster

```bash
./setup-eks.sh
```

Este script configura el kubeconfig para EKS, valida nodos/ingress y deja el entorno listo para la aplicación.

### 3) Levantar frontend + backend

```bash
cd ../../app
docker compose -f docker-compose.aws.yaml up -d --build
```

Accesos:

- Frontend: `http://localhost:3000`
- Backend (health): `http://localhost:8000/health`

## Ejecución alternativa local con k3d

### 1) Crear cluster local y preparar entorno

```bash
cd infrastructure/local
./setup-k3d.sh
```

Este script crea el cluster `tfg-cluster`, instala ingress/monitoring y genera `~/.kube/config-backend` para el contenedor backend.

### 2) Levantar frontend + backend

```bash
cd ../../app
docker compose -f docker-compose.k3d.yaml up -d --build
```

Accesos:

- Frontend: `http://localhost:3000`
- Backend (health): `http://localhost:8000/health`

## Uso funcional

Desde la interfaz web se puede:

- Desplegar entornos por clase (`mysql` o `mongo`).
- Listar despliegues activos.
- Despertar despliegues hibernados.
- Destruir despliegues.

## Destrucción y limpieza

### A) Parar solo la aplicación (mantener infraestructura)

Desde `app/`:

```bash
docker compose -f docker-compose.aws.yaml down
# o
docker compose -f docker-compose.k3d.yaml down
```

### B) Destruir infraestructura AWS (Terraform)

Desde `infrastructure/aws-terraform`:

```bash
./destroy-eks.sh
```

Este script elimina primero releases Helm y después ejecuta `terraform destroy -auto-approve`.

### C) Destruir entorno local k3d

```bash
cd app
docker compose -f docker-compose.k3d.yaml down

k3d cluster delete tfg-cluster
```
