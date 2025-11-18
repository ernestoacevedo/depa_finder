# API Specification: Matches

## Overview
Endpoints for managing matches between users who both liked the same apartment.

## Endpoints

### GET /api/matches

Lists all matches for the authenticated user.

**Query Parameters:**
- `page`: integer (default: 1)
- `per_page`: integer (default: 20, max: 50)
- `status`: string (filter by match status)
- `sort`: string (options: "newest", "oldest", "last_activity") (default: "last_activity")

**Success Response (200):**
```json
{
  "data": [
    {
      "id": "321e6574-e89b-12d3-a456-426614174003",
      "apartment": {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "title": "Hermoso departamento en Providencia",
        "price_clp": 850000,
        "area_m2": 65.5,
        "bedrooms": 2,
        "bathrooms": 1,
        "address": "Av. Providencia 2547",
        "comuna": "Providencia"
      },
      "other_user": {
        "id": "987e6543-e89b-12d3-a456-426614174004",
        "nickname": "apartmentseeker42"
      },
      "status": "pending_visit",
      "note_count": 3,
      "last_activity_at": "2025-11-18T16:45:00Z",
      "created_at": "2025-11-18T14:25:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total_count": 7,
    "total_pages": 1
  }
}
```

**Examples:**
```
GET /api/matches?status=pending_visit&sort=newest
GET /api/matches?page=1&per_page=10
```

**Error Responses:**
- 401: User not authenticated
- 422: Invalid query parameters

### GET /api/matches/:id

Gets detailed information about a specific match.

**Path Parameters:**
- `id`: UUID of the match

**Success Response (200):**
```json
{
  "data": {
    "id": "321e6574-e89b-12d3-a456-426614174003",
    "apartment": {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Hermoso departamento en Providencia",
      "price_clp": 850000,
      "area_m2": 65.5,
      "bedrooms": 2,
      "bathrooms": 1,
      "address": "Av. Providencia 2547",
      "comuna": "Providencia",
      "url": "https://www.portalinmobiliario.com/..."
    },
    "other_user": {
      "id": "987e6543-e89b-12d3-a456-426614174004",
      "nickname": "apartmentseeker42",
      "joined_at": "2025-10-15T09:20:00Z"
    },
    "status": "pending_visit",
    "created_at": "2025-11-18T14:25:00Z",
    "updated_at": "2025-11-18T16:45:00Z",
    "notes": [
      {
        "id": "654e3210-e89b-12d3-a456-426614174005",
        "body": "I can visit this weekend if you're available!",
        "author": {
          "id": "789e0123-e89b-12d3-a456-426614174002",
          "nickname": "homehunter23",
          "is_me": true
        },
        "created_at": "2025-11-18T16:45:00Z",
        "updated_at": "2025-11-18T16:45:00Z"
      },
      {
        "id": "765e4321-e89b-12d3-a456-426614174006",
        "body": "Perfect! Saturday morning works for me. Should we contact the agent together?",
        "author": {
          "id": "987e6543-e89b-12d3-a456-426614174004",
          "nickname": "apartmentseeker42",
          "is_me": false
        },
        "created_at": "2025-11-18T17:20:00Z",
        "updated_at": "2025-11-18T17:20:00Z"
      }
    ]
  }
}
```

**Error Responses:**
- 404: Match not found
- 403: User is not part of this match
- 401: User not authenticated

### PATCH /api/matches/:id

Updates the status of a match.

**Path Parameters:**
- `id`: UUID of the match

**Request Body:**
```json
{
  "status": "visited"
}
```

**Success Response (200):**
```json
{
  "data": {
    "id": "321e6574-e89b-12d3-a456-426614174003",
    "status": "visited",
    "updated_at": "2025-11-18T18:30:00Z"
  }
}
```

**Error Responses:**
- 404: Match not found
- 403: User is not part of this match
- 401: User not authenticated
- 422: Invalid status transition

**Valid Status Values:**
- `pending` - Initial state when match is created
- `pending_visit` - Users are planning to visit the apartment
- `visited` - Users have visited the apartment
- `applied` - Users have applied for the apartment
- `rejected` - Application was rejected or users decided not to proceed
- `discarded` - Users are no longer interested

### DELETE /api/matches/:id

Removes a match (when one user removes their like).

**Path Parameters:**
- `id`: UUID of the match

**Success Response (204):**
Empty body

**Error Responses:**
- 404: Match not found
- 403: User is not part of this match
- 401: User not authenticated

**Business Logic:**
- This endpoint is automatically called when a user removes a like for an apartment they matched on
- All notes associated with the match are also deleted

## Validation Rules

### Status Updates
- Status must be one of the valid enum values
- Status transitions must follow the state machine rules (see domain/state_transitions.md)
- Both users in a match can update the status

### Pagination
- `page`: Must be positive integer
- `per_page`: Must be between 1 and 50
- `sort`: Must be one of allowed values

## Business Logic

### Match Creation
- Automatically created when second user likes an apartment
- Initial status is always "pending"
- Both users become participants

### Match Access Control
- Only the two users involved in a match can view/modify it
- Users cannot see matches they are not part of

### Match Deletion
- Occurs when either user removes their like for the apartment
- All associated notes are cascade deleted
- Cannot be undone

## Performance Requirements
- Match listing should respond within 150ms
- Match detail should respond within 100ms
- Status updates should respond within 50ms
