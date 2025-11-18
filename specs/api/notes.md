# API Specification: Notes

## Overview
Endpoints for managing notes within matches. Notes allow matched users to coordinate their apartment hunting process.

## Endpoints

### POST /api/matches/:match_id/notes

Creates a new note in a match.

**Path Parameters:**
- `match_id`: UUID of the match

**Request Body:**
```json
{
  "body": "I called the agent and they're available for a viewing tomorrow at 2pm"
}
```

**Success Response (201):**
```json
{
  "data": {
    "id": "876e5432-e89b-12d3-a456-426614174007",
    "body": "I called the agent and they're available for a viewing tomorrow at 2pm",
    "author": {
      "id": "789e0123-e89b-12d3-a456-426614174002",
      "nickname": "homehunter23",
      "is_me": true
    },
    "match_id": "321e6574-e89b-12d3-a456-426614174003",
    "created_at": "2025-11-18T19:15:00Z",
    "updated_at": "2025-11-18T19:15:00Z"
  }
}
```

**Error Responses:**
- 404: Match not found
- 403: User is not part of this match
- 401: User not authenticated
- 422: Validation errors (empty body, too long, etc.)

### GET /api/matches/:match_id/notes

Lists all notes for a match (included in match detail, but available as separate endpoint).

**Path Parameters:**
- `match_id`: UUID of the match

**Query Parameters:**
- `page`: integer (default: 1)
- `per_page`: integer (default: 50, max: 100)

**Success Response (200):**
```json
{
  "data": [
    {
      "id": "654e3210-e89b-12d3-a456-426614174005",
      "body": "I can visit this weekend if you're available!",
      "author": {
        "id": "789e0123-e89b-12d3-a456-426614174002",
        "nickname": "homehunter23",
        "is_me": true
      },
      "match_id": "321e6574-e89b-12d3-a456-426614174003",
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
      "match_id": "321e6574-e89b-12d3-a456-426614174003",
      "created_at": "2025-11-18T17:20:00Z",
      "updated_at": "2025-11-18T17:20:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 50,
    "total_count": 2,
    "total_pages": 1
  }
}
```

**Error Responses:**
- 404: Match not found
- 403: User is not part of this match
- 401: User not authenticated

### PATCH /api/notes/:id

Updates an existing note.

**Path Parameters:**
- `id`: UUID of the note

**Request Body:**
```json
{
  "body": "I called the agent and they're available for a viewing tomorrow at 3pm (updated time)"
}
```

**Success Response (200):**
```json
{
  "data": {
    "id": "876e5432-e89b-12d3-a456-426614174007",
    "body": "I called the agent and they're available for a viewing tomorrow at 3pm (updated time)",
    "author": {
      "id": "789e0123-e89b-12d3-a456-426614174002",
      "nickname": "homehunter23",
      "is_me": true
    },
    "match_id": "321e6574-e89b-12d3-a456-426614174003",
    "created_at": "2025-11-18T19:15:00Z",
    "updated_at": "2025-11-18T19:45:00Z"
  }
}
```

**Error Responses:**
- 404: Note not found
- 403: User is not the author of this note OR not part of the match
- 401: User not authenticated
- 422: Validation errors

### DELETE /api/notes/:id

Deletes a note.

**Path Parameters:**
- `id`: UUID of the note

**Success Response (204):**
Empty body

**Error Responses:**
- 404: Note not found
- 403: User is not the author of this note OR not part of the match
- 401: User not authenticated

**Business Logic:**
- Only the author of a note can delete it
- Deletion is permanent and cannot be undone

## Validation Rules

### Note Body
- Must be present and non-empty
- Must be between 1 and 1000 characters
- Basic sanitization to prevent XSS

### Edit Time Window
- Notes can be edited within 24 hours of creation
- After 24 hours, notes become read-only
- Deletion is always allowed by the author

### Rate Limiting
- Users can create maximum 50 notes per match per day
- API should return 429 (Too Many Requests) if limit exceeded

## Business Logic

### Note Creation
1. Validate user is part of the match
2. Validate note content
3. Create note record
4. Update match's `updated_at` timestamp (for "last activity")
5. Return note with author information

### Note Editing
1. Validate user is author of the note
2. Validate user is still part of the match
3. Check edit time window (24 hours)
4. Update note content and `updated_at`
5. Update match's `updated_at` timestamp

### Note Access Control
- Only users who are part of the match can view notes
- Only note authors can edit/delete their notes
- Notes are ordered chronologically (oldest first)

### Note Deletion Cascade
- When a match is deleted, all notes are automatically deleted
- When a user account is deleted, their notes remain but author is anonymized

## Performance Requirements
- Note creation should respond within 100ms
- Note listing should respond within 150ms
- Note updates should respond within 50ms

## Examples

### Creating a coordination note
```
POST /api/matches/321e6574-e89b-12d3-a456-426614174003/notes
{
  "body": "I found the agent's WhatsApp: +56 9 1234 5678. Should I contact them about viewing times?"
}
```

### Following up on apartment status
```
POST /api/matches/321e6574-e89b-12d3-a456-426614174003/notes  
{
  "body": "Update: I visited the apartment today. The kitchen is smaller than expected, but overall it's nice. What do you think about the price?"
}
```

### Editing a note with new information
```
PATCH /api/notes/876e5432-e89b-12d3-a456-426614174007
{
  "body": "Update: I visited the apartment today. The kitchen is smaller than expected, but overall it's nice. What do you think about the price? EDIT: Just found out they're also including parking!"
}
```
