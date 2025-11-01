defmodule RentBot.Store do
  import Ecto.Query, only: [from: 2]
  alias RentBot.{Repo, Listing}
  def save_new(listings) do
    new =
      listings
      |> Enum.filter(& Map.get(&1, :passes_filters, true))
      |> Enum.map(&Map.drop(&1, [:passes_filters]))
      |> Enum.reject(&exists?/1)
      |> Enum.map(&insert!/1)
    {:ok, new}
  end
  defp exists?(%{fingerprint: fp}) do
    from(l in Listing, where: l.fingerprint == ^fp) |> Repo.exists?()
  end
  defp insert!(attrs), do: %Listing{} |> Listing.changeset(attrs) |> Repo.insert!()
end
