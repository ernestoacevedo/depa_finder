#!/usr/bin/env bash
# macOS setup: asdf + Erlang/Elixir + proyecto rent_bot
set -euo pipefail

APP=depa_finder
ERLANG_V=27.1.2
ELIXIR_V=1.17.3-otp-27

# brew update
# brew install autoconf wxwidgets fop git openssl@3 sqlite

# echo "🔧 asdf + plugins…"
# if ! command -v asdf >/dev/null 2>&1; then
#   echo "asdf no encontrado. Instálalo desde https://asdf-vm.com/ e intenta de nuevo."
#   exit 1
# fi
# asdf plugin add erlang  || true
# asdf plugin add elixir  || true

# # Erlang en macOS requiere apuntar a OpenSSL de Homebrew
# export KERL_CONFIGURE_OPTIONS="--with-ssl=$(brew --prefix openssl@3)"
# # Evita compilar jinterface si no tienes Java; comenta si lo necesitas
# export KERL_CONFIGURE_OPTIONS="$KERL_CONFIGURE_OPTIONS --without-javac"

# asdf install erlang "$ERLANG_V"
# asdf install elixir "$ELIXIR_V"

# mkdir -p "$APP" && cd "$APP"
# # echo "erlang $ERLANG_V"  > .tool-versions
# # echo "elixir $ELIXIR_V" >> .tool-versions

# echo "🚀 Creando proyecto OTP…"
# mix new . --sup >/dev/null

# cat > mix.exs <<'EOF'
# defmodule RentBot.MixProject do
#   use Mix.Project
#   def project, do: [
#     app: :rent_bot,
#     version: "0.1.0",
#     elixir: "~> 1.17",
#     start_permanent: Mix.env() == :prod,
#     deps: deps()
#   ]
#   def application, do: [
#     extra_applications: [:logger, :inets, :ssl],
#     mod: {RentBot.Application, []}
#   ]
#   defp deps, do: [
#     {:req, "~> 0.5"},
#     {:floki, "~> 0.36"},
#     {:jason, "~> 1.4"},
#     {:ecto, "~> 3.11"},
#     {:ecto_sql, "~> 3.11"},
#     {:ecto_sqlite3, "~> 0.18"}
#   ]
# end
# EOF

# mkdir -p config priv/repo/migrations lib/rent_bot lib/mix/tasks

# cat > config/config.exs <<'EOF'
# import Config
# config :rent_bot, RentBot.Repo, database: "rent_bot.sqlite3", pool_size: 5
# config :rent_bot, :filters,
#   comunas: ["Providencia", "Las Condes"],
#   precio_max: 900_000, min_m2: 40, min_dorms: 1
# config :rent_bot, :telegram,
#   bot_token: System.get_env("TG_BOT_TOKEN"),
#   chat_id: System.get_env("TG_CHAT_ID")
# EOF

# cat > lib/rent_bot/repo.ex <<'EOF'
# defmodule RentBot.Repo do
#   use Ecto.Repo, otp_app: :rent_bot, adapter: Ecto.Adapters.SQLite3
# end
# EOF

# cat > lib/rent_bot/application.ex <<'EOF'
# defmodule RentBot.Application do
#   use Application
#   def start(_t, _a) do
#     children = [
#       RentBot.Repo,
#       {RentBot.Scheduler, interval_ms: 10 * 60_000}
#     ]
#     Supervisor.start_link(children, strategy: :one_for_one, name: RentBot.Supervisor)
#   end
# end
# EOF

# cat > lib/rent_bot/schema.ex <<'EOF'
# defmodule RentBot.Listing do
#   use Ecto.Schema
#   import Ecto.Changeset
#   @primary_key {:id, :binary_id, autogenerate: true}
#   schema "listings" do
#     field :source, :string
#     field :url, :string
#     field :title, :string
#     field :price_clp, :integer
#     field :currency, :string
#     field :area_m2, :float
#     field :bedrooms, :integer
#     field :bathrooms, :integer
#     field :address, :string
#     field :comuna, :string
#     field :published_at, :utc_datetime
#     field :fingerprint, :string
#     timestamps(updated_at: false)
#   end
#   def changeset(l, attrs) do
#     l
#     |> cast(attrs, __schema__(:fields))
#     |> validate_required([:source, :url, :fingerprint])
#     |> unique_constraint(:url)
#     |> unique_constraint(:fingerprint)
#   end
# end
# EOF

# cat > lib/rent_bot/store.ex <<'EOF'
# defmodule RentBot.Store do
#   import Ecto.Query, only: [from: 2]
#   alias RentBot.{Repo, Listing}
#   def save_new(listings) do
#     new =
#       listings
#       |> Enum.filter(& Map.get(&1, :passes_filters, true))
#       |> Enum.map(&Map.drop(&1, [:passes_filters]))
#       |> Enum.reject(&exists?/1)
#       |> Enum.map(&insert!/1)
#     {:ok, new}
#   end
#   defp exists?(%{fingerprint: fp}) do
#     from(l in Listing, where: l.fingerprint == ^fp) |> Repo.exists?()
#   end
#   defp insert!(attrs), do: %Listing{} |> Listing.changeset(attrs) |> Repo.insert!()
# end
# EOF

