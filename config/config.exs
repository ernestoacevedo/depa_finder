import Config
config :rent_bot, RentBot.Repo, database: "rent_bot.sqlite3", pool_size: 5
config :rent_bot, :filters,
  comunas: ["Providencia", "Las Condes"],
  precio_max: 900_000, min_m2: 40, min_dorms: 1
config :rent_bot, :telegram,
  bot_token: System.get_env("TG_BOT_TOKEN"),
  chat_id: System.get_env("TG_CHAT_ID")
