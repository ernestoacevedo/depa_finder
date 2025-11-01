defmodule RentBot.Currency do
  @moduledoc false

  @uf_api_url "https://www.mindicador.cl/api/uf/"
  @uf_placeholder 40_000

  @spec uf_rate() :: number()
  def uf_rate do
    case fetch_uf_rate() do
      {:ok, rate} -> rate
      {:error, _} -> @uf_placeholder
    end
  end

  defp fetch_uf_rate do
    with {:ok, %Req.Response{status: 200, body: body}} <- Req.get(@uf_api_url, receive_timeout: 5_000),
         {:ok, decoded} <- decode_body(body),
         rate when is_number(rate) <- extract_today_or_latest(decoded) do
      {:ok, rate}
    else
      _ -> {:error, :unavailable}
    end
  end

  defp decode_body(%{} = body), do: {:ok, body}

  defp decode_body(body) when is_binary(body) do
    Jason.decode(body)
  end

  defp decode_body(_), do: {:error, :invalid_body}

  defp extract_today_or_latest(%{"serie" => serie}) when is_list(serie) do
    today = Date.utc_today()

    serie
    |> Enum.map(&normalize_entry/1)
    |> Enum.reject(&is_nil/1)
    |> pick_value(today)
  end

  defp extract_today_or_latest(_), do: nil

  defp normalize_entry(%{"fecha" => fecha, "valor" => valor}) do
    with {:ok, datetime, _} <- DateTime.from_iso8601(fecha),
         true <- is_number(valor) do
      {DateTime.to_date(datetime), valor}
    else
      _ -> nil
    end
  end

  defp normalize_entry(_), do: nil

  defp pick_value([], _today), do: nil

  defp pick_value(entries, today) do
    case Enum.find(entries, fn {date, _value} -> date == today end) do
      {_date, value} -> value
      nil -> pick_most_recent(entries)
    end
  end

  defp pick_most_recent(entries) do
    entries
    |> Enum.max_by(fn {date, _value} -> date end, fn -> nil end)
    |> case do
      {_date, value} -> value
      nil -> nil
    end
  end
end
