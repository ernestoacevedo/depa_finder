defmodule RentBot.Repo.Migrations.AddImageUrlToListings do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :image_url, :text
    end
  end
end
