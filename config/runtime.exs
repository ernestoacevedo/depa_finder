import Config

env_file = Path.expand("../.env", __DIR__)

if File.exists?(env_file) do
  Dotenv.load!(env_file)
end

bot_token =
  System.get_env("TG_BOT_TOKEN") ||
    raise "Environment variable TG_BOT_TOKEN is required. Check your .env file."

chat_id =
  System.get_env("TG_CHAT_ID") ||
    raise "Environment variable TG_CHAT_ID is required. Check your .env file."

config :rent_bot, :telegram,
  bot_token: bot_token,
  chat_id: chat_id
