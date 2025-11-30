defmodule RentBot.Scraper do
  require Logger

  @seeds [
    "https://www.portalinmobiliario.com/arriendo/departamento/providencia-metropolitana",
    "https://www.portalinmobiliario.com/arriendo/departamento/las-condes-metropolitana"
  ]
  @offsets [nil, 301, 601]
  @toctoc_seeds [
    # Providencia
    "https://www.toctoc.com/resultados/mapa/arriendo/departamento/metropolitana/providencia/?moneda=1&precioDesde=700000&precioHasta=900000&dormitoriosDesde=2&dormitoriosHasta=&banosDesde=2&banosHasta=5&estado=0&disponibilidadEntrega=&numeroDeDiasTocToc=0&superficieDesdeUtil=0&superficieHastaUtil=0&superficieDesdeConstruida=0&superficieHastaConstruida=0&superficieDesdeTerraza=0&superficieHastaTerraza=0&superficieDesdeTerreno=0&superficieHastaTerreno=0&ordenarPor=0&pagina=1&paginaInterna=1&zoom=15&idZonaHomogenea=0&atributos=&texto=Providencia&viewport=-33.450583873234905,-70.63624806359637,-33.40842530599939,-70.58223131372333&idPoligono=47&publicador=0&temporalidad=0",
    # Las Condes
    "https://www.toctoc.com/resultados/mapa/arriendo/departamento/metropolitana/las-condes/?moneda=1&precioDesde=700000&precioHasta=900000&dormitoriosDesde=2&dormitoriosHasta=&banosDesde=2&banosHasta=5&estado=0&disponibilidadEntrega=&numeroDeDiasTocToc=0&superficieDesdeUtil=0&superficieHastaUtil=0&superficieDesdeConstruida=0&superficieHastaConstruida=0&superficieDesdeTerraza=0&superficieHastaTerraza=0&superficieDesdeTerreno=0&superficieHastaTerreno=0&ordenarPor=0&pagina=1&paginaInterna=1&zoom=15&idZonaHomogenea=0&atributos=&texto=Las%20Condes&viewport=-33.43,-70.58,-33.38,-70.50&publicador=0&temporalidad=0"
  ]
  @toctoc_pages 1..3
  @detail_timeout 15_000
  @detail_max_concurrency 4
  @base_headers [
    {"user-agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15"},
    {"accept-language", "es-CL,es;q=0.9,en-US;q=0.8,en;q=0.7"},
    {"accept",
     "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"},
    {"accept-encoding", "gzip, deflate"}
  ]

  @toctoc_headers [
    {"user-agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15"},
    {"accept-language", "es-CL,es;q=0.9,en-US;q=0.8,en;q=0.7"},
    {"accept",
     "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"}
  ]

  def fetch_all do
    uf_rate = RentBot.Currency.uf_rate()

    portal_listings = fetch_portal_listings()
    toctoc_listings = fetch_toctoc_listings()

    Logger.info(
      "Scraper fetched: portal=#{length(portal_listings)} toctoc=#{length(toctoc_listings)} (raw)"
    )

    listings =
      (portal_listings ++ toctoc_listings)
      |> Enum.map(&convert_currency(&1, uf_rate))
      |> Enum.map(&RentBot.Normalize.enrich/1)

    listings =
      listings
      |> Enum.uniq_by(& &1.url)
      |> attach_images()

    Logger.info("Scraper total after dedupe: #{length(listings)}")

    {:ok, listings}
  end

  defp fetch_portal_listings do
    urls =
      for seed <- @seeds, off <- @offsets do
        if off, do: "#{seed}/_Desde_#{off}", else: seed
      end

    urls
    |> Task.async_stream(&fetch_list/1, timeout: 30_000, max_concurrency: 4)
    |> Enum.flat_map(fn
      {:ok, xs} when is_list(xs) -> xs
      _ -> []
    end)
  end

  defp fetch_toctoc_listings do
    urls =
      for seed <- @toctoc_seeds, page <- @toctoc_pages do
        toctoc_page_url(seed, page)
      end

    urls
    |> Task.async_stream(fn url -> {url, fetch_toctoc_page(url)} end,
      timeout: 30_000,
      max_concurrency: 3
    )
    |> Enum.flat_map(fn
      {:ok, {url, xs}} when is_list(xs) ->
        Logger.info("TocToc: #{length(xs)} items from #{url}")
        xs

      _ -> []
    end)
  end

  defp toctoc_page_url(seed_url, page) do
    uri = URI.parse(seed_url)

    query =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.put("pagina", Integer.to_string(page))
      |> Map.put("paginaInterna", Integer.to_string(page))

    uri
    |> Map.put(:query, URI.encode_query(query))
    |> URI.to_string()
  end

  defp fetch_list(url) do
    case Req.get(url, receive_timeout: 15_000, headers: req_headers(url)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        if verification_wall?(body) do
          maybe_log_cookie_hint(url)
          []
        else
          extract_items(body)
        end

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Unexpected status #{status} when fetching #{url}")
        []

      {:error, reason} ->
        Logger.warning("Request error for #{url}: #{inspect(reason)}")
        []
    end
  end

  defp fetch_toctoc_page(url) do
    # TocToc now uses an API endpoint instead of embedding data in HTML
    # Extract parameters from the URL to build the API request
    case extract_toctoc_params(url) do
      {:ok, params} ->
        fetch_toctoc_api(params)

      :error ->
        Logger.warning("Could not extract parameters from TocToc URL: #{url}")
        []
    end
  end

  defp extract_toctoc_params(url) do
    uri = URI.parse(url)
    query_params = URI.decode_query(uri.query || "")

    path_parts = String.split(uri.path || "", "/", trim: true)
    tipo_vista = Enum.at(path_parts, 1) || "mapa"
    operacion_slug = Enum.at(path_parts, 2)
    tipo_propiedad = Enum.at(path_parts, 3)
    region = Enum.at(path_parts, 4) || "metropolitana"
    comuna = Enum.at(path_parts, 5)

    with true <- is_binary(comuna) do
      pagina = parse_int(query_params["pagina"]) || 1

      atributos =
        case query_params["atributos"] do
          "" -> []
          nil -> []
          values when is_binary(values) ->
            values
            |> String.split(",", trim: true)
            |> Enum.map(&parse_int/1)
            |> Enum.reject(&is_nil/1)
          _ -> []
        end

      {:ok,
       %{
         page_url: url,
         region: region,
         comuna: comuna,
         barrio: query_params["barrio"] || "",
         poi: query_params["poi"] || "",
         tipoVista: tipo_vista,
         operacion: parse_operacion(operacion_slug),
         idPoligono: parse_int(query_params["idPoligono"]) || 0,
         moneda: parse_int(query_params["moneda"]) || 1,
         precioDesde: parse_int(query_params["precioDesde"]) || 0,
         precioHasta: parse_int(query_params["precioHasta"]) || 0,
         dormitoriosDesde: parse_int(query_params["dormitoriosDesde"]) || 0,
         dormitoriosHasta: parse_int(query_params["dormitoriosHasta"]) || 0,
         banosDesde: parse_int(query_params["banosDesde"]) || 0,
         banosHasta: parse_int(query_params["banosHasta"]) || 0,
         tipoPropiedad: tipo_propiedad || "departamento",
         estado: parse_int(query_params["estado"]) || 0,
         disponibilidadEntrega: query_params["disponibilidadEntrega"] || "",
         numeroDeDiasTocToc: parse_int(query_params["numeroDeDiasTocToc"]) || 0,
         superficieDesdeUtil: parse_int(query_params["superficieDesdeUtil"]) || 0,
         superficieHastaUtil: parse_int(query_params["superficieHastaUtil"]) || 0,
         superficieDesdeConstruida: parse_int(query_params["superficieDesdeConstruida"]) || 0,
         superficieHastaConstruida: parse_int(query_params["superficieHastaConstruida"]) || 0,
         superficieDesdeTerraza: parse_int(query_params["superficieDesdeTerraza"]) || 0,
         superficieHastaTerraza: parse_int(query_params["superficieHastaTerraza"]) || 0,
         superficieDesdeTerreno: parse_int(query_params["superficieDesdeTerreno"]) || 0,
         superficieHastaTerreno: parse_int(query_params["superficieHastaTerreno"]) || 0,
         ordenarPor: parse_int(query_params["ordenarPor"]) || 0,
         pagina: pagina,
         paginaInterna: parse_int(query_params["paginaInterna"]) || pagina,
         zoom: parse_int(query_params["zoom"]) || 0,
         idZonaHomogenea: parse_int(query_params["idZonaHomogenea"]) || 0,
         busqueda: (query_params["texto"] || query_params["busqueda"]) |> decode_search(comuna),
         viewport: query_params["viewport"],
         atributos: atributos,
         publicador: parse_int(query_params["publicador"]) || 0,
         temporalidad: parse_int(query_params["temporalidad"]) || 0,
         limite: parse_int(query_params["limite"]) || 510,
         cargaBanner: true,
         primeraCarga: pagina == 1,
         santander: parse_boolean(query_params["santander"]) || false
       }}
    else
      _ -> :error
    end
  end

  defp fetch_toctoc_api(params) do
    url = "https://www.toctoc.com/api/mapa/GetProps"

    base_headers = [
      {"accept", "application/json"},
      {"content-type", "application/json"},
      {"user-agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"},
      {"origin", "https://www.toctoc.com"},
      {"referer", Map.get(params, :page_url) || "https://www.toctoc.com/"}
    ]

    headers =
      base_headers
      |> maybe_put_header("x-access-token", System.get_env("TOCTOC_ACCESS_TOKEN"))
      |> maybe_put_header("cookie", toctoc_cookie())

    body = Map.drop(params, [:page_url])

    case Req.post(url, json: body, headers: headers, receive_timeout: 20_000) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        extract_toctoc_api_items(body, params.comuna)

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, data} -> extract_toctoc_api_items(data, params.comuna)
          _ -> []
        end

      {:ok, %Req.Response{status: 403}} ->
        Logger.warning(
          "TocToc API returned 403 Forbidden for comuna #{params.comuna}. Configure TOCTOC_ACCESS_TOKEN and TOCTOC_COOKIE."
        )

        []

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("TocToc API returned status #{status} for comuna #{params.comuna}")
        []

      {:error, reason} ->
        Logger.warning("TocToc API request error: #{inspect(reason)}")
        []
    end
  end

  defp extract_toctoc_api_items(data, comuna) when is_map(data) do
    # The API returns data in the "resultados" key (Spanish for "results")
    listings =
      data["props"] || data["Props"] || data["resultados"] || data["propiedades"] ||
        data["properties"] || data["items"] || data["results"] || data["Propiedades"] || []

    items =
      listings
      |> List.wrap()
      |> Enum.map(&build_toctoc_api_item(&1, comuna))
      |> Enum.reject(&is_nil/1)

    Logger.info("TocToc API: extracted #{length(items)} items for #{comuna}")
    items
  end

  defp extract_toctoc_api_items(_, _), do: []

  defp build_toctoc_api_item(prop, fallback_comuna) when is_map(prop) do
    # Extract ID and build URL
    id = prop["id"] || prop["Id"] || prop["idPropiedad"]
    url = if id, do: "https://www.toctoc.com/propiedad/#{id}", else: nil

    # Extract basic info
    title = prop["titulo"] || prop["title"] || prop["Titulo"]
    precio = prop["precio"] || prop["Precio"] || prop["price"]
    moneda = prop["moneda"] || prop["Moneda"] || prop["currency"]

    # Extract property details
    dormitorios = prop["dormitorios"] || prop["Dormitorios"] || prop["bedrooms"]
    banos = prop["banos"] || prop["Banos"] || prop["bathrooms"]
    superficie = prop["superficie"] || prop["Superficie"] || prop["area"]

    # Extract location
    comuna = prop["comuna"] || prop["Comuna"] || fallback_comuna
    direccion = prop["direccion"] || prop["Direccion"] || prop["address"]

    # Extract image
    imagen = prop["imagen"] || prop["Imagen"] || prop["image"] || prop["foto"]

    with url when is_binary(url) <- url,
         title when is_binary(title) <- title do
      item = %{
        source: "toctoc",
        url: url,
        title: title,
        price_clp: parse_int(precio),
        currency: normalize_currency_code(moneda),
        area_m2: parse_float(superficie),
        bedrooms: parse_int(dormitorios),
        bathrooms: parse_int(banos),
        address: direccion,
        comuna: comuna,
        image_url: normalize_url(imagen),
        published_at: nil
      }

      if validate_toctoc_item(item) do
        item
      else
        Logger.debug("TocToc API item rejected (insufficient data): #{url}")
        nil
      end
    else
      _ -> nil
    end
  end

  defp build_toctoc_api_item(_, _), do: nil

  defp normalize_currency_code(code) when is_binary(code) do
    case String.upcase(code) do
      "CLP" -> "CLP"
      "UF" -> "UF"
      "CLF" -> "UF"
      "USD" -> "USD"
      "$" -> "CLP"
      _ -> code
    end
  end

  defp normalize_currency_code(code) when is_integer(code) do
    case code do
      1 -> "UF"
      2 -> "CLP"
      3 -> "USD"
      _ -> nil
    end
  end

  defp normalize_currency_code(_), do: nil

  defp extract_items(html) do
    with {:ok, doc} <- Floki.parse_document(html) do
      extract_jsonld(doc) ++ extract_polycards(doc)
    else
      _ -> []
    end
  end

  defp extract_jsonld(doc, source \\ "portalinmobiliario") do
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
    |> from_jsonld_list(source)
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

  defp extract_toctoc_items(html) do
    with {:ok, doc} <- Floki.parse_document(html) do
      next_items = extract_toctoc_next(doc)
      jsonld_items = extract_jsonld(doc, "toctoc")
      attr_items = extract_toctoc_data_attrs(doc)

      Logger.debug(
        "TocToc extraction: next=#{length(next_items)} jsonld=#{length(jsonld_items)} attrs=#{length(attr_items)}"
      )

      next_items ++ jsonld_items ++ attr_items
    else
      _ -> []
    end
  end

  defp extract_toctoc_data_attrs(doc) do
    links_by_id = toctoc_links_by_id(doc)

    doc
    |> Floki.find("img.imgslide[data-id-propiedad]")
    |> Enum.map(&build_toctoc_attr_item(&1, links_by_id))
    |> Enum.reject(&is_nil/1)
  end

  defp toctoc_links_by_id(doc) do
    doc
    |> Floki.find("a")
    |> Enum.reduce(%{}, fn node, acc ->
      href = attr(node, "href")
      id = attr(node, "data-id-propiedad") || extract_id_from_href(href)

      if is_binary(id) and is_binary(href) do
        Map.put_new(acc, id, normalize_url(href, "www.toctoc.com"))
      else
        acc
      end
    end)
  end

  defp extract_toctoc_next(doc) do
    doc
    |> Floki.find(~s(script#__NEXT_DATA__))
    |> Enum.flat_map(fn node ->
      node
      |> Floki.children()
      |> Enum.join()
      |> decode_toctoc_next()
    end)
  end

  defp decode_toctoc_next("") do
    []
  end

  defp decode_toctoc_next(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json) do
      data
      |> find_toctoc_blocks()
      |> Enum.flat_map(fn block ->
        block
        |> Enum.map(&build_toctoc_item/1)
        |> Enum.reject(&is_nil/1)
      end)
    else
      _ -> []
    end
  end

  defp decode_toctoc_next(_), do: []

  defp build_toctoc_attr_item({_tag, attrs, _} = node, links_by_id) do
    attr_map = Map.new(attrs)
    id = attr_map["data-id-propiedad"]

    url =
      Map.get(links_by_id, id) ||
        build_toctoc_url(id)

    title = attr(node, "alt") || attr_map["data-termino-busqueda"] || attr_map["data-lista"]

    bedrooms =
      pick_first_number(attr_map, ["data-dormitorios1", "data-dormitorios2"], &parse_int/1)

    bathrooms = pick_first_number(attr_map, ["data-banos1", "data-banos2"], &parse_int/1)

    area_m2 =
      pick_first_number(attr_map, ["data-superficie2", "data-superficie1"], &parse_float/1)

    price_value =
      first_present_attr(attr_map, [
        "data-precio",
        "data-precio-valor",
        "data-precio-clp",
        "data-precio-uf"
      ])

    currency =
      attr_map["data-precio-moneda"]
      |> currency_from_symbol()

    image_url = attr(node, "src")
    comuna = attr_map["data-comuna"]

    with url when is_binary(url) <- url,
         title when is_binary(title) <- title do
      item = %{
        source: "toctoc",
        url: url,
        title: title,
        price_clp: parse_int(price_value),
        currency: currency,
        area_m2: area_m2,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        address: nil,
        comuna: comuna,
        image_url: normalize_url(image_url)
      }

      # Validate minimum data quality
      if validate_toctoc_item(item) do
        item
      else
        Logger.debug("TocToc item rejected (insufficient data): #{url}")
        nil
      end
    else
      _ -> nil
    end
  end

  defp build_toctoc_attr_item(_, _), do: nil

  defp find_toctoc_blocks(value) when is_list(value) do
    candidate =
      case value do
        [%{} | _] -> [value]
        _ -> []
      end

    candidate ++ Enum.flat_map(value, &find_toctoc_blocks/1)
  end

  defp find_toctoc_blocks(value) when is_map(value) do
    explicit =
      ["listings", "items", "properties", "results", "data"]
      |> Enum.flat_map(fn key ->
        case Map.get(value, key) do
          list when is_list(list) -> [list]
          _ -> []
        end
      end)

    explicit ++ (value |> Map.values() |> Enum.flat_map(&find_toctoc_blocks/1))
  end

  defp find_toctoc_blocks(_), do: []

  defp currency_from_symbol(symbol) do
    case symbol do
      "$" -> "CLP"
      "UF" -> "UF"
      "US$" -> "USD"
      _ -> symbol
    end
  end

  defp pick_first_number(map, keys, parser) do
    map
    |> first_present_attr(keys)
    |> parser.()
  end

  defp first_present_attr(map, keys) do
    Enum.find_value(keys, fn key ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  defp build_toctoc_item(%{} = listing) do
    url = first_present(listing, ["url", "permalink", "Url", "Permalink", "Link", "link"])
    image_url = first_present(listing, ["image", "image_url", "ImageUrl", "photo", "PictureUrl"])

    title =
      first_present(listing, ["title", "Title", "headline", "SeoTitle", "seo_title", "name"]) ||
        first_present(listing, ["Address"])

    price_value =
      first_present(listing, ["price", "Price", "price_clp", "Precio", "PrecioUf", "PrecioClp"])

    currency =
      first_present(listing, ["currency", "Currency", "Moneda", "CurrencyCode", "currency_code"]) ||
        detect_currency_from_price(price_value)

    area_m2 = first_present(listing, ["Surface", "surface", "superficie", "Area", "area"])
    bedrooms = first_present(listing, ["Dormitorios", "dormitorios", "Bedrooms", "bedrooms"])
    bathrooms = first_present(listing, ["Banos", "BanosCantidad", "Bathrooms", "bathrooms"])

    comuna =
      first_present(listing, [
        "Comuna",
        "comuna",
        "Commune",
        "CommuneName",
        "District",
        "district"
      ])

    address =
      first_present(listing, [
        "Direccion",
        "direccion",
        "address",
        "Address",
        "street",
        "street_name"
      ])

    published_at =
      first_present(listing, ["PublishDate", "publish_date", "published_at", "fechaPublicacion"])

    with url when is_binary(url) <- normalize_url(url, "www.toctoc.com"),
         title when is_binary(title) <- title do
      item = %{
        source: "toctoc",
        url: url,
        title: title,
        price_clp: parse_int(price_value),
        currency: currency,
        area_m2: parse_float(area_m2),
        bedrooms: parse_int(bedrooms),
        bathrooms: parse_int(bathrooms),
        address: address,
        comuna: comuna,
        image_url: normalize_url(image_url),
        published_at: parse_date(published_at)
      }

      # Validate minimum data quality
      if validate_toctoc_item(item) do
        item
      else
        Logger.debug("TocToc item rejected (insufficient data): #{url}")
        nil
      end
    else
      _ -> nil
    end
  end

  defp build_toctoc_item(_), do: nil

  # Validates that a TocToc item has minimum required data quality
  defp validate_toctoc_item(%{url: url, title: title} = item)
       when is_binary(url) and is_binary(title) do
    # Item must have at least one of: price, area, or bedrooms
    has_price = is_number(item[:price_clp]) and item[:price_clp] > 0
    has_area = is_number(item[:area_m2]) and item[:area_m2] > 0
    has_bedrooms = is_number(item[:bedrooms]) and item[:bedrooms] > 0

    has_price or has_area or has_bedrooms
  end

  defp validate_toctoc_item(_), do: false

  defp first_present(map, keys) do
    keys
    |> Enum.find_value(fn key ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  defp attr(node, name) do
    node
    |> Floki.attribute(name)
    |> List.first()
  end

  defp extract_id_from_href(href) when is_binary(href) do
    case Regex.run(~r/(\d{6,})/, href) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp extract_id_from_href(_), do: nil

  defp build_toctoc_url(id) when is_binary(id) do
    "https://www.toctoc.com/propiedad/" <> id
  end

  defp build_toctoc_url(_), do: nil

  defp detect_currency_from_price(value) when is_binary(value) do
    cond do
      String.contains?(value, "UF") -> "UF"
      String.contains?(value, "Uf") -> "UF"
      String.contains?(value, "$") -> "CLP"
      true -> nil
    end
  end

  defp detect_currency_from_price(_), do: nil

  defp from_jsonld_list(blocks, source) do
    blocks
    |> Enum.flat_map(fn blk ->
      case blk["@type"] do
        "ItemList" ->
          (blk["itemListElement"] || []) |> Enum.map(&pick_item(&1, source))

        "SearchResultsPage" ->
          (blk["mainEntity"] || []) |> List.wrap() |> Enum.map(&pick_item(&1, source))

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp pick_item(el, source) do
    it = Map.get(el, "item", el)

    with url when is_binary(url) <- it["url"] || it["mainEntityOfPage"] do
      off = it["offers"] || %{}

      %{
        source: source,
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

  defp parse_operacion("venta"), do: 1
  defp parse_operacion("arriendo"), do: 2
  defp parse_operacion(_), do: 0

  defp parse_boolean(v) when v in [true, false], do: v

  defp parse_boolean(v) when is_binary(v) do
    case String.downcase(v) do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      _ -> nil
    end
  end

  defp parse_boolean(_), do: nil

  defp decode_search(nil, comuna), do: humanize_slug(comuna)
  defp decode_search("", comuna), do: humanize_slug(comuna)

  defp decode_search(text, _comuna) when is_binary(text) do
    text
    |> URI.decode_www_form()
    |> String.trim()
  end

  defp humanize_slug(nil), do: nil

  defp humanize_slug(slug) do
    slug
    |> URI.decode_www_form()
    |> String.replace("-", " ")
    |> String.trim()
    |> String.split(" ", trim: true)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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
      bathrooms: find_first_integer(texts, ~r/bañ|bano|bath/i),
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

  defp normalize_url(url, base_host \\ "www.portalinmobiliario.com")
  defp normalize_url(nil, _base_host), do: nil

  defp normalize_url(url, base_host) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      trimmed == "" -> nil
      String.contains?(trimmed, "://") -> trimmed
      String.starts_with?(trimmed, "//") -> "https:" <> trimmed
      String.starts_with?(trimmed, "/") -> "https://#{base_host}" <> trimmed
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
    case Req.get(url, receive_timeout: @detail_timeout, headers: req_headers(url)) do
      {:ok, %{body: body}} -> extract_image_from_html(body)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp extract_image_from_html(body) do
    with false <- verification_wall?(body),
         {:ok, doc} <- Floki.parse_document(body) do
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

  defp maybe_put_header(headers, _key, value) when value in [nil, ""], do: headers
  defp maybe_put_header(headers, key, value), do: [{key, value} | headers]

  defp toctoc_cookie do
    System.get_env("TOCTOC_COOKIE")
  end

  defp req_headers(url \\ nil) do
    headers =
      case runtime_cookie() do
        cookie when is_binary(cookie) and cookie != "" ->
          [{"cookie", cookie} | @base_headers]

        _ ->
          @base_headers
      end

    if is_binary(url) do
      [{"referer", "https://www.portalinmobiliario.com/"} | headers]
    else
      headers
    end
  end

  defp toctoc_headers(_url) do
    @toctoc_headers
  end

  defp verification_wall?(body) when is_binary(body) do
    String.contains?(body, "account-verification") or String.contains?(body, "captcha")
  end

  defp verification_wall?(_), do: false

  defp runtime_cookie do
    System.get_env("PORTALINMOBILIARIO_COOKIE") ||
      :rent_bot
      |> Application.get_env(:http, [])
      |> Keyword.get(:cookie)
  end

  defp maybe_log_cookie_hint(url) do
    if runtime_cookie() in [nil, ""] do
      Logger.warning(
        "Blocked by account verification when fetching #{url} (no session cookie configured)"
      )
    else
      Logger.warning(
        "Blocked by account verification when fetching #{url} even with provided cookie"
      )
    end
  end
end
