# Development Guidance for Depa Finder

This document provides practical guidance for implementing the constitutional principles in day-to-day development.

## Getting Started with Spec-Driven Development

### 1. New Feature Workflow

```bash
# 1. Create feature specification
/speckit.specify "Real-time listing notifications via WebSocket"

# This creates:
# - New branch: 001-realtime-notifications  
# - specs/001-realtime-notifications/spec.md
# - Proper directory structure

# 2. Generate implementation plan
/speckit.plan "Phoenix Channels for WebSocket, Redis for pub/sub, React hooks for client state"

# 3. Create executable tasks
/speckit.tasks

# 4. Begin implementation following TDD
```

### 2. Running Specs

```bash
# Fast feedback (unit tests only)
speckit run fast_specs

# Backend only
speckit run api_specs

# Frontend only  
speckit run web_specs

# Full test suite
speckit run full_specs

# Comprehensive E2E (nightly)
speckit run slow_specs
```

### 3. Monorepo Navigation

```bash
# Work on API
cd apps/api
mix test

# Work on frontend
cd apps/web  
pnpm test

# Run from root (uses spec-kit drivers)
speckit run --driver elixir_api
speckit run --driver react_web
```

## Constitutional Implementation Guide

### Library-First Development

**Correct Approach:**
```elixir
# 1. Create library first
defmodule DepaFinder.Notifications do
  @moduledoc """
  Notification delivery library with CLI interface.
  """
  
  def deliver(message, recipient, opts \\ []) do
    # Implementation
  end
  
  # CLI interface (required by constitution)
  def main(args) do
    # Parse args and call deliver/3
  end
end

# 2. Then integrate into application
defmodule DepaFinderWeb.NotificationController do
  def create(conn, params) do
    DepaFinder.Notifications.deliver(params["message"], params["recipient"])
    # Handle response
  end
end
```

**Incorrect Approach:**
```elixir
# Don't implement directly in controller
defmodule DepaFinderWeb.NotificationController do
  def create(conn, params) do
    # Business logic directly in controller - VIOLATES CONSTITUTION
    send_notification(params)
  end
end
```

### Test-First Implementation (NON-NEGOTIABLE)

**Required Workflow:**
```elixir
# 1. Write failing test first
defmodule DepaFinder.NotificationsTest do
  test "delivers notification successfully" do
    # This test MUST fail initially
    assert {:ok, _} = Notifications.deliver("message", "user@example.com")
  end
end

# 2. Run test - verify it fails (Red)
mix test

# 3. Implement minimal code to pass
defmodule DepaFinder.Notifications do
  def deliver(_message, _recipient), do: {:ok, :sent}
end

# 4. Run test - verify it passes (Green)  
mix test

# 5. Refactor while keeping tests green
```

### CLI Interface Requirements

Every library must expose CLI functionality:

```elixir
# In lib/depa_finder/notifications.ex
defmodule DepaFinder.Notifications do
  def main(args) do
    case OptionParser.parse(args, strict: [format: :string]) do
      {opts, [message, recipient], []} ->
        case deliver(message, recipient, opts) do
          {:ok, result} -> 
            if opts[:format] == "json" do
              IO.puts(Jason.encode!(result))
            else
              IO.puts("Notification delivered successfully")
            end
          {:error, reason} ->
            IO.puts(:stderr, "Error: #{reason}")
            System.halt(1)
        end
      _ ->
        IO.puts(:stderr, "Usage: notifications <message> <recipient> [--format json]")
        System.halt(1)
    end
  end
end
```

Make it executable:
```bash
# Test CLI interface
cd apps/api
mix escript.build
./depa_finder notifications "Hello" "user@example.com"
./depa_finder notifications "Hello" "user@example.com" --format json
```

## Technology Stack Guidelines

### Backend (Elixir/Phoenix)

**Project Structure:**
```
apps/api/
├── lib/
│   ├── depa_finder/          # Business logic libraries
│   │   ├── scraper.ex        # Standalone library with CLI
│   │   ├── notifications.ex  # Standalone library with CLI
│   │   └── ...
│   ├── depa_finder_web/      # Phoenix web layer
│   │   ├── controllers/      # Thin controllers
│   │   ├── channels/         # WebSocket handlers
│   │   └── ...
│   └── depa_finder.ex        # Application module
├── test/
│   ├── depa_finder/          # Library tests
│   ├── depa_finder_web/      # Web layer tests
│   ├── contracts/            # API contract tests
│   └── e2e/                  # End-to-end tests
└── mix.exs
```

**Testing Patterns:**
```elixir
# Unit tests for libraries
defmodule DepaFinder.ScraperTest do
  use ExUnit.Case, async: true
  # Test business logic in isolation
end

# Contract tests for APIs
defmodule DepaFinderWeb.ListingsControllerContractTest do
  use DepaFinderWeb.ConnCase, async: true
  # Test HTTP request/response contracts
end

# Integration tests
defmodule DepaFinder.IntegrationTest do
  use ExUnit.Case, async: false
  # Test with real database, external services
end
```

