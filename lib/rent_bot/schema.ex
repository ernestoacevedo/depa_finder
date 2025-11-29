defmodule RentBot.Listing do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "listings" do
    field :source, :string
    field :url, :string
    field :title, :string
    field :price_clp, :integer
    field :currency, :string
    field :area_m2, :float
    field :bedrooms, :integer
    field :bathrooms, :integer
    field :address, :string
    field :comuna, :string
    field :image_url, :string
    field :published_at, :utc_datetime
    field :fingerprint, :string
    timestamps(updated_at: false)
  end
  def changeset(l, attrs) do
    l
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:source, :url, :fingerprint])
    |> unique_constraint(:url)
    |> unique_constraint(:fingerprint)
  end
end
