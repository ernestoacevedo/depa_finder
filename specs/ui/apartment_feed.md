# UI Specification: Apartment Feed

## Overview
Main interface for browsing apartments and expressing interest through like/skip actions.

## Component Structure

### ApartmentFeed Component

**Props:**
```typescript
interface ApartmentFeedProps {
  onLike: (apartmentId: string) => Promise<LikeResponse>
  onSkip?: (apartmentId: string) => void
  filters?: ApartmentFilters
  className?: string
}

interface ApartmentFilters {
  comuna?: string
  minPrice?: number
  maxPrice?: number
  minBedrooms?: number
  maxBedrooms?: number
  minArea?: number
  maxArea?: number
  excludeLiked?: boolean
}

interface LikeResponse {
  like: Like
  matchCreated: boolean
  match?: Match
}
```

### ApartmentCard Component

**Props:**
```typescript
interface ApartmentCardProps {
  apartment: Apartment
  onLike: (id: string) => Promise<LikeResponse>
  onSkip?: (id: string) => void
  isLiking: boolean
  className?: string
}

interface Apartment {
  id: string
  title: string
  price_clp: number
  area_m2: number
  bedrooms: number
  bathrooms: number
  address: string
  comuna: string
  url: string
  source: string
  published_at: string
  user_liked: boolean
}
```

## User Interactions

### Like Button Behavior

**Scenario: User likes apartment**
```
Given: User views apartment card
When: User clicks "Like" button
Then: Button shows loading state
And: API request is made to POST /api/apartments/:id/like
And: If successful, button shows "Liked" state with checkmark
And: If match created, show match notification
And: If error, show error message and revert button state
```

**Scenario: User likes apartment that creates match**
```
Given: Another user has already liked the apartment
When: Current user clicks "Like" button  
Then: Like is created successfully
And: Match notification appears with other user info
And: User can navigate to match detail from notification
```

**Visual States:**
- **Default**: "Like" button with heart icon
- **Loading**: Spinner in button, disabled state
- **Liked**: Green checkmark, "Liked" text, disabled
- **Error**: Red border, error message below

### Skip Button Behavior

**Scenario: User skips apartment**
```
Given: User views apartment card
When: User clicks "Skip" button  
Then: Apartment is immediately hidden from feed
And: No API request is made (skip is client-side only)
And: Next apartment appears
```

**Note**: Skip is not persisted - apartment may reappear in future sessions.

### Match Notification

**Scenario: Match created notification**
```
Given: User likes apartment that creates match
When: API response includes match information
Then: Modal/toast appears with celebration animation
And: Shows other user's nickname
And: Shows apartment title/address
And: Provides "View Match" button to navigate to match detail
And: Provides "Dismiss" button to continue browsing
```

## Feed Behavior

### Infinite Scroll

**Scenario: User scrolls to bottom**
```
Given: User has scrolled through current apartments
When: User reaches bottom of feed
Then: Loading indicator appears
And: Next page of apartments is fetched
And: New apartments are appended to feed
And: If no more apartments, show "No more apartments" message
```

**Technical Requirements:**
- Implement virtual scrolling for performance with large lists
- Prefetch next page when user is 3 apartments from bottom
- Maintain scroll position during updates

### Loading States

**Initial Load:**
- Skeleton cards (3-4 placeholder cards)
- "Loading apartments..." text

**Pagination Load:**
- Spinner at bottom of feed
- Maintain existing apartments

**Empty State:**
- "No apartments match your criteria" message
- Suggestion to adjust filters
- Illustration of empty state

### Error States

**Network Error:**
```
Given: API request fails
When: Error occurs during apartment loading
Then: Error banner appears at top of feed
And: "Retry" button allows user to retry request
And: Previous apartments remain visible
```

**Like Error:**
```
Given: User attempts to like apartment
When: API request fails
Then: Toast notification shows "Failed to like apartment"
And: Button reverts to default state
And: User can retry the action
```

## Filtering Interface

### Filter Sidebar/Modal

**Components:**
- Comuna dropdown (populated from API)
- Price range slider (min/max inputs)
- Bedroom count selector (0-5+)
- Area range slider (m²)
- "Exclude already liked" checkbox

**Behavior:**
```
Given: User adjusts filters
When: Filter value changes
Then: Feed immediately updates with debounced API call (300ms delay)
And: Loading state shows during filter application
And: URL parameters update to reflect current filters
And: Filter state persists in localStorage
```

## Responsive Design

### Mobile Layout
- Single column apartment cards
- Swipe gestures for like/skip
- Bottom sheet for filters
- Large touch targets (44px minimum)

### Desktop Layout  
- Grid of apartment cards (2-3 columns)
- Sidebar filters always visible
- Hover states for interactive elements
- Keyboard navigation support

## Accessibility

### Screen Reader Support
- Proper ARIA labels for like/skip buttons
- Card content structured with semantic HTML
- Live region announcements for loading states
- Focus management for modal interactions

### Keyboard Navigation
- Tab through apartments sequentially
- Space/Enter to activate like button
- Arrow keys for apartment navigation (optional)
- Escape to close modals/notifications

## Performance Requirements

### Metrics
- Initial feed load: < 1 second
- Like action response: < 200ms visual feedback
- Smooth scrolling at 60fps
- Memory usage stays under 100MB for 100+ apartments

### Optimizations
- Image lazy loading for apartment photos (future)
- Virtual scrolling for large lists
- Debounced filter updates
- Optimistic UI updates for like actions

## State Management

### Component State
```typescript
interface ApartmentFeedState {
  apartments: Apartment[]
  loading: boolean
  error: string | null
  hasMore: boolean
  page: number
  filters: ApartmentFilters
  likingApartments: Set<string> // Track loading states
}
```

### Global State Integration
- User authentication status
- Current user preferences
- Match notifications queue
- Filter preferences persistence

## Testing Scenarios

### Component Tests
```typescript
describe('ApartmentFeed', () => {
  it('displays apartments from API')
  it('shows loading state during initial fetch')
  it('handles like button click with optimistic UI')
  it('shows match notification when match created') 
  it('handles infinite scroll pagination')
  it('applies filters and updates feed')
  it('shows appropriate error states')
})
```

### Integration Tests
```typescript
describe('ApartmentFeed Integration', () => {
  it('complete like flow creates match')
  it('filter changes update URL and persist')
  it('infinite scroll loads additional pages')
  it('handles concurrent like attempts gracefully')
})
```

### User Scenarios
- **Power User**: Quickly browse 50+ apartments with filters
- **Mobile User**: Swipe through apartments on phone
- **Accessibility User**: Navigate feed with screen reader
- **Slow Network**: Experience with 3G connection speeds