### Frontend (React/TypeScript)

**Project Structure:**
```
apps/web/
├── src/
│   ├── components/           # Reusable UI components
│   │   ├── ListingCard/
│   │   │   ├── ListingCard.tsx
│   │   │   ├── ListingCard.test.tsx
│   │   │   └── index.ts
│   │   └── ...
│   ├── services/            # API integration libraries
│   │   ├── api.ts           # Base API client
│   │   ├── listings.ts      # Listings service with CLI
│   │   └── notifications.ts # Notifications service
│   ├── hooks/              # Custom React hooks
│   ├── utils/              # Pure utility libraries
│   ├── e2e/                # E2E test specs
│   └── main.tsx
├── package.json
└── vite.config.ts
```

**Testing Patterns:**
```typescript
// Component unit tests
import { render, screen } from '@testing-library/react'
import { ListingCard } from './ListingCard'

describe('ListingCard', () => {
  it('displays listing information correctly', () => {
    // Test component behavior in isolation
  })
})

// Service integration tests  
import { listingsService } from '../services/listings'

describe('listingsService', () => {
  it('fetches listings from API', async () => {
    // Test with mock API responses
  })
})

// E2E tests
import { test, expect } from '@playwright/test'

test('user can search and view listings', async ({ page }) => {
  // Test complete user journeys
})
```

## Quality Standards

### Test Coverage
- Minimum 80% code coverage required
- 100% coverage for critical business logic
- Integration tests for all external API interactions

### Performance Targets
- API responses < 200ms for listing queries
- Frontend initial load < 2 seconds
- Test suite execution < 5 minutes total

### Code Complexity
- Maximum cyclomatic complexity: 10
- Maximum function length: 25 lines
- Maximum test nesting depth: 3 levels

## Common Patterns and Anti-Patterns

### ✅ Constitutional Patterns

**Library with CLI:**
```elixir
defmodule MyLibrary do
  def business_function(data), do: {:ok, transform(data)}
  
  def main(args) do
    # CLI interface implementation
  end
  
  defp transform(data), do: # implementation
end
```

**Test-First Implementation:**
```elixir
# 1. Write test
test "transforms data correctly" do
  assert {:ok, result} = MyLibrary.business_function(input)
  assert result == expected_output
end

# 2. Implement to pass test
def business_function(data), do: {:ok, data}

# 3. Refactor
def business_function(data) do
  with {:ok, validated} <- validate(data),
       {:ok, transformed} <- transform(validated) do
    {:ok, transformed}
  end
end
```

### ❌ Constitutional Violations

**Business Logic in Controllers:**
```elixir
# WRONG - violates Library-First principle
def create(conn, params) do
  # Complex business logic here
  processed_data = complex_processing(params)
  save_to_database(processed_data)
  notify_users(processed_data)
  render(conn, :created)
end
```

**Implementation Before Tests:**
```elixir
# WRONG - violates Test-First imperative
def new_feature(data) do
  # Implementation written without failing tests first
end
```

**No CLI Interface:**
```elixir
# WRONG - violates CLI Interface mandate  
defmodule MyLibrary do
  def business_function(data), do: process(data)
  # Missing: def main(args) - required CLI interface
end
```

## Debugging and Troubleshooting

### Spec Execution Issues
```bash
# Check driver configuration
speckit validate

# Run specific driver
speckit run --driver elixir_api --verbose

# Debug test failures
cd apps/api && mix test --trace
cd apps/web && pnpm test --verbose
```

### Constitutional Compliance Issues
```bash
# Check for missing CLI interfaces
find apps/ -name "*.ex" -exec grep -L "def main" {} \;

# Verify test-first compliance
git log --stat | grep -E "(test|spec)" | head -10

# Validate library structure
find apps/api/lib -name "*.ex" | xargs grep -l "defmodule.*Web"
```

## Migration Guide

When converting existing code to constitutional compliance:

1. **Extract Libraries**: Move business logic from controllers/components to standalone libraries
2. **Add CLI Interfaces**: Implement `main/1` functions for all libraries  
3. **Write Missing Tests**: Add tests for existing code following TDD patterns
4. **Add Integration Tests**: Ensure all external integrations have contract tests
5. **Validate Compliance**: Run `speckit validate` to verify all constitutional requirements

## Resources

- [Spec-Kit Documentation](https://github.com/github/spec-kit/blob/main/spec-driven.md)
- [Elixir Testing Patterns](https://hexdocs.pm/ex_unit/ExUnit.html)
- [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)
- [Constitutional Compliance Checklist](.specify/templates/checklist-template.md)
