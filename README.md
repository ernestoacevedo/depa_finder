# RentBot 🏠🤖

A rental listing scraper bot that monitors PortalInmobiliario.com for apartments in specific Santiago neighborhoods and sends new listings to Telegram. Built with Elixir as a supervised OTP application with scheduled background jobs.

## Features

- 🔍 **Smart Scraping**: Fetches and parses JSON-LD structured data from PortalInmobiliario.com
- 🎯 **Intelligent Filtering**: Configurable filters for neighborhoods, price, area, and bedrooms
- 🚫 **Duplicate Prevention**: SHA256 fingerprint-based deduplication (handles price changes)
- 📱 **Telegram Integration**: Sends formatted messages with proper Markdown escaping
- ⚡ **Concurrent Processing**: Efficient parallel scraping with controlled concurrency
- 🔄 **Automated Scheduling**: Runs scraping cycles every 10 minutes
- 💾 **SQLite Storage**: Local persistence with Ecto migrations

## Architecture

### Core Components

- **Scheduler** (`RentBot.Scheduler`): GenServer that orchestrates scraping cycles
- **Scraper** (`RentBot.Scraper`): Fetches and parses property listings from multiple pages
- **Normalize** (`RentBot.Normalize`): Applies filters and generates fingerprints for deduplication
- **Store** (`RentBot.Store`): Persists new listings to SQLite database
- **Notifier** (`RentBot.Notifier`): Sends formatted messages to Telegram

### Data Flow

```
Scheduler → Scraper → Normalize → Store → Notifier
    ↓           ↓         ↓        ↓        ↓
  Every      Concurrent  Filter   SQLite  Telegram
10 minutes   Requests   & Hash   Storage  Messages
```

## Setup

### Prerequisites

- Elixir 1.17+
- SQLite3

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd depa_finder
```

2. Install dependencies:
```bash
mix deps.get
```

3. Create environment configuration:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```env
TG_BOT_TOKEN=your_telegram_bot_token
TG_CHAT_ID=your_telegram_chat_id
```

5. Set up the database:
```bash
mix ecto.migrate
```

## Configuration

Edit `config/config.exs` to customize your search filters:

```elixir
config :rent_bot, :filters,
  comunas: ["Providencia", "Las Condes"],  # Target neighborhoods
  precio_max: 1_100_000,                  # Maximum price in CLP
  min_m2: 60,                             # Minimum area in square meters
  min_dorms: 2                            # Minimum number of bedrooms
```

## Usage

### Run a Single Scraping Cycle

For testing or manual execution:

```bash
mix rent_bot.scrape
```

### Start the Continuous Bot

Runs the scheduler that scrapes every 10 minutes:

```bash
mix run --no-halt
```

### Database Operations

```bash
# Run migrations
mix ecto.migrate

# Reset database (⚠️ deletes all data)
mix ecto.reset
```

## Development

### Project Structure

```
lib/
├── rent_bot/
│   ├── application.ex    # OTP Application supervisor
│   ├── scheduler.ex      # Periodic scraping GenServer
│   ├── scraper.ex        # Web scraping logic
│   ├── normalize.ex      # Data filtering and fingerprinting
│   ├── store.ex          # Database operations
│   ├── notifier.ex       # Telegram notifications
│   ├── repo.ex           # Ecto repository
│   └── schema.ex         # Database schema
└── mix/
    └── tasks/
        └── rent_bot.scrape.ex  # Mix task for manual runs
```

### Key Design Patterns

#### Concurrent Scraping
```elixir
Task.async_stream(urls, &fetch_list/1, 
  timeout: 30_000, 
  max_concurrency: 4
)
```

#### Robust Data Extraction
All parsing functions handle `nil` gracefully:
```elixir
defp parse_int(nil), do: nil
defp parse_int(v) when is_integer(v), do: v
defp parse_int(v) when is_binary(v), do: String.to_integer(v)
```

#### Fingerprint-Based Deduplication
Uses SHA256 of `url|price|area` instead of just URL to handle price changes:
```elixir
fingerprint = :crypto.hash(:sha256, "#{url}|#{price}|#{area}")
```

### Testing

Run the test suite:
```bash
mix test
```

For integration testing, use the manual scrape command:
```bash
mix rent_bot.scrape
```

## Telegram Bot Setup

1. Create a new bot with [@BotFather](https://t.me/botfather)
2. Get your bot token
3. Start a chat with your bot and send a message
4. Get your chat ID using the Telegram Bot API:
   ```bash
   curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `TG_BOT_TOKEN` | Telegram bot token from BotFather | Yes |
| `TG_CHAT_ID` | Telegram chat ID where messages will be sent | Yes |

## Error Handling

- **Network failures**: Logged but don't crash the application
- **Parsing errors**: Gracefully handled with fallback values
- **Database errors**: Transactions ensure data consistency
- **Telegram API errors**: Logged with retry logic

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This bot is for educational and personal use only. Please respect PortalInmobiliario.com's terms of service and implement appropriate rate limiting. The authors are not responsible for any misuse of this software.

