import Config

if File.exists?(".env") do
  Dotenv.load()
end

config :rent_bot, :telegram,
  bot_token: System.get_env("TG_BOT_TOKEN"),
  chat_id: System.get_env("TG_CHAT_ID")
