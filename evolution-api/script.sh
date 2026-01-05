#!/bin/bash
set -e

# --- CONFIGURACIÓN ---
IP="xxx.xx.xxx.xxx"
PASSWORD="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PROJECT_DIR="evolution_project"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres_password"

# --- COLORES ---
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
NC='\033[0m'

echo -e "${VERDE}[1/6] Actualizando sistema...${NC}"
apt update -y

echo -e "${VERDE}[2/6] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo "Docker no encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
else
    echo "Docker ya instalado ✓"
fi

echo -e "${VERDE}[3/6] Creando directorio...${NC}"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

echo -e "${VERDE}[4/6] Limpiando instalación previa...${NC}"
docker compose down -v 2>/dev/null || true

echo -e "${VERDE}[5/6] Generando configuración...${NC}"
cat > docker-compose.yml <<EOF
version: '3.3'

services:
  evolution_api:
    container_name: evolution_api
    image: evoapicloud/evolution-api:v2.1.1
    restart: always
    ports:
      - "8080:8080"
    environment:
      - SERVER_URL=http://${IP}:8080
      - API_KEY=${PASSWORD}
      - AUTHENTICATION_API_KEY=${PASSWORD}
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/evolution
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://redis:6379/0
      - CACHE_LOCAL_ENABLED=false
      - DEL_INSTANCE=false
      - DOCKER_ENV=true
    depends_on:
      - postgres
      - redis
    volumes:
      - evolution_instances:/evolution/instances

  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: evolution
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7
    restart: always
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - redis_data:/data

volumes:
  evolution_instances:
  pgdata:
  redis_data:
EOF

echo -e "${VERDE}[6/6] Desplegando servicios...${NC}"
docker compose up -d

echo -e "${VERDE}✅ INSTALACIÓN COMPLETADA${NC}"
echo -e "${AMARILLO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "🌐 URL: http://${IP}:8080/manager"
echo -e "🔑 API Key: ${PASSWORD}"
echo -e "${AMARILLO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Mostrar logs
sleep 3
echo -e "\n📜 Logs del servicio:"
docker logs evolution_api --tail 20