# cat > lib/rent_bot/scheduler.ex <<'EOF'
# defmodule RentBot.Scheduler do
#   use GenServer
#   require Logger
#   def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
#   def init(opts) do
#     Process.send_after(self(), :tick, 1_000)
#     {:ok, %{interval: Keyword.fetch!(opts, :interval_ms)}}
#   end
#   def handle_info(:tick, state) do
#     Task.start(fn -> run_cycle() end)
#     Process.send_after(self(), :tick, state.interval)
#     {:noreply, state}
#   end
#   defp run_cycle do
#     with {:ok, listings} <- RentBot.Scraper.fetch_all(),
#          {:ok, new} <- RentBot.Store.save_new(listings) do
#       RentBot.Notifier.notify_many(new)
#       Logger.info("Cycle: #{length(listings)} scraped, #{length(new)} new")
#     end
#   end
# end
# EOF

# cat > lib/rent_bot/scraper.ex <<'EOF'
# defmodule RentBot.Scraper do
#   @seeds [
#     "https://www.portalinmobiliario.com/arriendo/departamento/providencia-metropolitana",
#     "https://www.portalinmobiliario.com/arriendo/departamento/las-condes-metropolitana"
#   ]
#   @offsets [nil, 301, 601]
#   def fetch_all do
#     urls =
#       for seed <- @seeds, off <- @offsets do
#         if off, do: "#{seed}/_Desde_#{off}", else: seed
#       end
#     results =
#       urls
#       |> Task.async_stream(&fetch_list/1, timeout: 30_000, max_concurrency: 4)
#       |> Enum.flat_map(fn
#         {:ok, xs} when is_list(xs) -> xs
#         _ -> []
#       end)
#     {:ok, Enum.uniq_by(results, & &1.url)}
#   end
#   defp fetch_list(url) do
#     html = Req.get!(url, receive_timeout: 15_000).body
#     extract_jsonld(html) |> from_jsonld_list()
#   rescue
#     _ -> []
#   end
#   defp extract_jsonld(html) do
#     Floki.find(html, ~s(script[type="application/ld+json"]))
#     |> Enum.map(fn node ->
#       try do
#         node |> Floki.text() |> Jason.decode!()
#       rescue _ -> nil end
#     end)
#     |> Enum.flat_map(fn
#       %{} = m -> [m]
#       [_ | _] = l -> l
#       _ -> []
#     end)
#   end
#   defp from_jsonld_list(blocks) do
#     blocks
#     |> Enum.flat_map(fn blk ->
#       case blk["@type"] do
#         "ItemList" -> (blk["itemListElement"] || []) |> Enum.map(&pick_item/1)
#         "SearchResultsPage" -> (blk["mainEntity"] || []) |> List.wrap() |> Enum.map(&pick_item/1)
#         _ -> []
#       end
#     end)
#     |> Enum.reject(&is_nil/1)
#     |> Enum.map(&RentBot.Normalize.enrich/1)
#   end
#   defp pick_item(el) do
#     it = Map.get(el, "item", el)
#     with url when is_binary(url) <- it["url"] || it["mainEntityOfPage"] do
#       off = it["offers"] || %{}
#       %{
#         source: "portalinmobiliario",
#         url: url,
#         title: it["name"],
#         price_clp: parse_int(off["price"] || off["lowPrice"]),
#         currency: off["priceCurrency"],
#         area_m2: parse_float(get_in(it, ["floorSize", "value"])),
#         bedrooms: parse_int(it["numberOfRooms"] || it["numberOfBedrooms"]),
#         bathrooms: parse_int(it["numberOfBathroomsTotal"]),
#         address: get_in(it, ["address", "streetAddress"]) || get_in(it, ["address", "addressLocality"]),
#         comuna: get_in(it, ["address", "addressLocality"]) || get_in(it, ["address", "addressRegion"]),
#         published_at: parse_date(it["datePosted"] || it["datePublished"])
#       }
#     else _ -> nil end
#   end
#   defp parse_int(nil), do: nil
#   defp parse_int(v) when is_integer(v), do: v
#   defp parse_int(v) when is_binary(v) do
#     case Integer.parse(String.replace(v, ~r/[\.\s]/, "")) do {n,_}->n; _->nil end
#   end
#   defp parse_float(nil), do: nil
#   defp parse_float(v) when is_float(v), do: v
#   defp parse_float(v) when is_binary(v) do
#     case Float.parse(String.replace(v, ",", ".")) do {f,_}->f; _->nil end
#   end
#   defp parse_date(nil), do: nil
#   defp parse_date(iso), do:
#     case DateTime.from_iso8601(iso) do {:ok,dt,_}->dt; _->nil end
# end
# EOF

