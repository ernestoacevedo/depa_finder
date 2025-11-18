# Tinder for Apartments - Product Specifications

This directory contains comprehensive specifications for the "Tinder for Apartments" product built on top of the existing rental scraper infrastructure.

## Overview

The product allows users to swipe through pre-scraped apartments, "like" or "skip" them, and when two users both like the same apartment, they get matched and can coordinate their rental process together.

## Architecture

- **Backend**: Elixir API (Phoenix-style) in `apps/api`
- **Frontend**: React + TypeScript SPA in `apps/web`
- **Foundation**: Existing apartment scraper that populates the database

## Specification Files

### API Specifications
- `api/apartments.md` - Apartment listing and interaction endpoints
- `api/matches.md` - Match creation and management endpoints
- `api/notes.md` - Note management for matches
- `api/auth.md` - Authentication and authorization

### Domain Specifications
- `domain/matching.md` - Core matching logic and business rules
- `domain/state_transitions.md` - Match status state machine

### Frontend Specifications
- `ui/apartment_feed.md` - Main apartment browsing interface
- `ui/match_list.md` - User's match overview
- `ui/match_detail.md` - Individual match management

### Cross-cutting Concerns
- `cross_cutting/performance.md` - Performance requirements
- `cross_cutting/error_handling.md` - Error handling patterns

## Domain Model

```
User
- id: UUID
- email: string
- nickname: string
- created_at: datetime

Apartment (from existing Listing schema)
- id: UUID (from existing schema)
- source: string
- url: string
- title: string
- price_clp: integer
- area_m2: float
- bedrooms: integer
- bathrooms: integer
- address: string
- comuna: string

Like
- id: UUID
- user_id: UUID → User
- apartment_id: UUID → Apartment
- created_at: datetime

Match
- id: UUID
- apartment_id: UUID → Apartment
- user_1_id: UUID → User
- user_2_id: UUID → User
- status: enum
- created_at: datetime
- updated_at: datetime

Note
- id: UUID
- match_id: UUID → Match
- author_user_id: UUID → User
- body: text
- created_at: datetime
- updated_at: datetime
```

## Development Guidelines

All specifications follow the spec-kit methodology from GitHub's spec-driven development approach, with:
- Clear, testable examples
- Explicit happy path and error scenarios
- Concrete input/output formats
- Business logic separated from implementation details
