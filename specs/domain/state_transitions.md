# Domain Specification: Match State Transitions

## Overview
Finite state machine for match status lifecycle from creation to completion.

## States

### Valid Match Statuses

```elixir
@valid_statuses ~w[
  pending
  pending_visit  
  visited
  applied
  accepted
  rejected
  discarded
]a
```

### State Descriptions

- **pending**: Initial state when match is created, users haven't made plans yet
- **pending_visit**: Users are actively planning to visit the apartment
- **visited**: Users have completed a viewing of the apartment  
- **applied**: Users have submitted an application for the apartment
- **accepted**: Application was accepted by landlord/agent
- **rejected**: Application was rejected by landlord/agent  
- **discarded**: Users decided not to pursue this apartment further

## State Transitions

### Valid Transitions

```
pending → pending_visit, discarded
pending_visit → visited, discarded
visited → applied, discarded  
applied → accepted, rejected, discarded
accepted → [TERMINAL STATE]
rejected → [TERMINAL STATE]  
discarded → [TERMINAL STATE]
```

### State Transition Rules

#### From `pending`
- **To `pending_visit`**: Users decide to coordinate a visit
  - **Trigger**: Either user updates status
  - **Validation**: None required
  
- **To `discarded`**: Users lose interest without visiting
  - **Trigger**: Either user updates status  
  - **Validation**: None required

#### From `pending_visit`  
- **To `visited`**: Users completed the apartment viewing
  - **Trigger**: Either user updates status
  - **Validation**: None required
  
- **To `discarded`**: Users cancel visit plans or lose interest  
  - **Trigger**: Either user updates status
  - **Validation**: None required

#### From `visited`
- **To `applied`**: Users decide to apply for the apartment
  - **Trigger**: Either user updates status
  - **Validation**: None required
  
- **To `discarded`**: Users decide not to pursue after viewing
  - **Trigger**: Either user updates status  
  - **Validation**: None required

#### From `applied`
- **To `accepted`**: Landlord/agent accepts their application
  - **Trigger**: Either user updates status
  - **Validation**: None required
  
- **To `rejected`**: Landlord/agent rejects their application  
  - **Trigger**: Either user updates status
  - **Validation**: None required
  
- **To `discarded`**: Users withdraw their application
  - **Trigger**: Either user updates status
  - **Validation**: None required

#### Terminal States
- **`accepted`**, **`rejected`**, **`discarded`**: No further transitions allowed
  - **Validation**: Any attempt to transition from these states should return error

## Business Rules

### Authorization for State Changes
- **Rule**: Either user in the match can update the status
- **Rationale**: Both users need ability to advance the process

### State Change Notifications (Future Enhancement)
- When status changes, both users should be notified
- Status changes should update the match's `updated_at` timestamp
- Status changes should be logged for audit trail

### Automatic State Transitions (Future Enhancement)
- Matches in `pending` for >7 days could auto-transition to `discarded`
- Matches in `pending_visit` for >14 days could auto-transition to `discarded`

## Validation Logic

### State Transition Validation

```elixir
defmodule MatchStateMachine do
  @transitions %{
    pending: [:pending_visit, :discarded],
    pending_visit: [:visited, :discarded], 
    visited: [:applied, :discarded],
    applied: [:accepted, :rejected, :discarded],
    accepted: [],
    rejected: [],
    discarded: []
  }

  def valid_transition?(from_status, to_status) do
    allowed = Map.get(@transitions, from_status, [])
    to_status in allowed
  end

  def validate_status_update(match, new_status) do
    cond do
      new_status not in @valid_statuses ->
        {:error, :invalid_status}
        
      not valid_transition?(match.status, new_status) ->
        {:error, :invalid_transition}
        
      true ->
        :ok
    end
  end
end
```

## Test Scenarios

### Happy Path Scenarios

**Scenario: Complete successful flow**
```
Given: Match starts in "pending" 
When: Status updated to "pending_visit"
And: Status updated to "visited"  
And: Status updated to "applied"
And: Status updated to "accepted"
Then: Match reaches terminal accepted state
```

**Scenario: Early discard**
```
Given: Match in "pending" state
When: Status updated to "discarded"
Then: Match reaches terminal discarded state
And: No further status updates are allowed
```

### Error Scenarios

**Scenario: Invalid transition**
```
Given: Match in "pending" state
When: Attempt to update status to "applied" (skipping steps)
Then: Request should fail with "invalid_transition" error
And: Match status should remain "pending"
```

**Scenario: Update terminal state**
```
Given: Match in "accepted" state
When: Attempt to update status to "discarded"
Then: Request should fail with "invalid_transition" error
And: Match status should remain "accepted"
```

**Scenario: Invalid status**
```
Given: Match in any valid state
When: Attempt to update status to "invalid_status"
Then: Request should fail with "invalid_status" error
And: Match status should remain unchanged
```

### Edge Cases

**Scenario: Rapid concurrent updates**
```
Given: Match in "pending" state
When: User A updates to "pending_visit" simultaneously with User B updating to "discarded"
Then: One update should succeed based on database ordering
And: The other update should either succeed if valid transition or fail gracefully
```

**Scenario: Status update with match deletion**
```
Given: Match in "pending_visit" state
When: User A removes their like (deleting the match)
And: User B simultaneously tries to update status to "visited"
Then: Status update should fail gracefully (match no longer exists)
```

## Database Schema Implications

### Match Table
```sql
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apartment_id UUID NOT NULL REFERENCES apartments(id),
  user_1_id UUID NOT NULL REFERENCES users(id),
  user_2_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  
  CHECK (status IN ('pending', 'pending_visit', 'visited', 'applied', 'accepted', 'rejected', 'discarded')),
  CHECK (user_1_id != user_2_id),
  UNIQUE (apartment_id, user_1_id, user_2_id)
);
```

### Status Change Audit Log (Future Enhancement)
```sql
CREATE TABLE match_status_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  from_status VARCHAR(20) NOT NULL,
  to_status VARCHAR(20) NOT NULL,
  changed_by_user_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
```

## API Error Responses

### Status Transition Errors

```json
{
  "error": {
    "code": "invalid_transition",
    "message": "Cannot transition from 'accepted' to 'discarded'",
    "details": {
      "current_status": "accepted",
      "attempted_status": "discarded", 
      "allowed_transitions": []
    }
  }
}
```

```json
{
  "error": {
    "code": "invalid_status",
    "message": "Status 'invalid_status' is not valid",
    "details": {
      "valid_statuses": ["pending", "pending_visit", "visited", "applied", "accepted", "rejected", "discarded"]
    }
  }
}
```

## Performance Considerations

- Status updates should be fast (< 50ms) as they're simple field updates
- Include database index on `matches.status` for filtering queries
- Consider caching status transition rules in application memory
- Status change audit logs should be written asynchronously if implemented
