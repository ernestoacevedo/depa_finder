defmodule RentBot.Repo.Migrations.Init do
  use Ecto.Migration
  def change do
    create table(:listings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :text, null: false
      add :url, :text, null: false
      add :title, :text
      add :price_clp, :integer
      add :currency, :text
      add :area_m2, :float
      add :bedrooms, :integer
      add :bathrooms, :integer
      add :address, :text
      add :comuna, :text
      add :published_at, :utc_datetime
      add :fingerprint, :text, null: false
      add :inserted_at, :utc_datetime, null: false
    end
    create unique_index(:listings, [:url])
    create unique_index(:listings, [:fingerprint])
    create index(:listings, [:comuna])
    create index(:listings, [:price_clp])
  end
end
