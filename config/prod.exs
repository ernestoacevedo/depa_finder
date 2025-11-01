import Config

# Configuración para producción
config :logger, level: :info

# Base de datos en producción - usar directorio de datos persistente
config :rent_bot, RentBot.Repo,
  database: Path.join(System.get_env("HOME", "/var/lib/rent_bot"), "rent_bot.sqlite3"),
  pool_size: 5,
  log: false

# Configurar scheduler para producción (cada 10 minutos)
# Se puede sobrescribir con variable de entorno SCRAPE_INTERVAL_MINUTES
interval_minutes = 
  case System.get_env("SCRAPE_INTERVAL_MINUTES") do
    nil -> 10
    val -> String.to_integer(val)
  end

config :rent_bot, :scheduler,
  interval_ms: interval_minutes * 60 * 1000