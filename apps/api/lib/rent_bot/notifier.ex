defmodule RentBot.Notifier do
  require Logger
  def notify_many([]), do: :ok
  def notify_many(list) do
    tg = telegram_config()
    Enum.each(list, &notify(&1, tg))
  end
  defp notify(m, tg) do
    msg = render_message(m)
    payload = %{chat_id: Keyword.fetch!(tg, :chat_id), text: msg, parse_mode: "MarkdownV2"}
    Logger.debug(fn -> "Telegram payload body=#{inspect(payload)}" end)
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
  defp render_message(m) do
    [
      "🏠 *#{escape(m.title || "Depto")}*",
      "📍 #{escape(location_text(m))}",
      "💵 #{escape(fmt(m.price_clp, m.currency))}",
      "🧱 \\~#{escape(display_value(m.area_m2))} m² • 🛏 #{escape(display_value(m.bedrooms))} • 🛁 #{escape(display_value(m.bathrooms))}",
      link_line(m.url)
    ]
    |> Enum.join("\n")
  end
  defp fmt(nil, _), do: "—"
  defp fmt(p, cur), do: "#{cur || "CLP"} #{p}"
  defp location_text(m), do: m.comuna || m.address || "—"
  defp display_value(nil), do: "?"
  defp display_value(value) when is_binary(value), do: value
  defp display_value(value), do: to_string(value)
  defp display_url(nil), do: "—"
  defp display_url(url) when is_binary(url), do: String.trim(url)
  defp display_url(_), do: "—"
  defp link_line(url) do
    case display_url(url) do
      "—" ->
        "🔗 —"

      display ->
        label = escape(display)
        target = escape_link_target(display)
        "🔗 [#{label}](#{target})"
    end
  end
  defp escape_link_target(url) do
    url
    |> String.replace("\\", "\\\\")
    |> String.replace(")", "\\)")
    |> String.replace("(", "\\(")
  end
  defp escape(nil), do: nil
  defp escape(value) when not is_binary(value), do: value |> to_string() |> escape()
  defp escape(value) do
    String.replace(value, ~r/([_*[\]()~`>#+\-=|{}.!\\])/, "\\\\\\1")
  end
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
