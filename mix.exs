defmodule RentBot.MixProject do
  use Mix.Project
  def project, do: [
    app: :rent_bot,
    version: "0.1.0",
    elixir: "~> 1.17",
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]
  def application, do: [
    extra_applications: [:logger, :inets, :ssl],
    mod: {RentBot.Application, []}
  ]
  defp deps, do: [
    {:req, "~> 0.5"},
    {:floki, "~> 0.36"},
    {:jason, "~> 1.4"},
    {:ecto, "~> 3.11"},
    {:ecto_sql, "~> 3.11"},
    {:ecto_sqlite3, "~> 0.18"},
    {:dotenv, "~> 3.0"}
  ]
end
