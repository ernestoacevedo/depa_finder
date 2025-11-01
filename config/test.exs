import Config

# Configuración para pruebas
config :logger, level: :warning

config :rent_bot, RentBot.Repo,
  database: "rent_bot_test.sqlite3",
  pool: Ecto.Adapters.SQL.Sandbox