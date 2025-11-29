defmodule RentBotWeb.ListingJSON do
  alias RentBot.Listing

  def index(%{listings: listings}) do
    %{data: Enum.map(listings, &listing/1)}
  end

  defp listing(%Listing{} = listing) do
    %{
      id: listing.id,
      source: listing.source,
      url: listing.url,
      title: listing.title,
      price_clp: listing.price_clp,
      currency: listing.currency,
      area_m2: listing.area_m2,
      bedrooms: listing.bedrooms,
      bathrooms: listing.bathrooms,
      address: listing.address,
      comuna: listing.comuna,
      image_url: listing.image_url,
      published_at: format_datetime(listing.published_at),
      inserted_at: format_datetime(listing.inserted_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
end
