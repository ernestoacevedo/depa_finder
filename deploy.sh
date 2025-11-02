#!/bin/bash

# Script de deployment para RentBot en Ubuntu
set -e

# Configuración
APP_NAME="rent_bot"
APP_USER="rent_bot"
APP_DIR="/opt/rent_bot"
DATA_DIR="/var/lib/rent_bot"
SERVICE_FILE="/etc/systemd/system/rent_bot.service"
ENV_FILE="/etc/rent_bot.env"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
    exit 1
}

# Verificar que estamos en el directorio correcto
if [ ! -f "mix.exs" ]; then
    error "Este script debe ejecutarse desde el directorio raíz del proyecto RentBot"
fi

# Verificar variables de entorno requeridas
if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    error "Las variables TG_BOT_TOKEN y TG_CHAT_ID son requeridas. Expórtalas antes de ejecutar este script."
fi

log "🚀 Iniciando deployment de RentBot..."

# 1. Verificar dependencias del sistema
log "🔍 Verificando dependencias del sistema..."
if ! command -v elixir &> /dev/null; then
    error "Elixir no está instalado. Por favor instálalo primero."
fi

if ! command -v systemctl &> /dev/null; then
    error "systemctl no está disponible. Este script requiere systemd."
fi

# 2. Crear usuario del sistema si no existe
if ! id "$APP_USER" &>/dev/null; then
    log "� Creando usuario del sistema..."
    sudo useradd --system --shell /bin/false --home-dir $DATA_DIR --create-home $APP_USER
    success "Usuario $APP_USER creado"
else
    log "Usuario $APP_USER ya existe"
fi

# 3. Crear directorios
log "📁 Creando directorios..."
sudo mkdir -p $APP_DIR
sudo mkdir -p $DATA_DIR
sudo chown $APP_USER:$APP_USER $DATA_DIR
sudo chmod 755 $DATA_DIR
success "Directorios creados"

# 4. Parar servicio si está ejecutándose
if systemctl is-active --quiet rent_bot; then
    log "⏸️  Parando servicio existente..."
    sudo systemctl stop rent_bot
fi

# 5. Compilar release
log "🔨 Construyendo release..."
export MIX_ENV=prod

# Limpiar compilación anterior
mix clean

# Instalar dependencias
mix deps.get --only prod
mix deps.compile

# Compilar aplicación
mix compile

# Crear release
mix release --overwrite

success "Release construido exitosamente"

# 6. Respaldar instalación anterior si existe
if [ -d "$APP_DIR/bin" ]; then
    log "💾 Respaldando instalación anterior..."
    sudo mv $APP_DIR $APP_DIR.backup.$(date +%Y%m%d_%H%M%S)
    sudo mkdir -p $APP_DIR
fi

# 7. Copiar release al directorio de la aplicación
log "📋 Copiando release..."
sudo cp -R _build/prod/rel/rent_bot/* $APP_DIR/
sudo chown -R $APP_USER:$APP_USER $APP_DIR
sudo chmod +x $APP_DIR/bin/rent_bot
success "Release copiado"

# 8. Crear archivo de variables de entorno
log "⚙️  Configurando variables de entorno..."
sudo tee $ENV_FILE > /dev/null << EOF
# Variables de entorno para RentBot
TG_BOT_TOKEN=$TG_BOT_TOKEN
TG_CHAT_ID=$TG_CHAT_ID

# Configuración opcional
# SCRAPE_INTERVAL_MINUTES=10
EOF

sudo chown root:$APP_USER $ENV_FILE
sudo chmod 640 $ENV_FILE
success "Variables de entorno configuradas"

# 9. Crear servicio systemd
log "🔧 Configurando servicio systemd..."
sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=RentBot - Rental listing scraper
Documentation=https://github.com/ernestoacevedo/depa_finder
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=exec
User=$APP_USER
Group=$APP_USER

# Comandos de ejecución
ExecStart=$APP_DIR/bin/rent_bot start
ExecStop=$APP_DIR/bin/rent_bot stop
ExecReload=/bin/kill -HUP \$MAINPID

# Configuración de reinicio
Restart=on-failure
RestartSec=5
StartLimitBurst=3
StartLimitInterval=60

# Variables de entorno
Environment=HOME=$DATA_DIR
Environment=MIX_ENV=prod
EnvironmentFile=$ENV_FILE

# Directorio de trabajo
WorkingDirectory=$DATA_DIR

# Configuración de recursos y seguridad
LimitNOFILE=65536
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR
NoNewPrivileges=true

# Configuración de señales
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30
FinalKillSignal=SIGKILL

[Install]
WantedBy=multi-user.target
EOF

success "Servicio systemd configurado"

# 10. Ejecutar migraciones
log "🗃️  Ejecutando migraciones..."
sudo -u $APP_USER -E HOME=$DATA_DIR $APP_DIR/bin/rent_bot eval "RentBot.Release.migrate()"
success "Migraciones ejecutadas"

# 11. Habilitar y iniciar servicio
log "▶️  Iniciando servicio..."
sudo systemctl daemon-reload
sudo systemctl enable rent_bot
sudo systemctl start rent_bot

# Esperar un momento para que el servicio inicie
sleep 3

# 12. Verificar estado del servicio
if systemctl is-active --quiet rent_bot; then
    success "¡Deployment completado exitosamente!"
    echo
    log "📊 Estado del servicio:"
    sudo systemctl status rent_bot --no-pager -l
    echo
    log "📝 Para ver los logs:"
    echo "  sudo journalctl -u rent_bot -f"
    echo
    log "🔧 Comandos útiles:"
    echo "  sudo systemctl status rent_bot     # Ver estado"
    echo "  sudo systemctl restart rent_bot    # Reiniciar"
    echo "  sudo systemctl stop rent_bot       # Parar"
    echo "  sudo systemctl start rent_bot      # Iniciar"
else
    error "El servicio no pudo iniciarse. Revisa los logs con: sudo journalctl -u rent_bot -f"
fi
