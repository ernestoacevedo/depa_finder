defmodule RentBot.Scheduler do
  use GenServer
  require Logger
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def init(opts) do
    Process.send_after(self(), :tick, 1_000)
    {:ok, %{interval: Keyword.fetch!(opts, :interval_ms)}}
  end
  def handle_info(:tick, state) do
    Task.start(fn -> run_cycle() end)
    Process.send_after(self(), :tick, state.interval)
    {:noreply, state}
  end
  defp run_cycle do
    with {:ok, listings} <- RentBot.Scraper.fetch_all(),
         {:ok, new} <- RentBot.Store.save_new(listings) do
      RentBot.Notifier.notify_many(new)
      Logger.info("Cycle: #{length(listings)} scraped, #{length(new)} new")
    end
  end
end
