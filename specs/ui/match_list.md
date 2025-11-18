# UI Specification: Match List

## Overview
Interface showing all matches for the current user, providing overview and navigation to individual match details.

## Component Structure

### MatchList Component

**Props:**
```typescript
interface MatchListProps {
  onMatchSelect: (matchId: string) => void
  filters?: MatchFilters
  className?: string
}

interface MatchFilters {
  status?: MatchStatus[]
  sortBy?: 'newest' | 'oldest' | 'last_activity'
}

type MatchStatus = 'pending' | 'pending_visit' | 'visited' | 'applied' | 'accepted' | 'rejected' | 'discarded'
```

### MatchCard Component

**Props:**
```typescript
interface MatchCardProps {
  match: MatchSummary
  onClick: () => void
  className?: string
}

interface MatchSummary {
  id: string
  apartment: {
    id: string
    title: string
    price_clp: number
    area_m2: number
    bedrooms: number
    bathrooms: number
    address: string
    comuna: string
  }
  other_user: {
    id: string
    nickname: string
  }
  status: MatchStatus
  note_count: number
  last_activity_at: string
  created_at: string
}
```

## User Interactions

### Match Navigation

**Scenario: User clicks on match**
```
Given: User views match list
When: User clicks on a match card
Then: Navigation occurs to match detail page
And: Match ID is included in URL
And: Loading state shows during navigation
```

**Scenario: Match card hover (desktop)**
```
Given: User hovers over match card
When: Mouse enters card area
Then: Card elevates with subtle shadow
And: "View Details" button becomes visible
And: Quick preview of last note appears (if any)
```

### Status Filtering

**Scenario: User filters by status**
```
Given: User has matches in various states
When: User selects status filter (e.g., "pending_visit")
Then: List immediately filters to show only matches with that status
And: Count indicator shows number of filtered results
And: URL parameters update to reflect filter
And: Filter selection persists across sessions
```

### Sorting Options

**Scenario: User changes sort order**
```
Given: User has multiple matches
When: User selects "Last Activity" sort option
Then: Matches reorder by most recent note/status change first
And: Sort preference is saved to user preferences
And: Loading indicator shows briefly during reorder
```

**Sort Options:**
- **Last Activity** (default): Most recently updated matches first
- **Newest**: Most recently created matches first  
- **Oldest**: Oldest matches first

## Visual Design

### Match Card Layout

**Card Structure:**
```
┌─────────────────────────────────────────┐
│ 📍 [Comuna]               [Status Badge] │
│ Apartment Title                          │
│ $850.000 • 2br • 65m²                  │
│ ────────────────────────────────────────│
│ 👤 with apartmentseeker42               │
│ 💬 3 notes • Last: 2 hours ago         │
└─────────────────────────────────────────┘
```

**Status Badges:**
- `pending`: Gray badge "New Match"
- `pending_visit`: Blue badge "Planning Visit"
- `visited`: Green badge "Visited"
- `applied`: Yellow badge "Applied" 
- `accepted`: Green badge "Accepted" ✅
- `rejected`: Red badge "Rejected" ❌
- `discarded`: Gray badge "Closed"

### Empty States

**No Matches:**
```
┌─────────────────────────────────────────┐
│                   🏠                     │
│          No matches yet                  │
│                                          │
│    Start liking apartments to find      │
│         people to house-hunt with       │
│                                          │
│        [Browse Apartments]              │
└─────────────────────────────────────────┘
```

**No Matches for Filter:**
```
┌─────────────────────────────────────────┐
│                   🔍                     │
│       No matches found                   │
│                                          │
│      Try adjusting your filters         │
│                                          │
│        [Clear Filters]                  │
└─────────────────────────────────────────┘
```

## Loading and Error States

### Initial Load
- Skeleton cards (3-4 shimmer placeholders)
- "Loading your matches..." text
- Progressive enhancement as data arrives

### Refresh/Update
- Pull-to-refresh on mobile
- Subtle loading indicator at top of list
- Maintain scroll position during updates

### Error Handling

**Network Error:**
```
Given: API request fails
When: Error occurs during match loading
Then: Error banner appears with retry option
And: Previous matches remain visible if any
And: "Retry" button allows user to reload
```

**Individual Match Error:**
```
Given: User clicks on a match
When: Navigation fails
Then: Toast notification shows "Unable to load match"
And: User remains on match list
And: Can retry by clicking again
```

## Real-time Updates

### New Match Notification
```
Given: Another user likes apartment that current user already liked
When: Match is created
Then: New match appears at top of list with animation
And: Push notification sent (if enabled)
And: Badge appears on app icon/tab (if applicable)
```

### Status Change Updates
```
Given: Match status is updated (by other user or current user in another tab)
When: Status change occurs
Then: Match card updates with new status badge
And: Last activity timestamp updates
And: List reorders if sorted by last activity
```

## Responsive Design

### Mobile Layout
- Single column list
- Swipe actions for quick status update (future enhancement)
- Pull-to-refresh gesture
- Bottom tab navigation integration

### Desktop Layout
- Grid layout (2 columns) for wider screens
- Sidebar with filters always visible
- Hover states and transitions
- Keyboard navigation support

## Accessibility

### Screen Reader Support
- Match cards have descriptive labels
- Status badges have clear text alternatives
- Filter controls are properly labeled
- Loading states announced to screen readers

### Keyboard Navigation
- Tab through matches sequentially
- Enter/Space to select match
- Arrow keys for quick navigation
- Filter controls accessible via keyboard

## State Management

### Component State
```typescript
interface MatchListState {
  matches: MatchSummary[]
  loading: boolean
  error: string | null
  filters: MatchFilters
  sortBy: SortOption
}
```

### Real-time Subscriptions
```typescript
interface MatchSubscriptionData {
  type: 'match_created' | 'match_updated' | 'match_deleted'
  match: MatchSummary
  timestamp: string
}
```

## Performance Requirements

### Metrics
- Initial load: < 800ms
- Filter application: < 200ms
- Real-time update processing: < 100ms
- Smooth scrolling and animations: 60fps

### Optimizations
- Virtual scrolling for users with 50+ matches
- Debounced filter updates
- Optimistic UI for status changes
- Efficient diff updates for real-time changes

## Testing Scenarios

### Component Tests
```typescript
describe('MatchList', () => {
  it('displays matches from API')
  it('applies status filters correctly')
  it('sorts matches by selected criteria')
  it('handles empty state appropriately')
  it('shows loading states during fetch')
  it('handles match selection navigation')
})
```

### Integration Tests
```typescript
describe('MatchList Integration', () => {
  it('updates in real-time when new match created')
  it('persists filter preferences across sessions')
  it('handles concurrent status updates gracefully')
  it('maintains scroll position during updates')
})
```

### User Journey Tests
```
Scenario: Finding an active match
Given: User has 10 matches in various states
When: User filters to "pending_visit" status
And: Clicks on most recent match
Then: Navigate to match detail with correct data
```

```
Scenario: Managing multiple matches
Given: User has matches for 5 different apartments
When: User sorts by "Last Activity"
And: Reviews most active matches first
Then: Can efficiently manage active house hunting
```

## Analytics Events

### Tracking Points
- `match_list_viewed` - User opens match list
- `match_filter_applied` - User applies status filter
- `match_card_clicked` - User navigates to match detail
- `match_sort_changed` - User changes sort order
- `match_list_refreshed` - User pulls to refresh

### Metrics
- Average time spent on match list
- Most common filter usage
- Match click-through rates by status
- User engagement with different sort orders
