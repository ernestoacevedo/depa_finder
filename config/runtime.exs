import Config

# En desarrollo, intentar cargar archivo .env local
if config_env() == :dev do
  env_file = Path.expand("../.env", __DIR__)
  if File.exists?(env_file) do
    Dotenv.load!(env_file)
  end
end

# Las variables de entorno deben estar disponibles en el sistema
# En producción se configuran via systemd EnvironmentFile
bot_token =
  System.get_env("TG_BOT_TOKEN") ||
    raise """
    Environment variable TG_BOT_TOKEN is required.

    For development: Create a .env file in the project root with:
    TG_BOT_TOKEN=your_token_here

    For production: Set the environment variable in your deployment system.
    """

chat_id =
  System.get_env("TG_CHAT_ID") ||
    raise """
    Environment variable TG_CHAT_ID is required.

    For development: Create a .env file in the project root with:
    TG_CHAT_ID=your_chat_id_here

    For production: Set the environment variable in your deployment system.
    """

signing_salt =
  System.get_env("PHOENIX_SIGNING_SALT") ||
    raise """
    Environment variable PHOENIX_SIGNING_SALT is required.

    For development: Create a .env file in the project root with:
    PHOENIX_SIGNING_SALT=your_random_salt_here

    For production: Set the environment variable in your deployment system.

    You can generate a secure signing salt with:
    mix phx.gen.secret 32
    """

config :rent_bot, :telegram,
  bot_token: bot_token,
  chat_id: chat_id

config :rent_bot,
  signing_salt: signing_salt
