# UI Specification: Match Detail

## Overview
Detailed interface for individual match management, including apartment details, other user information, status coordination, and note collaboration.

## Component Structure

### MatchDetail Component

**Props:**
```typescript
interface MatchDetailProps {
  matchId: string
  onStatusUpdate: (status: MatchStatus) => Promise<void>
  onNoteAdd: (body: string) => Promise<Note>
  onNoteEdit: (noteId: string, body: string) => Promise<Note>
  onNoteDelete: (noteId: string) => Promise<void>
  onBack: () => void
  className?: string
}
```

### Match Data Structure
```typescript
interface MatchDetail {
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
    url: string
  }
  other_user: {
    id: string
    nickname: string
    joined_at: string
  }
  status: MatchStatus
  created_at: string
  updated_at: string
  notes: Note[]
}

interface Note {
  id: string
  body: string
  author: {
    id: string
    nickname: string
    is_me: boolean
  }
  match_id: string
  created_at: string
  updated_at: string
}
```

## Layout Sections

### Header Section
```
┌─────────────────────────────────────────┐
│ ← Back to Matches    [Status: Visited] ▼│
│                                          │
│ Hermoso departamento en Providencia      │
│ $850.000 • 2br • 1ba • 65m²            │
│ Av. Providencia 2547, Providencia       │
│                                          │
│ 🏠 [View Original Listing] 🔗           │
└─────────────────────────────────────────┘
```

### Collaboration Section
```
┌─────────────────────────────────────────┐
│ 👥 Matched with apartmentseeker42        │
│    Member since October 2025             │
│                                          │
│ Match created Nov 18, 2025               │
│ Status: Visited                          │
│ [Update Status ▼]                       │
└─────────────────────────────────────────┘
```

### Notes Section
```
┌─────────────────────────────────────────┐
│ 💬 Coordination Notes (3)               │
│ ────────────────────────────────────────│
│ homehunter23 (You) • 2 hours ago        │
│ I can visit this weekend if available!   │
│ [Edit] [Delete]                         │
│ ────────────────────────────────────────│
│ apartmentseeker42 • 1 hour ago          │
│ Perfect! Saturday morning works. Should  │
│ we contact the agent together?           │
│ ────────────────────────────────────────│
│ [Add a note...] [Send]                  │
└─────────────────────────────────────────┘
```

## User Interactions

### Status Management

**Status Update Flow:**
```
Given: User views match detail
When: User clicks status dropdown
Then: Show status options based on current state and valid transitions
And: Disable invalid transition options with tooltips
When: User selects new status
Then: Show confirmation for destructive actions (discarded)
And: Update status with loading state
And: Show success feedback when complete
And: Update timestamp and status badge
```

**Status Dropdown Options:**
- Show only valid transitions from current state
- Include descriptive text for each option
- Highlight destructive actions (discarded) in red
- Show loading spinner during update

### Note Management

**Adding Notes:**
```
Given: User wants to add coordination note
When: User types in note input field
Then: Show character count (limit: 1000 chars)
And: Enable send button when content is valid
When: User clicks send or presses Ctrl+Enter
Then: Show optimistic UI with note immediately
And: Disable input during API call
And: Show error state if API fails
And: Scroll to new note when successful
```

**Editing Notes:**
```
Given: User wants to edit their own note
When: User clicks edit button (only visible for own notes)
Then: Note text becomes editable inline
And: Show save/cancel buttons
And: Track edit time window (24 hours)
When: User saves changes
Then: Show loading state on note
And: Update note with new content and timestamp
And: Show "edited" indicator on note
```

**Deleting Notes:**
```
Given: User wants to delete their note
When: User clicks delete button
Then: Show confirmation modal "Delete this note?"
When: User confirms deletion
Then: Optimistically remove note from UI
And: Show undo option for 5 seconds
And: Permanently delete if no undo
```

### Apartment Actions

**View Original Listing:**
```
Given: User wants to see full apartment details
When: User clicks "View Original Listing"
Then: Open apartment URL in new tab/window
And: Track click for analytics
```

**Share Match:**
```
Given: User wants to share match externally
When: User clicks share button (future)
Then: Copy shareable match URL to clipboard
And: Show "Link copied" feedback
```

## Real-time Updates

