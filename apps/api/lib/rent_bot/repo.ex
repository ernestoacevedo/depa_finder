defmodule RentBot.Repo do
  use Ecto.Repo, otp_app: :rent_bot, adapter: Ecto.Adapters.SQLite3
end
