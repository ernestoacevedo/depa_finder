defmodule RentBotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :rent_bot

  @session_options [
    store: :cookie,
    key: "_rent_bot_key",
    signing_salt: {Application, :get_env, [:rent_bot, :signing_salt]}
  ]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug CORSPlug,
    origin: ["http://localhost:5173"],
    allow_headers: ["content-type", "authorization"],
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug RentBotWeb.Router
end
