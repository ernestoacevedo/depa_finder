# Cross-cutting Specification: Performance Requirements

## Overview
Performance targets, monitoring, and optimization strategies for the apartment matching application.

## Response Time Targets

### API Endpoints
| Endpoint | Target Response Time | 95th Percentile |
|----------|---------------------|-----------------|
| `GET /api/apartments` | < 200ms | < 400ms |
| `POST /api/apartments/:id/like` | < 100ms | < 200ms |
| `GET /api/matches` | < 150ms | < 300ms |
| `GET /api/matches/:id` | < 100ms | < 200ms |
| `PATCH /api/matches/:id` | < 50ms | < 100ms |
| `POST /api/matches/:id/notes` | < 100ms | < 200ms |
| `PATCH /api/notes/:id` | < 50ms | < 100ms |

### Frontend Targets
| Metric | Target | Measurement |
|--------|--------|-------------|
| First Contentful Paint (FCP) | < 1.2s | Lighthouse |
| Largest Contentful Paint (LCP) | < 2.5s | Core Web Vitals |
| Time to Interactive (TTI) | < 3.0s | Lighthouse |
| Cumulative Layout Shift (CLS) | < 0.1 | Core Web Vitals |
| First Input Delay (FID) | < 100ms | Core Web Vitals |

## Database Performance

### Query Performance Targets
```sql
-- Apartment listing with filters
SELECT * FROM apartments WHERE comuna = ? AND price_clp BETWEEN ? AND ?
-- Target: < 50ms for 10,000 apartments

-- User's likes lookup  
SELECT apartment_id FROM likes WHERE user_id = ?
-- Target: < 20ms for 1,000 likes

-- Match creation check
SELECT * FROM likes WHERE apartment_id = ? AND user_id != ?
-- Target: < 10ms

-- Match detail with notes
SELECT m.*, a.*, u.*, n.* FROM matches m 
JOIN apartments a ON m.apartment_id = a.id
JOIN users u ON (m.user_1_id = u.id OR m.user_2_id = u.id) AND u.id != ?
LEFT JOIN notes n ON n.match_id = m.id
WHERE m.id = ?
-- Target: < 30ms
```

### Required Indexes
```sql
-- Core performance indexes
CREATE INDEX idx_apartments_comuna_price ON apartments(comuna, price_clp);
CREATE INDEX idx_apartments_bedrooms_area ON apartments(bedrooms, area_m2);
CREATE INDEX idx_likes_user_apartment ON likes(user_id, apartment_id);
CREATE INDEX idx_likes_apartment_user ON likes(apartment_id, user_id);
CREATE INDEX idx_matches_users ON matches(user_1_id, user_2_id);
CREATE INDEX idx_matches_apartment ON matches(apartment_id);
CREATE INDEX idx_notes_match_created ON notes(match_id, created_at);

-- Composite indexes for common queries
CREATE INDEX idx_apartments_filters ON apartments(comuna, price_clp, bedrooms, area_m2) 
WHERE deleted_at IS NULL;
```

## Memory and Resource Limits

### Backend (Elixir/Phoenix)
- **Process Memory**: < 512MB per application instance
- **Database Connections**: Max 20 per instance
- **Response Payload Size**: < 1MB for apartment listings
- **WebSocket Connections**: Support 1,000 concurrent connections
- **File Uploads**: < 10MB (future feature for user profiles)

### Frontend (React/TypeScript)
- **Bundle Size**: < 250KB gzipped for main bundle
- **Runtime Memory**: < 100MB after 1 hour of usage
- **Image Assets**: < 500KB total for UI assets
- **Local Storage**: < 5MB for user preferences and offline data

## Scalability Targets

### User Load
- **Concurrent Users**: Support 500 active users simultaneously
- **Peak Throughput**: 100 requests/second sustained
- **Database Size**: Perform well with 100,000 apartments and 10,000 users
- **Match Volume**: Handle 1,000 new matches per day

### Data Growth
- **Apartments**: 1,000 new apartments per week
- **Likes**: 10,000 new likes per week  
- **Notes**: 5,000 new notes per week
- **Storage Growth**: Plan for 10GB database growth per year

## Optimization Strategies

### Database Optimizations

**Query Optimization:**
```elixir
# Use preloading to avoid N+1 queries
def get_matches_with_details(user_id) do
  from(m in Match)
  |> where([m], m.user_1_id == ^user_id or m.user_2_id == ^user_id)
  |> preload([:apartment, :notes, user_1: [:profile], user_2: [:profile]])
  |> Repo.all()
end

# Use database-level pagination
def list_apartments(filters, pagination) do
  from(a in Apartment)
  |> apply_filters(filters)
  |> order_by([a], desc: a.published_at)
  |> limit(^pagination.per_page)
  |> offset(^((pagination.page - 1) * pagination.per_page))
  |> Repo.all()
end
```

**Connection Pooling:**
```elixir
# config/config.exs
config :depa_finder, DepaFinder.Repo,
  pool_size: 15,
  queue_target: 50,
  queue_interval: 1000
```

### Caching Strategies

