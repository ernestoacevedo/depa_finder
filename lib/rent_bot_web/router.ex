defmodule RentBotWeb.Router do
  use RentBotWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", RentBotWeb do
    pipe_through :api

    get "/listings", ListingController, :index
  end
end