# cat > lib/rent_bot/normalize.ex <<'EOF'
# defmodule RentBot.Normalize do
#   @filters Application.compile_env(:rent_bot, :filters)
#   def enrich(map) do
#     fp = :crypto.hash(:sha256, "#{map.url}|#{map.price_clp}|#{map.area_m2}") |> Base.encode16(case: :lower)
#     map |> Map.put(:fingerprint, fp) |> Map.put(:passes_filters, passes?(map))
#   end
#   defp passes?(m) do
#     Enum.member?(@filters[:comunas], m.comuna || "") and
#     (is_nil(@filters[:precio_max]) or (m.price_clp || 0) <= @filters[:precio_max]) and
#     (is_nil(@filters[:min_m2]) or (m.area_m2 || 0.0) >= @filters[:min_m2]) and
#     (is_nil(@filters[:min_dorms]) or (m.bedrooms || 0) >= @filters[:min_dorms])
#   end
# end
# EOF

# cat > lib/rent_bot/notifier.ex <<'EOF'
# defmodule RentBot.Notifier do
#   require Logger
#   @tg Application.compile_env(:rent_bot, :telegram)
#   def notify_many([]), do: :ok
#   def notify_many(list), do: Enum.each(list, &notify/1)
#   defp notify(m) do
#     msg = """
#     🏠 *#{escape(m.title || "Depto")}*
#     📍 #{m.comuna || m.address || "—"}
#     💵 #{fmt(m.price_clp, m.currency)}
#     🧱 ~#{m.area_m2 || "?"} m² • 🛏 #{m.bedrooms || "?"} • 🛁 #{m.bathrooms || "?"}
#     🔗 #{m.url}
#     """
#     url = "https://api.telegram.org/bot#{@tg[:bot_token]}/sendMessage"
#     Req.post(url, json: %{chat_id: @tg[:chat_id], text: msg, parse_mode: "Markdown"})
#   rescue
#     e -> Logger.error("Telegram failed: #{inspect(e)}")
#   end
#   defp fmt(nil, _), do: "—"
#   defp fmt(p, cur), do: "#{cur || "CLP"} #{p}"
#   defp escape(s), do: String.replace(s, ~r/([_*[\]()~`>#+\-=|{}.!])/, "\\\\\\1")
# end
# EOF

# cat > priv/repo/migrations/0001_init.exs <<'EOF'
# defmodule RentBot.Repo.Migrations.Init do
#   use Ecto.Migration
#   def change do
#     create table(:listings, primary_key: false) do
#       add :id, :binary_id, primary_key: true
#       add :source, :text, null: false
#       add :url, :text, null: false
#       add :title, :text
#       add :price_clp, :integer
#       add :currency, :text
#       add :area_m2, :float
#       add :bedrooms, :integer
#       add :bathrooms, :integer
#       add :address, :text
#       add :comuna, :text
#       add :published_at, :utc_datetime
#       add :fingerprint, :text, null: false
#       add :inserted_at, :utc_datetime, null: false
#     end
#     create unique_index(:listings, [:url])
#     create unique_index(:listings, [:fingerprint])
#     create index(:listings, [:comuna])
#     create index(:listings, [:price_clp])
#   end
# end
# EOF

# cat > lib/mix/tasks/rent_bot.scrape.ex <<'EOF'
# defmodule Mix.Tasks.RentBot.Scrape do
#   use Mix.Task
#   @shortdoc "Run a single scraping+store+notify cycle"
#   @impl true
#   def run(_args) do
#     Mix.Task.run("app.start")
#     with {:ok, listings} <- RentBot.Scraper.fetch_all(),
#          {:ok, new} <- RentBot.Store.save_new(listings) do
#       RentBot.Notifier.notify_many(new)
#       IO.puts("✅ cycle ok — scraped=#{length(listings)} new=#{length(new)}")
#     else
#       err -> IO.puts("⚠️ #{inspect(err)}")
#     end
#   end
# end
# EOF

# cat > .gitignore <<'EOF'
# /_build
# /deps
# *.sqlite3
# /db
# .env
# ENV
# .erlang.cookie
# .coverage
# EOF

echo "📦 Instalando deps + DB…"
mix do local.hex --force, local.rebar --force, deps.get
mix ecto.create
mix ecto.migrate

cp -n .env.example .env 2>/dev/null || true || true
cat > .env.example <<'EOF'
TG_BOT_TOKEN=123456:ABC-DEF_your_token
TG_CHAT_ID=123456789
EOF

git init >/dev/null
git add .
git commit -m "feat: initial Elixir rent_bot (macOS setup)" >/dev/null

echo "✅ Listo en $(pwd)"
echo "Edita .env y ejecuta: mix rent_bot.scrape"