**Application-Level Caching:**
```elixir
# Cache apartment counts for filter dropdowns
@decorate cache(cache: Application.get_env(:depa_finder, :cache), ttl: 300_000)
def get_comuna_counts() do
  # Expensive aggregation query
  Repo.all(from a in Apartment, group_by: a.comuna, select: {a.comuna, count(a.id)})
end

# Cache user match counts
@decorate cache(cache: Application.get_env(:depa_finder, :cache), ttl: 60_000)  
def get_user_match_count(user_id) do
  from(m in Match, where: m.user_1_id == ^user_id or m.user_2_id == ^user_id)
  |> Repo.aggregate(:count, :id)
end
```

**HTTP Caching:**
```elixir
# Set appropriate cache headers for static apartment data
def apartment_show(conn, %{"id" => id}) do
  apartment = Apartments.get_apartment!(id)
  
  conn
  |> put_resp_header("cache-control", "public, max-age=300") # 5 minutes
  |> put_resp_header("etag", apartment.updated_at |> to_string())
  |> render("show.json", apartment: apartment)
end
```

### Frontend Optimizations

**Bundle Optimization:**
```typescript
// Code splitting for routes
const ApartmentFeed = lazy(() => import('./components/ApartmentFeed'))
const MatchList = lazy(() => import('./components/MatchList'))
const MatchDetail = lazy(() => import('./components/MatchDetail'))

// Tree shaking for utility libraries
import { debounce } from 'lodash-es'  // Instead of entire lodash
```

**State Management Optimization:**
```typescript
// Memoized selectors to prevent unnecessary re-renders
const selectFilteredApartments = createSelector(
  [selectApartments, selectFilters],
  (apartments, filters) => applyFilters(apartments, filters)
)

// Virtualized lists for large data sets
<FixedSizeList
  height={600}
  itemCount={apartments.length}
  itemSize={120}
  itemData={apartments}
>
  {ApartmentCard}
</FixedSizeList>
```

**Network Optimization:**
```typescript
// Request deduplication
const useApartments = (filters) => {
  return useQuery(
    ['apartments', filters],
    () => fetchApartments(filters),
    {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      refetchOnWindowFocus: false
    }
  )
}

// Optimistic updates for likes
const useLikeApartment = () => {
  const queryClient = useQueryClient()
  
  return useMutation(likeApartment, {
    onMutate: async (apartmentId) => {
      // Optimistically update UI before API response
      await queryClient.cancelQueries(['apartments'])
      const previousApartments = queryClient.getQueryData(['apartments'])
      
      queryClient.setQueryData(['apartments'], (old) =>
        updateApartmentLikeStatus(old, apartmentId, true)
      )
      
      return { previousApartments }
    },
    onError: (err, variables, context) => {
      // Rollback on error
      queryClient.setQueryData(['apartments'], context.previousApartments)
    }
  })
}
```

## Monitoring and Alerting

### Key Metrics to Track

**Backend Metrics:**
- Response time percentiles (50th, 95th, 99th)
- Error rates by endpoint
- Database query performance
- Memory and CPU usage
- Active WebSocket connections

**Frontend Metrics:**
- Core Web Vitals scores
- JavaScript error rates
- API call success rates
- User interaction latency
- Bundle size over time

### Performance Testing

**Load Testing Scenarios:**
```bash
# Basic apartment browsing load
artillery run --config load-test-config.yml apartment-browsing.yml

# Like/match creation stress test
artillery run --config load-test-config.yml match-creation.yml

# WebSocket connection scaling
artillery run --config load-test-config.yml websocket-scaling.yml
```

**Benchmark Tests:**
```elixir
# Database query benchmarks
defmodule ApartmentBench do
  use Benchee
  
  def run do
    Benchee.run(%{
      "apartment_listing_no_filters" => fn -> Apartments.list_apartments(%{}, %{page: 1, per_page: 20}) end,
      "apartment_listing_with_filters" => fn -> 
        Apartments.list_apartments(%{comuna: "Providencia", min_bedrooms: 2}, %{page: 1, per_page: 20}) 
      end,
      "user_matches_with_preload" => fn -> Matches.list_user_matches("user-id") end
    })
  end
end
```

### Performance Budgets

**Regression Thresholds:**
- API response times increase > 20% from baseline
- Frontend bundle size increases > 10KB
- Database query times increase > 50ms
- Memory usage increases > 100MB
- Error rates exceed 1%

**Automated Performance Checks:**
```yaml
# GitHub Actions performance check
- name: Performance Regression Check
  run: |
    npm run test:performance
    npm run lighthouse:ci
    mix test --only performance
```

## Graceful Degradation

### Progressive Enhancement
- Core apartment browsing works without JavaScript
- Basic like functionality available with slow connections
- Offline support for viewing already loaded apartments
- Fallback UI states for failed API calls

### Connection Quality Adaptation
```typescript
// Adapt behavior based on connection quality
const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection

if (connection && connection.effectiveType === '2g') {
  // Reduce polling frequency, smaller page sizes
  return { pollInterval: 30000, pageSize: 10 }
} else {
  return { pollInterval: 5000, pageSize: 20 }
}
```

### Resource Prioritization
```typescript
// Critical resource loading
<link rel="preload" href="/api/apartments" as="fetch" crossorigin>
<link rel="dns-prefetch" href="https://cdn.example.com">

// Non-critical resources
<link rel="prefetch" href="/api/user/matches">
```
