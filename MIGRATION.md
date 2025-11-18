# Migration to Specification-Driven Monorepo

This guide helps migrate the existing Depa Finder Elixir application to a constitutional monorepo structure.

## Current State → Target State

### Current Structure
```
depa_finder/
├── lib/depa_finder/
│   ├── application.ex
│   ├── scheduler.ex
│   ├── scraper.ex
│   ├── normalize.ex
│   ├── store.ex
│   └── notifier.ex
├── test/
└── mix.exs
```

### Target Structure  
```
depa_finder/
├── .specify/                   # Spec-kit configuration
├── apps/
│   ├── api/                   # Elixir backend (Phoenix API)
│   │   ├── lib/depa_finder/   # Business libraries with CLI
│   │   └── test/              # Comprehensive test suite
│   └── web/                   # React frontend
└── package.json               # Workspace management
```

## Migration Steps

### 1. Backup and Prepare

```bash
# Create backup of current state
git checkout -b backup-pre-migration
git commit -am "Backup before monorepo migration"

# Create migration branch
git checkout -b feat/monorepo-migration
```

### 2. Move Existing Code (ALREADY DONE)

The existing Elixir code has been copied to `apps/api/`:
- `lib/` → `apps/api/lib/`
- `test/` → `apps/api/test/`  
- `mix.exs` → `apps/api/mix.exs`
- `config/` → `apps/api/config/`
- `priv/` → `apps/api/priv/`

### 3. Add CLI Interfaces (CONSTITUTIONAL REQUIREMENT)

Each library module must expose CLI functionality:

```elixir
# apps/api/lib/depa_finder/scraper.ex
defmodule DepaFinder.Scraper do
  # Existing business logic
  def fetch_listings(urls, opts \\ []) do
    # Current implementation
  end
  
  # NEW: Required CLI interface
  def main(args) do
    {opts, urls, []} = OptionParser.parse(args,
      strict: [format: :string, timeout: :integer]
    )
    
    case fetch_listings(urls, opts) do
      {:ok, listings} ->
        output = if opts[:format] == "json" do
          Jason.encode!(listings)
        else
          Enum.map_join(listings, "\n", &format_listing/1)
        end
        IO.puts(output)
        
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        System.halt(1)
    end
  end
  
  defp format_listing(listing) do
    "#{listing.title} - #{listing.price} - #{listing.url}"
  end
end
```

Apply this pattern to all modules:
- `DepaFinder.Normalize` - CLI for filtering and normalization
- `DepaFinder.Store` - CLI for database operations  
- `DepaFinder.Notifier` - CLI for sending notifications

### 4. Add Comprehensive Test Coverage

Follow constitutional test-first requirements:

```elixir
# apps/api/test/depa_finder/scraper_test.exs
defmodule DepaFinder.ScraperTest do
  use ExUnit.Case, async: true
  
  describe "fetch_listings/2" do
    test "returns listings for valid URLs" do
      # Unit test for business logic
    end
    
    test "handles network errors gracefully" do
      # Error handling tests
    end
  end
  
  describe "CLI interface" do
    test "main/1 outputs JSON format when requested" do
      # Test CLI functionality
    end
    
    test "main/1 handles invalid arguments" do
      # CLI error handling
    end
  end
end

# apps/api/test/contracts/scraper_contract_test.exs  
defmodule DepaFinder.ScraperContractTest do
  use ExUnit.Case, async: false
  
  test "integrates with real PortalInmobiliario API" do
    # Integration test with real external service
  end
end
```

### 5. Convert to Phoenix API

Transform the current OTP application into a Phoenix API:

```bash
cd apps/api
mix phx.new . --app depa_finder_web --no-html --no-assets --no-gettext --no-dashboard
```

Update `apps/api/lib/depa_finder_web/router.ex`:
```elixir
defmodule DepaFinderWeb.Router do
  use DepaFinderWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", DepaFinderWeb do
    pipe_through :api
    
    resources "/listings", ListingController, only: [:index, :show]
    post "/scrape", ScrapeController, :create
    resources "/notifications", NotificationController, only: [:create]
  end
end
```

### 6. Setup React Frontend

Frontend structure (already created):

```typescript
// apps/web/src/services/api.ts
export class ApiClient {
  private baseURL = import.meta.env.VITE_API_URL || 'http://localhost:4000'
  
  async fetchListings(params: ListingParams): Promise<Listing[]> {
    // API integration
  }
  
  // Required CLI interface for testing
  static async main(args: string[]): Promise<void> {
    const client = new ApiClient()
    const listings = await client.fetchListings({})
    console.log(JSON.stringify(listings, null, 2))
  }
}
```

### 7. Update Configuration

Update Phoenix configuration for API-only mode:

```elixir
# apps/api/config/config.exs
import Config

config :depa_finder_web, DepaFinderWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DepaFinderWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: DepaFinder.PubSub

# CORS for frontend development
config :cors_plug,
  origin: ["http://localhost:3000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
```

### 8. Database Migration Strategy

Keep existing SQLite for development, prepare for PostgreSQL:

```elixir
# apps/api/config/dev.exs
config :depa_finder, DepaFinder.Repo,
  database: Path.expand("../depa_finder_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# apps/api/config/prod.exs  
config :depa_finder, DepaFinder.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

### 9. Update CI/CD

The new GitHub Actions workflow (`.github/workflows/specs.yml`) provides:
- Constitutional compliance checking
- Matrix builds for both apps
- Quality gates and coverage reporting
- E2E testing with real services

### 10. Verification Steps

After migration, verify constitutional compliance:

```bash
# 1. Validate spec-kit configuration
speckit validate

# 2. Run constitutional compliance checks
npm run speckit:full

# 3. Test all CLI interfaces
cd apps/api
mix escript.build
./depa_finder scraper --help
./depa_finder normalize --help

# 4. Verify frontend builds and tests
cd apps/web
pnpm build
pnpm test

# 5. Run E2E scenarios  
npm run speckit:e2e
```

## Breaking Changes

### Environment Variables
- Move `.env` to `apps/api/.env` for backend-specific config
- Add `apps/web/.env` for frontend config (API URL, etc.)

### Database Location
- SQLite database moves from root to `apps/api/`
- Update any deployment scripts accordingly

### Deployment
- Update Docker configuration to build both apps
- Modify deployment scripts for monorepo structure

## Post-Migration Benefits

1. **Specification-Driven Development**: All changes start with specs
2. **Constitutional Compliance**: Architecture principles enforced automatically  
3. **Modern Frontend**: React interface for better user experience
4. **Improved Testing**: Comprehensive test coverage with real integrations
5. **Scalability**: Independent scaling of API and frontend
6. **Developer Experience**: Better tooling, faster feedback loops

## Rollback Plan

If issues arise:
```bash
# Return to pre-migration state
git checkout backup-pre-migration
git checkout -b hotfix/rollback-migration

# Or: Keep monorepo but run only backend
cd apps/api
mix phx.server
```

## Next Steps After Migration

1. **Create Specifications**: Use `/speckit.specify` to document existing features
2. **Add Missing Tests**: Achieve 80% coverage requirement
3. **Frontend Features**: Implement listing browser, search, notifications
4. **Performance**: Optimize API responses and frontend loading  
5. **Monitoring**: Add observability and alerting
6. **Documentation**: Update all docs for new structure

This migration preserves all existing functionality while establishing a foundation for specification-driven development and modern full-stack architecture.
