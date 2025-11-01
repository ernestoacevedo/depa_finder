defmodule RentBot.Application do
  use Application
  def start(_t, _a) do
    # Obtener intervalo de configuración o usar default
    interval_ms = 
      Application.get_env(:rent_bot, :scheduler, [])
      |> Keyword.get(:interval_ms, 10 * 60_000)

    children = [
      RentBot.Repo,
      {RentBot.Scheduler, interval_ms: interval_ms}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: RentBot.Supervisor)
  end
end
