defmodule RentBotWeb.ListingController do
  use RentBotWeb, :controller

  import Ecto.Query, only: [from: 2]
  alias RentBot.{Listing, Repo}

  def index(conn, _params) do
    listings =
      from(l in Listing, order_by: [desc: l.inserted_at])
      |> Repo.all()

    render(conn, :index, listings: listings)
  end
end
