# Depa Finder - Specification-Driven Monorepo

A rental listing scraper with Elixir backend and React frontend, built following Specification-Driven Development (SDD) principles.

## Architecture

This is a monorepo containing:

- **`apps/api`** - Elixir/Phoenix API backend
- **`apps/web`** - React/TypeScript frontend

## Constitutional Foundation

This project follows a [constitutional approach](.specify/memory/constitution.md) to development with these core principles:

1. **Specification-First**: Specs are the source of truth, code serves specifications
2. **Library-First**: All features begin as standalone libraries with CLI interfaces  
3. **Test-First**: Strict TDD - tests written → approved → fail → implement
4. **Monorepo Harmony**: Consistent tooling across apps, shared libraries when appropriate
5. **Integration-First Testing**: Test in realistic environments, not artificial ones

## Quick Start

### Prerequisites

- Elixir 1.17+ and OTP 26+
- Node.js 18+ 
- PostgreSQL 15+
- pnpm 8+ (or npm/yarn - configurable)

### Setup

```bash
# Clone and setup
git clone <repo>
cd depa_finder

# Setup backend
cd apps/api
mix deps.get
mix ecto.setup

# Setup frontend (choose your package manager)
cd ../web
pnpm install        # preferred
# OR: npm install
# OR: yarn install

# Return to root
cd ../..
```

### Development

```bash
# Run both apps in development
npm run dev

# Or run individually
npm run dev:api     # Start Elixir API on port 4000
npm run dev:web     # Start React app on port 3000
```

## Specification-Driven Workflow

### Creating New Features

```bash
# 1. Create feature specification
/speckit.specify "Real-time listing notifications via WebSocket"

# 2. Generate implementation plan  
/speckit.plan "Phoenix Channels for WebSocket, Redis for pub/sub"

# 3. Create executable tasks
/speckit.tasks

# 4. Implement following TDD principles
```

### Running Specifications

```bash
# Quick feedback - unit tests only
npm run speckit:fast

# Backend specifications  
npm run speckit:api

# Frontend specifications
npm run speckit:web

# Complete test suite
npm run speckit:full

# End-to-end scenarios
npm run speckit:e2e
```

### Using Spec-Kit Directly

```bash
# Validate configuration
speckit validate

# Run specific drivers
speckit run --driver elixir_api
speckit run --driver react_web

# Run with tags
speckit run --tags unit
speckit run --tags integration
speckit run --tags e2e
```

## Project Structure

```
depa_finder/
├── .specify/                    # Spec-kit configuration
│   ├── memory/
│   │   ├── constitution.md      # Core principles and rules
│   │   └── guidance.md          # Practical development guidance
│   ├── templates/               # Code generation templates
│   └── speckit.yml             # Spec-kit configuration
├── .github/
│   └── workflows/
│       └── specs.yml           # CI/CD with constitutional compliance
├── apps/
│   ├── api/                    # Elixir backend
│   │   ├── lib/
│   │   │   ├── depa_finder/    # Business logic libraries (with CLI)
│   │   │   └── depa_finder_web/ # Phoenix web layer
│   │   ├── test/
│   │   │   ├── contracts/      # API contract tests
│   │   │   └── e2e/           # Backend E2E tests
│   │   └── mix.exs
│   └── web/                   # React frontend  
│       ├── src/
│       │   ├── components/    # Reusable UI components
│       │   ├── services/      # API integration libraries
│       │   ├── hooks/         # Custom React hooks
│       │   └── e2e/          # Frontend E2E tests
│       ├── package.json
│       └── vite.config.ts
└── package.json               # Workspace configuration
```

## Constitutional Requirements

### Every Library Must Have CLI Interface

```elixir
# Backend libraries (apps/api/lib/depa_finder/*)
defmodule DepaFinder.Scraper do
  def scrape_listings(source, opts \\ []), do: # implementation
  
  # Required CLI interface
  def main(args) do
    # Parse args and call scrape_listings/2
  end
end
```

```typescript
// Frontend services (apps/web/src/services/*)
export class ListingsService {
  async fetchListings(params: FetchParams): Promise<Listing[]> {
    // Implementation
  }
  
  // Required CLI interface for testing
  static async main(args: string[]): Promise<void> {
    // Parse args and call fetchListings
  }
}
```

### Test-First Implementation

```bash
# 1. Write failing test
cd apps/api
mix test test/depa_finder/scraper_test.exs

# 2. Implement to make test pass
# Edit lib/depa_finder/scraper.ex

# 3. Refactor while keeping tests green
```

### Quality Gates

All changes must pass:

- **Constitutional compliance** - Architecture principles enforced
- **Test coverage** - Minimum 80% across both apps
- **Performance** - Tests complete within time limits
- **Integration** - Real database and service testing

## Package Manager Configuration

The project defaults to `pnpm` but can easily switch:

```bash
# Switch to npm
sed -i 's/pnpm/npm/g' package.json apps/web/package.json

# Switch to yarn  
sed -i 's/pnpm/yarn/g' package.json apps/web/package.json
```

## Deployment

```bash
# Build production assets
npm run build

# Docker deployment
docker-compose up -d
```

## Contributing

1. **Follow the Constitution** - All contributions must comply with [constitutional principles](.specify/memory/constitution.md)
2. **Specification-First** - Create specs before implementation
3. **Test-Driven** - Write failing tests before any code
4. **Library-First** - Implement as standalone libraries with CLI interfaces

See [Development Guidance](.specify/memory/guidance.md) for detailed implementation patterns and examples.

## License

[Add your license here]
