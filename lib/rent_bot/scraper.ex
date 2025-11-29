defmodule RentBot.Scraper do
  @seeds [
    "https://www.portalinmobiliario.com/arriendo/departamento/providencia-metropolitana",
    "https://www.portalinmobiliario.com/arriendo/departamento/las-condes-metropolitana"
  ]
  @offsets [nil, 301, 601]
  @detail_timeout 15_000
  @detail_max_concurrency 4
  @req_headers [
    {"user-agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15"},
    {"accept-language", "es-CL,es;q=0.9,en-US;q=0.8,en;q=0.7"},
    {"accept",
     "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"}
  ]

  def fetch_all do
    urls =
      for seed <- @seeds, off <- @offsets do
        if off, do: "#{seed}/_Desde_#{off}", else: seed
      end

    uf_rate = RentBot.Currency.uf_rate()

    listings =
      urls
      |> Task.async_stream(&fetch_list/1, timeout: 30_000, max_concurrency: 4)
      |> Enum.flat_map(fn
        {:ok, xs} when is_list(xs) -> xs
        _ -> []
      end)
      |> Enum.map(&convert_currency(&1, uf_rate))
      |> Enum.map(&RentBot.Normalize.enrich/1)

    listings =
      listings
      |> Enum.uniq_by(& &1.url)
      |> attach_images()

    {:ok, listings}
  end

  defp fetch_list(url) do
    html = Req.get!(url, receive_timeout: 15_000, headers: @req_headers).body
    extract_items(html)
  rescue
    _ -> []
  end

  defp extract_items(html) do
    with {:ok, doc} <- Floki.parse_document(html) do
      extract_jsonld(doc) ++ extract_polycards(doc)
    else
      _ -> []
    end
  end

  defp extract_jsonld(doc) do
    doc
    |> Floki.find(~s(script[type="application/ld+json"]))
    |> Enum.map(fn node ->
      try do
        node |> Floki.text() |> Jason.decode!()
      rescue
        _ -> nil
      end
    end)
    |> Enum.flat_map(fn
      %{} = m -> [m]
      [_ | _] = list -> list
      _ -> []
    end)
    |> from_jsonld_list()
  end

  defp extract_polycards(doc) do
    doc
    |> Floki.find(~s(script#__PRELOADED_STATE__))
    |> Enum.flat_map(fn node ->
      node
      |> Floki.children()
      |> Enum.join()
      |> decode_preloaded_polycards()
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp decode_preloaded_polycards(""), do: []

  defp decode_preloaded_polycards(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json),
        results when is_list(results) <- get_in(data, ["pageState", "initialState", "results"]) do
      results |> Enum.flat_map(&polycard_block_items/1)
    else
      _ -> []
    end
  end

  defp decode_preloaded_polycards(_), do: []

  defp polycard_block_items(%{"polycard" => %{} = polycard} = block) do
    if block["state"] in [nil, "VISIBLE"] do
      case build_polycard_item(polycard) do
        nil -> []
        item -> [item]
      end
    else
      []
    end
  end

  defp polycard_block_items(_), do: []

  defp build_polycard_item(polycard) do
    components = Map.get(polycard, "components", [])
    metadata = Map.get(polycard, "metadata", %{})
    url = metadata |> Map.get("url") |> normalize_url()
    title = component_value(components, "title", ["title", "text"])
    price_info = component_value(components, "price", ["price", "current_price"]) || %{}

    attributes =
      component_value(components, "attributes_list", ["attributes_list", "texts"]) || []

    location_text = component_value(components, "location", ["location", "text"])
    {address, comuna} = split_location(location_text)
    %{bedrooms: bedrooms, bathrooms: bathrooms, area_m2: area_m2} = extract_attributes(attributes)
    currency = Map.get(price_info, "currency")
    price_value = Map.get(price_info, "value")

    with url when is_binary(url) <- url,
        title when is_binary(title) <- title do
      %{
        source: "portalinmobiliario",
        url: url,
        title: title,
        price_clp: parse_int(price_value),
        currency: currency,
        area_m2: area_m2,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        address: address,
        comuna: comuna,
        published_at: nil
      }
    else
      _ -> nil
    end
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
        address:
          get_in(it, ["address", "streetAddress"]) ||
            get_in(it, ["address", "addressLocality"]),
        comuna:
          get_in(it, ["address", "addressLocality"]) ||
            get_in(it, ["address", "addressRegion"]),
        published_at: parse_date(it["datePosted"] || it["datePublished"])
      }
    else
      _ -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_float(v), do: v |> Float.round() |> trunc()

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(String.replace(v, ~r/[\.\s]/, "")) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(v) when is_float(v), do: v

  defp parse_float(v) when is_binary(v) do
    case Float.parse(String.replace(v, ",", ".")) do
      {f, _} -> f
      _ -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp component_value(components, id, path) do
    components
    |> Enum.find_value(fn
      %{"id" => ^id} = component -> get_in(component, path)
      _ -> nil
    end)
  end

  defp extract_attributes(texts) do
    texts = List.wrap(texts)

    %{
      bedrooms: find_first_integer(texts, "dormitorio"),
      bathrooms: find_first_integer(texts, "baño"),
      area_m2: find_first_float(texts, ~r/m(?:2|\x{00B2})/iu)
    }
  end

  defp find_first_integer(texts, needle) do
    find_match(texts, needle, ~r/\d+/, &parse_int/1)
  end

  defp find_first_float(texts, matcher) do
    find_match(texts, matcher, ~r/\d+(?:[.,]\d+)?/, &parse_float/1)
  end

  defp find_match(texts, matcher, regex, parser) do
    texts
    |> Enum.find_value(fn
      text when is_binary(text) ->
        if matches?(text, matcher) do
          case Regex.run(regex, text) do
            [match | _] -> parser.(match)
            _ -> nil
          end
        end

      _ ->
        nil
    end)
  end

  defp matches?(text, matcher) when is_binary(matcher) do
    String.contains?(String.downcase(text), matcher)
  end

  defp matches?(text, %Regex{} = matcher), do: Regex.match?(matcher, text)
  defp matches?(_, _), do: false

  defp split_location(nil), do: {nil, nil}

  defp split_location(text) when is_binary(text) do
    parts =
      text
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case parts do
      [] ->
        {nil, nil}

      [single] ->
        {nil, single}

      _ ->
        comuna = List.last(parts)

        address =
          parts
          |> Enum.drop(-1)
          |> Enum.join(", ")

        address =
          case String.trim(address) do
            "" -> nil
            value -> value
          end

        {address, comuna}
    end
  end

  defp normalize_url(nil), do: nil

  defp normalize_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      trimmed == "" -> nil
      String.contains?(trimmed, "://") -> trimmed
      String.starts_with?(trimmed, "//") -> "https:" <> trimmed
      String.starts_with?(trimmed, "/") -> "https://www.portalinmobiliario.com" <> trimmed
      true -> "https://" <> trimmed
    end
  end

  defp attach_images(listings) do
    results =
      listings
      |> Task.async_stream(&maybe_attach_image/1,
        timeout: @detail_timeout,
        max_concurrency: @detail_max_concurrency
      )
      |> Enum.to_list()

    listings
    |> Enum.zip(results)
    |> Enum.map(fn
      {_original, {:ok, enriched}} -> enriched
      {original, _} -> original
    end)
  end

  defp maybe_attach_image(%{image_url: url} = listing) when is_binary(url) and url != "" do
    listing
  end

  defp maybe_attach_image(%{url: url} = listing) when is_binary(url) do
    case fetch_listing_image(url) do
      nil -> listing
      image_url -> Map.put(listing, :image_url, image_url)
    end
  end

  defp maybe_attach_image(listing), do: listing

  defp fetch_listing_image(url) do
    case Req.get(url, receive_timeout: @detail_timeout, headers: @req_headers) do
      {:ok, %{body: body}} -> extract_image_from_html(body)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp extract_image_from_html(body) do
    with {:ok, doc} <- Floki.parse_document(body) do
      extract_image_from_preloaded_state(doc) ||
        extract_image_from_gallery_mosaic(doc)
    else
      _ -> nil
    end
  end

  defp extract_image_from_preloaded_state(doc) do
    with [node | _] <- Floki.find(doc, ~s(script#__PRELOADED_STATE__)),
         json when is_binary(json) <- node |> Floki.children() |> Enum.join(),
         {:ok, data} <- Jason.decode(json) do
      data
      |> get_in(["pageState", "initialState", "components", "gallery"])
      |> build_image_from_gallery()
    else
      _ -> nil
    end
  end

  defp build_image_from_gallery(%{"pictures" => [picture | _]} = gallery) do
    template =
      get_in(gallery, ["picture_config", "template_zoom"]) ||
        get_in(gallery, ["picture_config", "template"]) ||
        get_in(gallery, ["picture_config", "template_thumbnail"])

    fill_gallery_template(template, picture)
  end

  defp build_image_from_gallery(_), do: nil

  defp fill_gallery_template(nil, _), do: nil

  defp fill_gallery_template(template, %{"id" => id} = picture) when is_binary(id) do
    sanitized = Map.get(picture, "sanitized_title") || ""

    template
    |> String.replace("{id}", id)
    |> String.replace("{sanitizedTitle}", sanitized)
  end

  defp fill_gallery_template(_, _), do: nil

  defp extract_image_from_gallery_mosaic(doc) do
    doc
    |> Floki.find("#gallery_mosaic img, .gallery_mosaic img, .gallery-mosaic img")
    |> Enum.find_value(&image_from_img_node/1)
  end

  defp image_from_img_node(node) do
    ["data-src", "data-srcset", "src"]
    |> Enum.find_value(fn attr ->
      node
      |> Floki.attribute(attr)
      |> List.first()
      |> pick_from_srcset()
    end)
  end

  defp pick_from_srcset(nil), do: nil

  defp pick_from_srcset(srcset) do
    srcset
    |> String.split(",", parts: 2)
    |> hd()
    |> String.trim()
    |> String.split(" ", parts: 2)
    |> hd()
    |> normalize_url()
  rescue
    _ -> nil
  end

  defp convert_currency(%{currency: currency} = item, uf_rate) do
    case normalize_currency(currency) do
      nil ->
        item

      normalized when normalized in ["CLF", "UF"] ->
        price = Map.get(item, :price_clp)

        converted_price =
          if is_number(price) and is_number(uf_rate) do
            round(price * uf_rate)
          else
            price
          end

        item
        |> Map.put(:currency, "CLP")
        |> Map.put(:price_clp, converted_price)

      _ ->
        item
    end
  end

  defp convert_currency(item, _uf_rate), do: item

  defp normalize_currency(currency) when is_binary(currency), do: String.upcase(currency)
  defp normalize_currency(_), do: nil
end
