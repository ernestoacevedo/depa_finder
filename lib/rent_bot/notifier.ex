defmodule RentBot.Notifier do
  require Logger
  @tg Application.compile_env(:rent_bot, :telegram)
  def notify_many([]), do: :ok
  def notify_many(list), do: Enum.each(list, &notify/1)
  defp notify(m) do
    msg = """
    🏠 *#{escape(m.title || "Depto")}*
    📍 #{m.comuna || m.address || "—"}
    💵 #{fmt(m.price_clp, m.currency)}
    🧱 ~#{m.area_m2 || "?"} m² • 🛏 #{m.bedrooms || "?"} • 🛁 #{m.bathrooms || "?"}
    🔗 #{m.url}
    """
    url = "https://api.telegram.org/bot#{@tg[:bot_token]}/sendMessage"
    Req.post(url, json: %{chat_id: @tg[:chat_id], text: msg, parse_mode: "Markdown"})
  rescue
    e -> Logger.error("Telegram failed: #{inspect(e)}")
  end
  defp fmt(nil, _), do: "—"
  defp fmt(p, cur), do: "#{cur || "CLP"} #{p}"
  defp escape(s), do: String.replace(s, ~r/([_*[\]()~`>#+\-=|{}.!])/, "\\\\\\1")
end
