defmodule RentBot.Scraper do
  @seeds [
    "https://www.portalinmobiliario.com/arriendo/departamento/providencia-metropolitana",
    "https://www.portalinmobiliario.com/arriendo/departamento/las-condes-metropolitana"
  ]
  @offsets [nil, 301, 601]
  def fetch_all do
    urls =
      for seed <- @seeds, off <- @offsets do
        if off, do: "#{seed}/_Desde_#{off}", else: seed
      end
    results =
      urls
      |> Task.async_stream(&fetch_list/1, timeout: 30_000, max_concurrency: 4)
      |> Enum.flat_map(fn
        {:ok, xs} when is_list(xs) -> xs
        _ -> []
      end)
    {:ok, Enum.uniq_by(results, & &1.url)}
  end
  defp fetch_list(url) do
    html = Req.get!(url, receive_timeout: 15_000).body
    extract_jsonld(html) |> from_jsonld_list()
  rescue
    _ -> []
  end
  defp extract_jsonld(html) do
    Floki.find(html, ~s(script[type="application/ld+json"]))
    |> Enum.map(fn node ->
      try do
        node |> Floki.text() |> Jason.decode!()
      rescue _ -> nil end
    end)
    |> Enum.flat_map(fn
      %{} = m -> [m]
      [_ | _] = l -> l
      _ -> []
    end)
  end
  defp from_jsonld_list(blocks) do
    blocks
    |> Enum.flat_map(fn blk ->
      case blk["@type"] do
        "ItemList" -> (blk["itemListElement"] || []) |> Enum.map(&pick_item/1)
        "SearchResultsPage" -> (blk["mainEntity"] || []) |> List.wrap() |> Enum.map(&pick_item/1)
        _ -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&RentBot.Normalize.enrich/1)
  end
  defp pick_item(el) do
    it = Map.get(el, "item", el)
    with url when is_binary(url) <- it["url"] || it["mainEntityOfPage"] do
      off = it["offers"] || %{}
      %{
        source: "portalinmobiliario",
        url: url,
        title: it["name"],
        price_clp: parse_int(off["price"] || off["lowPrice"]),
        currency: off["priceCurrency"],
        area_m2: parse_float(get_in(it, ["floorSize", "value"])),
        bedrooms: parse_int(it["numberOfRooms"] || it["numberOfBedrooms"]),
        bathrooms: parse_int(it["numberOfBathroomsTotal"]),
        address: get_in(it, ["address", "streetAddress"]) || get_in(it, ["address", "addressLocality"]),
        comuna: get_in(it, ["address", "addressLocality"]) || get_in(it, ["address", "addressRegion"]),
        published_at: parse_date(it["datePosted"] || it["datePublished"])
      }
    else _ -> nil end
  end
  defp parse_int(nil), do: nil
  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(String.replace(v, ~r/[\.\s]/, "")) do {n,_}->n; _->nil end
  end
  defp parse_float(nil), do: nil
  defp parse_float(v) when is_float(v), do: v
  defp parse_float(v) when is_binary(v) do
    case Float.parse(String.replace(v, ",", ".")) do {f,_}->f; _->nil end
  end
  defp parse_date(nil), do: nil
  defp parse_date(iso), do:
    case DateTime.from_iso8601(iso) do {:ok,dt,_}->dt; _->nil end
end
