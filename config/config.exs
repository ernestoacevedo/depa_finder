import Config
config :rent_bot, ecto_repos: [RentBot.Repo]

config :rent_bot, RentBot.Repo,
  database: "rent_bot.sqlite3",
  pool_size: 5

config :rent_bot, :filters,
  comunas: ["Providencia", "Las Condes"],
  precio_max: 1_100_000, min_m2: 60, min_dorms: 2

# Importar configuración específica del entorno
import_config "#{config_env()}.exs"
