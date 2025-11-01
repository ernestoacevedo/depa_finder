defmodule RentBot.Normalize do
  @filters Application.compile_env(:rent_bot, :filters)
  def enrich(map) do
    fp = :crypto.hash(:sha256, "#{map.url}|#{map.price_clp}|#{map.area_m2}") |> Base.encode16(case: :lower)
    map |> Map.put(:fingerprint, fp) |> Map.put(:passes_filters, passes?(map))
  end
  defp passes?(m) do
    Enum.member?(@filters[:comunas], m.comuna || "") and
    (is_nil(@filters[:precio_max]) or (m.price_clp || 0) <= @filters[:precio_max]) and
    (is_nil(@filters[:min_m2]) or (m.area_m2 || 0.0) >= @filters[:min_m2]) and
    (is_nil(@filters[:min_dorms]) or (m.bedrooms || 0) >= @filters[:min_dorms])
  end
end
