defmodule RentBot.Notifier do
  require Logger
  def notify_many([]), do: :ok
  def notify_many(list) do
    tg = telegram_config()
    Enum.each(list, &notify(&1, tg))
  end
  defp notify(m, tg) do
    msg = """
    🏠 *#{escape(m.title || "Depto")}*
    📍 #{m.comuna || m.address || "—"}
    💵 #{fmt(m.price_clp, m.currency)}
    🧱 ~#{m.area_m2 || "?"} m² • 🛏 #{m.bedrooms || "?"} • 🛁 #{m.bathrooms || "?"}
    🔗 #{m.url}
    """
    payload = %{chat_id: Keyword.fetch!(tg, :chat_id), text: msg, parse_mode: "Markdown"}
    Logger.debug(fn ->
      "Sending Telegram notification title=#{inspect(m.title || "Depto")} chat_id=#{payload.chat_id} msg_size=#{byte_size(msg)}"
    end)
    url = "https://api.telegram.org/bot#{Keyword.fetch!(tg, :bot_token)}/sendMessage"
    response = Req.post(url, json: payload)
    log_response(response)
    response
  rescue
    e -> Logger.error("Telegram failed: #{inspect(e)}")
  end
  defp fmt(nil, _), do: "—"
  defp fmt(p, cur), do: "#{cur || "CLP"} #{p}"
  defp escape(s), do: String.replace(s, ~r/([_*[\]()~`>#+\-=|{}.!])/, "\\\\\\1")
  defp log_response({:ok, %Req.Response{} = resp}) do
    Logger.debug(fn ->
      "Telegram response status=#{resp.status} body=#{inspect(resp.body)}"
    end)
  end
  defp log_response({:error, error}) do
    Logger.error("Telegram request error: #{inspect(error)}")
  end
  defp log_response(other) do
    Logger.warning("Telegram unexpected response payload: #{inspect(other)}")
  end
  defp telegram_config do
    Application.fetch_env!(:rent_bot, :telegram)
  end
end
