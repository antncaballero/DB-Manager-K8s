# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/eks/main.tf – Cluster EKS (Kubernetes gestionado por AWS)          ║
# ║                                                                             ║
# ║  ADAPTADO PARA AWS ACADEMY:                                                 ║
# ║    - NO se crean roles IAM custom (prohibido en Academy)                    ║
# ║    - Se usa el rol pre-creado "LabRole", que es el único rol genérico       ║
# ║      disponible en el lab y tiene permisos suficientes para:                ║
# ║        · Control plane del cluster EKS                                      ║
# ║        · Nodos worker EC2 (Node Group)                                      ║
# ║        · EBS CSI Driver (vía instance profile del nodo)                     ║
# ║    - NO se crea OIDC Provider ni roles IRSA (prohibido en AWS Academy)      ║
# ║                                                                             ║
# ║  Componentes:                                                               ║
# ║    1. Data source: rol IAM pre-creado LabRole                               ║
# ║    2. Security Group para controlar tráfico de red                          ║
# ║    3. El cluster EKS en sí                                                  ║
# ║    4. Node Group (grupo de nodos EC2 auto-gestionados)                      ║
# ║    5. EBS CSI Driver addon                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝


# ═══════════════════════════════════════════════════════════════════════════════
#  1. IAM ROL PRE-CREADO POR AWS ACADEMY
# ═══════════════════════════════════════════════════════════════════════════════
# En AWS Academy NO se pueden crear roles IAM personalizados.
# El laboratorio pre-crea un rol genérico llamado "LabRole" que tiene
# permisos amplios, incluyendo todas las políticas necesarias para EKS:
#
#   - AmazonEKSClusterPolicy (control plane)
#   - AmazonEKSWorkerNodePolicy (nodos worker)
#   - AmazonEKS_CNI_Policy (networking de pods)
#   - AmazonEC2ContainerRegistryReadOnly (descargar imágenes)
#   - AmazonEBSCSIDriverPolicy (gestionar volúmenes EBS)
#   - Y muchas más (Lambda, S3, etc.)
#
# Su trust policy permite que tanto eks.amazonaws.com como ec2.amazonaws.com
# lo asuman, por lo que sirve para el cluster Y para los nodos.
#
# NOTA: AWS Academy también crea roles específicos (LabEksClusterRole,
# LabEksNodeRole) cuyos nombres incluyen prefijos/sufijos de sesión
# aleatorios, pero LabRole es estable y engloba estos dos casos, así que lo usamos directamente.

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}


# ═══════════════════════════════════════════════════════════════════════════════
#  2. SECURITY GROUP PARA LOS NODOS
# ═══════════════════════════════════════════════════════════════════════════════
# Controla qué tráfico de red puede entrar y salir de los nodos del cluster.

resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  vpc_id      = var.vpc_id
  description = "Security group para los nodos worker del cluster EKS"

  # Permitir TODO el tráfico entre nodos del cluster (pods hablan entre sí)
  ingress {
    description = "Trafico entre nodos del cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Rango de puertos TCP para MySQL (3306-3330) – acceso desde internet
  # Estos puertos llegan al NLB → NGINX Ingress → Service → Pod MySQL
  ingress {
    description = "MySQL TCP ports"
    from_port   = var.mysql_port_range_start
    to_port     = var.mysql_port_range_end
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Rango de puertos TCP para MongoDB (27017-27040) – acceso desde internet
  ingress {
    description = "MongoDB TCP ports"
    from_port   = var.mongo_port_range_start
    to_port     = var.mongo_port_range_end
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Rango de puertos TCP para Redis (6379-6404) – acceso desde internet
  ingress {
    description = "Redis TCP ports"
    from_port   = var.redis_port_range_start
    to_port     = var.redis_port_range_end
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Rango de puertos TCP para Cassandra (9042-9067) – acceso desde internet
  ingress {
    description = "Cassandra TCP ports"
    from_port   = var.cassandra_port_range_start
    to_port     = var.cassandra_port_range_end
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir TODA la salida (nodos necesitan descargar imágenes, hablar con API, etc.)
  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-nodes-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}


# ═══════════════════════════════════════════════════════════════════════════════
#  4. CLUSTER EKS
# ═══════════════════════════════════════════════════════════════════════════════
# El propio cluster de Kubernetes gestionado por AWS.

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  version  = var.cluster_version
  role_arn = data.aws_iam_role.lab_role.arn

  # Configuración de red: en qué subnets vive el cluster
  vpc_config {
    # Subnets donde EKS crea ENIs para la comunicación control-plane ↔ nodos
    # Se incluyen ambas (públicas + privadas) para que el control plane pueda
    # comunicarse con los nodos en las subnets privadas
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)

    # El endpoint del API server es público → se puede hacer kubectl desde el propio PC
    endpoint_public_access  = true
    # También accesible desde dentro de la VPC (los nodos hablan por red privada)
    endpoint_private_access = true

    security_group_ids = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${var.project_name}-eks"
  }
}


# ═══════════════════════════════════════════════════════════════════════════════
#  5. NODE GROUP – Grupo de nodos EC2 auto-gestionados
# ═══════════════════════════════════════════════════════════════════════════════
# Son las máquinas EC2 reales donde corren los pods de MySQL/MongoDB.
# EKS gestiona su ciclo de vida (escalar, actualizar, reemplazar).

# ── Launch Template con IMDS configurado ─────────────────────────────────────
# Necesario para que el EBS CSI Driver (controller) pueda obtener credenciales
# IAM desde el Instance Metadata Service.
# Los pods que NO usan hostNetwork necesitan hop_limit=2 porque el paquete
# atraviesa: pod → veth bridge → host → IMDS (2 saltos de red).
# Sin esto, con hop_limit=1 (por defecto), el paquete IMDS se descarta
# y el CSI Driver no puede autenticarse contra la API de EC2.
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project_name}-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.node_disk_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 (más seguro)
    http_put_response_hop_limit = 2           # Permitir acceso desde pods
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-node"
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = data.aws_iam_role.lab_role.arn

  subnet_ids = var.private_subnet_ids

  # Usar launch template para configurar IMDS hop_limit=2
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  instance_types = var.node_instance_types
  # disk_size se define en el launch template (block_device_mappings)
  # porque EKS lo exige así cuando se usa launch_template

  # Configuración del auto-scaling
  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }

  # Estrategia de actualización: máximo 1 nodo no disponible a la vez
  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.project_name}-nodes"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"                     = "true"
  }
}


# ═══════════════════════════════════════════════════════════════════════════════
#  6. EBS CSI DRIVER – Para que los PersistentVolumeClaims funcionen
# ═══════════════════════════════════════════════════════════════════════════════
# En k3d, los PVC usan el StorageClass "local-path".
# En AWS, necesitan EBS (Elastic Block Store) = discos virtuales.
# El EBS CSI Driver conecta Kubernetes con EBS para crear/montar discos.
#
# El EBS CSI Driver necesita credenciales IAM para crear/montar volúmenes EBS.
#
# En AWS Academy NO se puede usar IRSA (IAM Roles for Service Accounts) porque:
#   - Requiere crear un OIDC Provider en IAM (iam:CreateOpenIDConnectProvider)
#   - Academy bloquea operaciones IAM
#
# SOLUCIÓN: NO especificar service_account_role_arn.
# Sin él, el CSI Driver usa el INSTANCE PROFILE del nodo EC2 (LabRole)
# en lugar de asumir un rol vía STS/OIDC. Esto funciona porque:
#   - Cada nodo EC2 del Node Group tiene asociado LabRole como instance profile
#   - LabRole tiene permisos suficientes para gestionar volúmenes EBS
#   - Los pods del CSI Driver heredan esas credenciales del nodo donde corren

# Addon de EKS: instala el EBS CSI Driver como componente gestionado
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  # NO se usa service_account_role_arn → el driver usa el instance profile
  # del nodo (LabRole) en lugar de IRSA/OIDC

  timeouts {
    create = "10m"
  }

  depends_on = [aws_eks_node_group.main]
}
