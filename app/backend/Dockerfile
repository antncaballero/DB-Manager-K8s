FROM python:3.12-slim

# ── Metadatos ────────────────────────────────────────────────────────────────
LABEL maintainer="TFG DB Manager" \
      description="Backend – mando a distancia para desplegar clusters de BBDD en Kubernetes"

# ── Dependencias del sistema ─────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# ── Instalar kubectl ────────────────────────────────────────────────────────
ARG KUBECTL_VERSION=v1.31.4
RUN curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# ── Instalar Helm v3 ────────────────────────────────────────────────────────
ARG HELM_VERSION=v3.16.4
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
        | tar -xz --strip-components=1 -C /usr/local/bin linux-amd64/helm \
    && chmod +x /usr/local/bin/helm

# ── Instalar AWS CLI v2 (necesario si el cluster es EKS) ────────────────────
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# ── Directorio de trabajo ───────────────────────────────────────────────────
WORKDIR /app

# ── Dependencias de Python ──────────────────────────────────────────────────
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Copiar código fuente ────────────────────────────────────────────────────
COPY . .

# ── Puerto de la API ────────────────────────────────────────────────────────
EXPOSE 8000

# ── Arranque ─────────────────────────────────────────────────────────────────
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
