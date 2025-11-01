# Copilot Instructions for RentBot

## Architecture Overview

This is a **rental listing scraper bot** that monitors PortalInmobiliario.com for apartments in specific Santiago neighborhoods and sends new listings to Telegram. The app runs as a supervised OTP application with a scheduled background job.

### Core Components

- **Scheduler** (`lib/rent_bot/scheduler.ex`): GenServer that runs scraping cycles every 10 minutes
- **Scraper** (`lib/rent_bot/scraper.ex`): Fetches and parses JSON-LD structured data from PortalInmobiliario
- **Normalize** (`lib/rent_bot/normalize.ex`): Applies filters and generates fingerprints for deduplication
- **Store** (`lib/rent_bot/store.ex`): Persists new listings to SQLite, preventing duplicates
- **Notifier** (`lib/rent_bot/notifier.ex`): Sends formatted messages to Telegram with proper Markdown escaping

### Data Flow

1. Scheduler triggers scraping cycle
2. Scraper fetches multiple paginated URLs concurrently (`Task.async_stream`)
3. Parses JSON-LD blocks from HTML using Floki
4. Normalize adds fingerprints (SHA256 of url|price|area) and applies filters
5. Store saves only new listings (fingerprint-based deduplication)
6. Notifier sends Telegram messages for new listings only

## Key Patterns

### Concurrent Scraping
```elixir
# Uses Task.async_stream with timeout and max_concurrency
Task.async_stream(&fetch_list/1, timeout: 30_000, max_concurrency: 4)
```

### Robust Data Extraction
All parsing functions handle `nil` gracefully and use pattern matching:
```elixir
defp parse_int(nil), do: nil
defp parse_int(v) when is_integer(v), do: v
# Always include fallback patterns
```

### Configuration-Driven Filtering
Filters are compile-time config in `config/config.exs`:
```elixir
config :rent_bot, :filters,
  comunas: ["Providencia", "Las Condes"],
  precio_max: 1_100_000, min_m2: 60, min_dorms: 2
```

### Telegram Message Formatting
Messages use Markdown with proper escaping for special characters. The `escape/1` function handles all Telegram Markdown special chars.

## Development Workflows

### Manual Testing
```bash
# Run a single scrape cycle manually
mix rent_bot.scrape

# Start the app (runs continuous scheduling)
mix run --no-halt
```

### Environment Setup
Requires `.env` file in project root:
```
TG_BOT_TOKEN=your_telegram_bot_token
TG_CHAT_ID=your_telegram_chat_id
```

### Database Operations
```bash
# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset
```

## Important Conventions

- **Error Handling**: All network operations use `rescue` blocks, log errors but don't crash
- **Deduplication**: Uses SHA256 fingerprints of `url|price|area` instead of just URL (handles price changes)
- **Filtering**: Applied at normalize stage with `passes_filters` field before storage
- **Concurrency**: Limited to 4 concurrent requests to be respectful to target site
- **Data Structure**: All listings are maps with consistent field names, `nil` for missing data

## External Dependencies

- **PortalInmobiliario.com**: Target scraping site - parses JSON-LD structured data
- **Telegram Bot API**: Notification delivery via HTTP POST to `/sendMessage`
- **SQLite**: Local persistence via Ecto with custom migrations in `priv/repo/migrations/`

## Testing

Basic ExUnit setup. Tests are minimal - focus on integration testing via `mix rent_bot.scrape`.