### Live Note Updates
```
Given: Other user adds a note
When: Note is created via WebSocket
Then: New note appears with slide-in animation
And: Scroll to new note if user is near bottom
And: Show notification if user is scrolled up
And: Update note count in header
```

### Status Change Updates
```
Given: Other user updates match status
When: Status change occurs
Then: Status badge updates with transition animation
And: Show brief notification "Status updated by [user]"
And: Updated timestamp reflects change
```

### Typing Indicators
```
Given: Other user is typing a note
When: Typing activity detected
Then: Show "[user] is typing..." indicator
And: Hide indicator after 3 seconds of inactivity
And: Position above note input area
```

## Error Handling

### Network Errors
```
Given: User performs action while offline
When: Network request fails
Then: Show appropriate error message
And: Maintain optimistic UI state
And: Provide retry button
And: Queue actions for when connectivity returns
```

### Permission Errors
```
Given: User tries to edit note they don't own
When: API returns 403 error
Then: Show "You can only edit your own notes" message
And: Revert any optimistic UI changes
And: Disable edit controls for that note
```

### Validation Errors
```
Given: User submits invalid note content
When: API returns validation error
Then: Show inline error below input field
And: Highlight problematic content
And: Keep note content for user to fix
And: Focus back to input field
```

## Responsive Design

### Mobile Layout
- Stack sections vertically
- Full-width note input at bottom
- Swipe up for note history
- Large touch targets for actions
- Collapse apartment details by default

### Desktop Layout
- Two-column layout (apartment + collaboration)
- Fixed note input at bottom of notes section
- Hover states for interactive elements
- Keyboard shortcuts for actions

### Tablet Layout
- Hybrid approach based on screen width
- Collapsible sidebar for apartment details
- Optimized for both portrait and landscape

## Accessibility

### Screen Reader Support
- Proper heading hierarchy (h1 > h2 > h3)
- ARIA labels for status controls
- Live regions for note updates
- Descriptive button labels

### Keyboard Navigation
- Tab order: header → status → notes → input
- Enter to send note, Shift+Enter for new line
- Escape to cancel editing
- Arrow keys for note navigation

### Visual Accessibility
- High contrast status badges
- Clear visual hierarchy
- Sufficient color contrast ratios
- Text alternatives for icons

## Performance Optimizations

### Note Rendering
- Virtual scrolling for matches with 100+ notes
- Lazy load note history beyond initial 20
- Debounced typing indicators
- Efficient diff updates for real-time changes

### Image Handling
- Lazy load apartment images
- Placeholder images while loading
- Optimized image sizes for different screens

### State Management
- Local optimistic updates
- Background sync for offline actions
- Efficient WebSocket message handling

## State Management

### Component State
```typescript
interface MatchDetailState {
  match: MatchDetail | null
  loading: boolean
  error: string | null
  updatingStatus: boolean
  addingNote: boolean
  editingNoteId: string | null
  noteInput: string
  optimisticNotes: Note[]
}
```

### Real-time State
```typescript
interface RealtimeState {
  connected: boolean
  typingUsers: string[]
  pendingUpdates: PendingUpdate[]
}
```

## Testing Scenarios

### Happy Path Tests
```typescript
describe('MatchDetail Happy Paths', () => {
  it('displays match information correctly')
  it('updates status through complete flow') 
  it('adds notes with real-time updates')
  it('edits own notes within time window')
  it('handles concurrent note updates gracefully')
})
```

### Error Handling Tests
```typescript
describe('MatchDetail Error Handling', () => {
  it('handles network failures gracefully')
  it('prevents editing notes after 24 hours')
  it('shows appropriate errors for invalid actions')
  it('recovers from WebSocket disconnections')
})
```

### User Journey Tests
```
Scenario: Complete apartment coordination
Given: User and match partner want to visit apartment
When: Users coordinate through notes
And: Update status to "pending_visit" → "visited" → "applied"
And: Share contact information and visit notes
Then: Both users have clear coordination history
And: Status reflects current progress accurately
```

## Analytics Events

### Interaction Tracking
- `match_detail_viewed` - User opens match detail
- `status_updated` - User changes match status
- `note_added` - User adds new note
- `note_edited` - User edits existing note
- `apartment_link_clicked` - User views original listing

### Engagement Metrics
- Time spent on match detail page
- Notes per match ratio
- Status progression rates
- User collaboration patterns
