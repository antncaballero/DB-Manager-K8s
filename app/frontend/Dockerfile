# ── Etapa 1: Build ───────────────────────────────────────────────────────────
FROM node:22-alpine AS build

WORKDIR /app

# Instalar dependencias (cacheo de capas)
COPY package.json package-lock.json ./
RUN npm ci

# Copiar código fuente y compilar
COPY . .
RUN npm run build

# ── Etapa 2: Servir con Nginx ───────────────────────────────────────────────
FROM nginx:alpine

# Copiar el build estático
COPY --from=build /app/dist /usr/share/nginx/html

# Configuración de Nginx con proxy al backend
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
