# RentBot - Deployment en Producción

Guía completa para deployar RentBot en un servidor Ubuntu usando releases de producción.

## 📋 Prerrequisitos

### En el Servidor Ubuntu

1. **Elixir y Erlang**:
```bash
# Opción 1: Usando apt (versiones del repositorio)
sudo apt update
sudo apt install erlang elixir

# Opción 2: Usando asdf (recomendado - versiones específicas)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
source ~/.bashrc
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.1
asdf install elixir 1.17.3-otp-27
asdf global erlang 27.1
asdf global elixir 1.17.3-otp-27
```

2. **Git** (para clonar el repositorio):
```bash
sudo apt install git
```

3. **Dependencias del sistema**:
```bash
sudo apt install build-essential
```

### Variables de Entorno

Necesitas obtener:
- `TG_BOT_TOKEN`: Token de tu bot de Telegram
- `TG_CHAT_ID`: ID del chat donde quieres recibir notificaciones

## 🚀 Proceso de Deployment

### 1. Preparar el Release Localmente

```bash
# En tu máquina de desarrollo
cd /Users/ernesto/scripts/depa_finder

# Construir el release
mix rent_bot.release

# O con opciones adicionales:
mix rent_bot.release --clean --test
```

### 2. Deployment en el Servidor

```bash
# 1. Clonar el repositorio en el servidor
git clone https://github.com/ernestoacevedo/depa_finder.git
cd depa_finder

# 2. Configurar variables de entorno
export TG_BOT_TOKEN="tu_token_aqui"
export TG_CHAT_ID="tu_chat_id_aqui"

# 3. Ejecutar el script de deployment
chmod +x deploy.sh
sudo ./deploy.sh
```

## 🔧 Gestión del Servicio

### Comandos Básicos

```bash
# Ver estado
sudo systemctl status rent_bot

# Iniciar servicio
sudo systemctl start rent_bot

# Parar servicio
sudo systemctl stop rent_bot

# Reiniciar servicio
sudo systemctl restart rent_bot

# Habilitar inicio automático
sudo systemctl enable rent_bot

# Deshabilitar inicio automático
sudo systemctl disable rent_bot
```

### Ver Logs

```bash
# Logs en tiempo real
sudo journalctl -u rent_bot -f

# Logs de las últimas 100 líneas
sudo journalctl -u rent_bot -n 100

# Logs desde el último boot
sudo journalctl -u rent_bot -b
```

## ⚙️ Configuración

### Variables de Entorno Disponibles

El archivo `/etc/rent_bot.env` puede contener:

```bash
# Requeridas
TG_BOT_TOKEN=your_telegram_bot_token
TG_CHAT_ID=your_telegram_chat_id

# Opcionales
SCRAPE_INTERVAL_MINUTES=10  # Intervalo de scraping (default: 10 minutos)
```

### Archivos Importantes

- **Ejecutable**: `/opt/rent_bot/bin/rent_bot`
- **Base de datos**: `/var/lib/rent_bot/rent_bot.sqlite3`
- **Configuración**: `/etc/rent_bot.env`
- **Servicio**: `/etc/systemd/system/rent_bot.service`
- **Logs**: `journalctl -u rent_bot`

### Cambiar Configuración de Scraping

Para modificar los filtros de búsqueda, edita `config/config.exs`:

```elixir
config :rent_bot, :filters,
  comunas: ["Providencia", "Las Condes", "Ñuñoa"],  # Agregar más comunas
  precio_max: 1_200_000,  # Cambiar precio máximo
  min_m2: 50,             # Cambiar área mínima
  min_dorms: 1            # Cambiar dormitorios mínimos
```

Luego rebuild y redeploy:

```bash
mix rent_bot.release
sudo ./deploy.sh
```

## 🔄 Actualización

Para actualizar a una nueva versión:

```bash
# En el servidor
cd depa_finder
git pull origin master

# Reconstruir y deployar
export TG_BOT_TOKEN="tu_token"
export TG_CHAT_ID="tu_chat_id"
sudo ./deploy.sh
```

El script automáticamente:
- Para el servicio actual
- Respalda la instalación anterior
- Instala la nueva versión
- Ejecuta migraciones si hay
- Reinicia el servicio

## 🐛 Troubleshooting

### El servicio no inicia

```bash
# Ver logs detallados
sudo journalctl -u rent_bot -f

# Verificar configuración
sudo systemctl cat rent_bot

# Probar el ejecutable manualmente
sudo -u rent_bot -E HOME=/var/lib/rent_bot /opt/rent_bot/bin/rent_bot start
```

### Problemas de permisos

```bash
# Verificar propietario de archivos
ls -la /opt/rent_bot/
ls -la /var/lib/rent_bot/

# Corregir permisos si es necesario
sudo chown -R rent_bot:rent_bot /opt/rent_bot/
sudo chown -R rent_bot:rent_bot /var/lib/rent_bot/
```

### Base de datos corrupta

```bash
# Respaldar base de datos actual
sudo cp /var/lib/rent_bot/rent_bot.sqlite3 /var/lib/rent_bot/rent_bot.sqlite3.backup

# Eliminar base de datos (se recreará automáticamente)
sudo rm /var/lib/rent_bot/rent_bot.sqlite3*

# Reiniciar servicio para que se recree
sudo systemctl restart rent_bot
```

### Probar scraping manual

```bash
# Ejecutar un ciclo de scraping manualmente
sudo -u rent_bot -E HOME=/var/lib/rent_bot /opt/rent_bot/bin/rent_bot rpc "
  with {:ok, listings} <- RentBot.Scraper.fetch_all(),
       {:ok, new} <- RentBot.Store.save_new(listings) do
    RentBot.Notifier.notify_many(new)
    IO.puts(\"Scraped=\#{length(listings)} new=\#{length(new)}\")
  end
"
```

## 📊 Monitoreo

### Verificar que está scrapeando

Los logs deben mostrar actividad cada 10 minutos:

```bash
sudo journalctl -u rent_bot -f | grep -E "(cycle|scraped|new)"
```

### Verificar base de datos

```bash
# Conectar a la base de datos
sudo -u rent_bot sqlite3 /var/lib/rent_bot/rent_bot.sqlite3

# Ver listados más recientes
.headers on
SELECT url, price, area, inserted_at FROM listings ORDER BY inserted_at DESC LIMIT 10;
.quit
```

## 🔐 Seguridad

El deployment implementa las siguientes medidas de seguridad:

- Ejecuta con usuario no-privilegiado (`rent_bot`)
- Protección del sistema de archivos (`ProtectSystem=strict`)
- Directorio temporal privado (`PrivateTmp=true`)
- Variables de entorno protegidas (permisos 640)
- Sin capacidades adicionales (`NoNewPrivileges=true`)

## 📞 Soporte

Si encuentras problemas:

1. Revisa los logs: `sudo journalctl -u rent_bot -f`
2. Verifica la configuración de red y conectividad
3. Confirma que las variables de entorno están correctas
4. Prueba el scraping manual para aislar el problema
