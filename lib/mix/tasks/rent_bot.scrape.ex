defmodule Mix.Tasks.RentBot.Scrape do
  use Mix.Task
  @shortdoc "Run a single scraping+store+notify cycle"
  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    with {:ok, listings} <- RentBot.Scraper.fetch_all(),
         {:ok, new} <- RentBot.Store.save_new(listings) do
      RentBot.Notifier.notify_many(new)
      IO.puts("✅ cycle ok — scraped=#{length(listings)} new=#{length(new)}")
    else
      err -> IO.puts("⚠️ #{inspect(err)}")
    end
  end
end
