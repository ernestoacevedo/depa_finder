# Domain Specification: Matching Logic

## Overview
Core business logic for creating matches when users like the same apartment.

## Domain Rules

### Match Creation Logic

**Given** two users exist in the system
**When** both users like the same apartment
**Then** a match is automatically created between them

**Scenario: First user likes apartment**
- **Given**: User A likes Apartment 1
- **When**: Like is recorded
- **Then**: No match is created yet
- **And**: Like is stored with timestamp

**Scenario: Second user creates match**
- **Given**: User A has already liked Apartment 1  
- **When**: User B likes Apartment 1
- **Then**: A match is created with User A and User B
- **And**: Match status is set to "pending"
- **And**: Both users are notified of the match (future enhancement)

**Scenario: Third user doesn't affect existing match**
- **Given**: User A and User B have matched on Apartment 1
- **When**: User C likes Apartment 1  
- **Then**: No new match is created
- **And**: User C's like is stored independently
- **And**: Existing match between A and B is unchanged

### Match Uniqueness Rules

**Rule**: Only one match can exist for any combination of (apartment_id, user_1_id, user_2_id)

**Scenario: Duplicate match prevention**
- **Given**: User A and User B have matched on Apartment 1
- **When**: The system attempts to create another match for the same users and apartment
- **Then**: The operation should fail or be ignored
- **And**: The existing match should remain unchanged

**Scenario: User order independence**  
- **Given**: A match exists between User A and User B on Apartment 1
- **When**: Checking for existing matches
- **Then**: The match should be found regardless of whether we query (A,B) or (B,A)

### Like Removal and Match Deletion

**Rule**: When a user removes their like for an apartment, any associated match must be deleted

**Scenario: Like removal breaks match**
- **Given**: User A and User B have matched on Apartment 1
- **When**: User A removes their like for Apartment 1
- **Then**: The match between User A and User B is deleted
- **And**: User B's like for Apartment 1 remains
- **And**: All notes associated with the match are deleted

**Scenario: Re-liking after match deletion**
- **Given**: User A removed their like, breaking a match with User B
- **When**: User A likes Apartment 1 again
- **Then**: A new match is created between User A and User B
- **And**: The new match has a fresh ID and "pending" status
- **And**: Previous notes are not restored

### Multi-User Scenario

**Scenario: Multiple users, selective matching**
- **Given**: Users A, B, C, and D exist
- **When**: User A likes Apartment 1
- **And**: User B likes Apartment 1 (creates match A-B)
- **And**: User C likes Apartment 1 (no new match)
- **And**: User D likes Apartment 1 (no new match)
- **Then**: Only one match exists: A-B on Apartment 1
- **And**: Users C and D have individual likes but no matches

**Scenario: Same users, different apartments**
- **Given**: User A and User B have matched on Apartment 1
- **When**: User A likes Apartment 2
- **And**: User B likes Apartment 2
- **Then**: A second match is created between User A and User B for Apartment 2
- **And**: Both matches exist independently

## Implementation Constraints

### Database Consistency
- Match creation must be atomic (both the like and the match creation)
- Use database transactions to ensure consistency
- Handle race conditions where two users like simultaneously

### Concurrency Handling
- **Given**: User A and User B like the same apartment at exactly the same time
- **Then**: Only one match should be created
- **And**: Both likes should be recorded
- **Implementation**: Use database-level constraints and proper transaction isolation

### Performance Requirements
- Match creation should complete within 100ms
- Like queries should use proper indexes on (apartment_id, user_id)
- Match queries should use indexes on (apartment_id, user_1_id, user_2_id)

## Domain Events (Future Enhancement)

### Match Created Event
```elixir
%MatchCreated{
  match_id: UUID,
  apartment_id: UUID,
  user_1_id: UUID,
  user_2_id: UUID,
  created_at: DateTime
}
```

### Match Deleted Event  
```elixir
%MatchDeleted{
  match_id: UUID,
  apartment_id: UUID,
  reason: "like_removed" | "user_deleted",
  deleted_at: DateTime
}
```

## Data Invariants

### Always True
1. A match always has exactly 2 users
2. Both users in a match have likes for the same apartment
3. A match cannot exist without corresponding likes
4. Match user_1_id ≠ user_2_id (users cannot match with themselves)

### Never True  
1. A user cannot like the same apartment twice
2. A match cannot exist with only one user
3. A match cannot reference a non-existent apartment
4. Users cannot match on apartments they haven't liked

## Test Scenarios

### Edge Cases to Test

**Empty State**
- No likes exist → No matches can be created

**Single Like**  
- One user likes apartment → No match created

**Self-Matching Prevention**
- User cannot like apartment twice → Second like attempt fails

**Cascading Deletions**
- User account deleted → All their likes and matches are removed
- Apartment removed from system → All associated likes and matches removed

**Timing Edge Cases**
- Two users like simultaneously → One match created
- User removes like while another user is liking → Match creation may fail gracefully

## Business Logic Functions

### Core Functions (Elixir)

```elixir
# Primary matching logic
@spec create_like_and_check_match(user_id :: String.t(), apartment_id :: String.t()) ::
  {:ok, %{like: Like.t(), match: Match.t() | nil}} | {:error, reason :: atom()}

# Match lookup  
@spec find_existing_match(apartment_id :: String.t(), user_id :: String.t()) ::
  Match.t() | nil

# Like removal with cascading
@spec remove_like_and_match(user_id :: String.t(), apartment_id :: String.t()) ::
  {:ok, %{like_removed: boolean(), match_deleted: boolean()}} | {:error, reason :: atom()}
```

### Validation Rules

```elixir
# Prevent duplicate likes
def validate_like(user_id, apartment_id) do
  case Repo.get_by(Like, user_id: user_id, apartment_id: apartment_id) do
    nil -> :ok
    _like -> {:error, :already_liked}
  end
end

# Ensure users exist  
def validate_users_exist([user_1_id, user_2_id]) do
  existing = Repo.all(from u in User, where: u.id in ^[user_1_id, user_2_id], select: u.id)
  if length(existing) == 2, do: :ok, else: {:error, :users_not_found}
end
```
