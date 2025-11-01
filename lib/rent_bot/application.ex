defmodule RentBot.Application do
  use Application
  def start(_t, _a) do
    children = [
      RentBot.Repo,
      {RentBot.Scheduler, interval_ms: 10 * 60_000}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: RentBot.Supervisor)
  end
end
