# ╔═════════════════════════════════════════════════════════════════════════════╗
# ║  modules/vpc/main.tf – Red privada virtual en AWS                           ║
# ║                                                                             ║
# ║  La VPC (Virtual Private Cloud) es la red aislada donde vivirá todo:        ║
# ║  el cluster EKS, los nodos, los volúmenes de datos, etc.                    ║
# ║                                                                             ║
# ║  Componentes que crea:                                                      ║
# ║    - VPC: la red principal con su rango de IPs                              ║
# ║    - Subnets públicas: para el Load Balancer (acceso desde internet)        ║
# ║    - Subnets privadas: para los nodos del cluster (sin acceso directo)      ║
# ║    - Internet Gateway: puerta de salida a internet                          ║
# ║    - NAT Gateway: permite que los nodos privados descarguen imágenes        ║
# ║    - Tablas de rutas: definen cómo fluye el tráfico                         ║
# ║                                                                             ║
# ║  NOTA DE COSTES:                                                            ║
# ║    Usamos solo 1 NAT Gateway (en vez de 1 por AZ) para reducir costes.      ║
# ╚═════════════════════════════════════════════════════════════════════════════╝

# ── Data source: obtener AZs disponibles en la región ────────────────────────
# No todas las regiones tienen las mismas AZs. Esto las descubre dinámicamente.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Usar solo las AZs que hemos pedido (2)
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
}

# ═══════════════════════════════════════════════════════════════════════════════
#  VPC – La red principal
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Necesario para que EKS funcione: resolución DNS interna
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  INTERNET GATEWAY – Puerta de entrada/salida a internet
# ═══════════════════════════════════════════════════════════════════════════════
# Sin esto, nada dentro de la VPC puede hablar con internet.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  SUBNETS PÚBLICAS – Para el Load Balancer de NGINX Ingress
# ═══════════════════════════════════════════════════════════════════════════════
# Las subnets públicas tienen ruta directa a internet vía el Internet Gateway.
# Aquí vive el Network Load Balancer (NLB) que recibe tráfico externo.

resource "aws_subnet" "public" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  availability_zone = local.azs[count.index]

  # Las instancias en esta subnet reciben IP pública automáticamente
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${local.azs[count.index]}"
    # Tag requerido por AWS Load Balancer Controller para detectar subnets públicas
    "kubernetes.io/role/elb" = "1"
    # Tag requerido por EKS para saber que esta subnet pertenece al cluster
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  SUBNETS PRIVADAS – Para los nodos worker del cluster EKS
# ═══════════════════════════════════════════════════════════════════════════════
# Los nodos (EC2) donde corren los pods de MySQL/MongoDB están aquí.
# No son accesibles directamente desde internet → más seguro.
# Salen a internet solo a través del NAT Gateway (para descargar imágenes Docker).

resource "aws_subnet" "private" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-private-${local.azs[count.index]}"
    # Tag para Load Balancers internos (no lo usamos, pero es buena práctica)
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  NAT GATEWAY – Permite que los nodos privados salgan a internet
# ═══════════════════════════════════════════════════════════════════════════════
# Los nodos necesitan descargar imágenes de Docker Hub (mysql:8.0, mongo:7.0).
# El NAT Gateway actúa como intermediario: los nodos salen a internet, pero
# nadie de internet puede iniciar una conexión hacia ellos.


resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Se ubica en la primera subnet pública

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# ═══════════════════════════════════════════════════════════════════════════════
#  TABLAS DE RUTAS – Definen a dónde va el tráfico
# ═══════════════════════════════════════════════════════════════════════════════

# ── Tabla de rutas pública: tráfico → Internet Gateway ────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # Todo el tráfico que no sea local...
    gateway_id = aws_internet_gateway.main.id # ...sale por el Internet Gateway
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.availability_zones_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Tabla de rutas privada: tráfico → NAT Gateway ────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0" # Todo el tráfico que no sea local...
    nat_gateway_id = aws_nat_gateway.main.id # ...sale por el NAT Gateway
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.availability_zones_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
