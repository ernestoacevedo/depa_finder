# API Specification: Authentication & Authorization

## Overview
Authentication and authorization endpoints and patterns for the apartment matching application.

## Authentication Strategy
- JWT-based authentication
- Tokens expire after 24 hours
- Refresh tokens valid for 30 days
- Stateless authentication (no server-side sessions)

## Endpoints

### POST /api/auth/register

Creates a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "nickname": "apartmenthunter",
  "password": "securepassword123"
}
```

**Success Response (201):**
```json
{
  "data": {
    "user": {
      "id": "789e0123-e89b-12d3-a456-426614174002",
      "email": "user@example.com",
      "nickname": "apartmenthunter",
      "created_at": "2025-11-18T20:30:00Z"
    },
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "def50200a1b2c3d4e5f6...",
    "expires_at": "2025-11-19T20:30:00Z"
  }
}
```

**Error Responses:**
- 422: Validation errors (email taken, weak password, etc.)

**Validation Rules:**
- Email must be valid format and unique
- Nickname must be 3-30 characters, alphanumeric + underscore only, unique
- Password must be at least 8 characters

### POST /api/auth/login

Authenticates an existing user.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Success Response (200):**
```json
{
  "data": {
    "user": {
      "id": "789e0123-e89b-12d3-a456-426614174002",
      "email": "user@example.com",
      "nickname": "apartmenthunter",
      "created_at": "2025-10-15T14:20:00Z"
    },
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "def50200a1b2c3d4e5f6...",
    "expires_at": "2025-11-19T20:30:00Z"
  }
}
```

**Error Responses:**
- 401: Invalid credentials
- 422: Validation errors (malformed email, etc.)

### POST /api/auth/refresh

Refreshes an access token using a refresh token.

**Request Body:**
```json
{
  "refresh_token": "def50200a1b2c3d4e5f6..."
}
```

**Success Response (200):**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "new50200a1b2c3d4e5f6...",
    "expires_at": "2025-11-19T21:00:00Z"
  }
}
```

**Error Responses:**
- 401: Invalid or expired refresh token

### POST /api/auth/logout

Invalidates the current refresh token.

**Request Body:**
```json
{
  "refresh_token": "def50200a1b2c3d4e5f6..."
}
```

**Success Response (200):**
```json
{
  "message": "Successfully logged out"
}
```

**Error Responses:**
- 401: Invalid refresh token

### GET /api/auth/me

Gets current user information.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Success Response (200):**
```json
{
  "data": {
    "id": "789e0123-e89b-12d3-a456-426614174002",
    "email": "user@example.com",
    "nickname": "apartmenthunter",
    "created_at": "2025-10-15T14:20:00Z",
    "stats": {
      "likes_count": 45,
      "matches_count": 3,
      "active_matches_count": 2
    }
  }
}
```

**Error Responses:**
- 401: Invalid or expired token

### PATCH /api/auth/me

Updates current user information.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Request Body:**
```json
{
  "nickname": "newhuntername"
}
```

**Success Response (200):**
```json
{
  "data": {
    "id": "789e0123-e89b-12d3-a456-426614174002",
    "email": "user@example.com",
    "nickname": "newhuntername",
    "created_at": "2025-10-15T14:20:00Z",
    "updated_at": "2025-11-18T21:15:00Z"
  }
}
```

**Error Responses:**
- 401: Invalid or expired token
- 422: Validation errors (nickname taken, invalid format)

## Authorization Patterns

### Protected Endpoints
All endpoints except `/api/auth/register`, `/api/auth/login`, and `/api/auth/refresh` require authentication.

**Authentication Header:**
```
Authorization: Bearer <access_token>
```

### Resource Access Rules

#### Apartments
- **Read**: Any authenticated user can view apartments
- **Like/Unlike**: Only authenticated users can like apartments they don't own

#### Matches  
- **Read**: Only users who are part of the match
- **Update**: Only users who are part of the match
- **Delete**: Only users who are part of the match (via removing like)

#### Notes
- **Read**: Only users who are part of the match
- **Create**: Only users who are part of the match
- **Update**: Only the author of the note + within edit window
- **Delete**: Only the author of the note

### JWT Token Structure
```json
{
  "sub": "789e0123-e89b-12d3-a456-426614174002",
  "email": "user@example.com", 
  "nickname": "apartmenthunter",
  "iat": 1700340600,
  "exp": 1700427000,
  "type": "access"
}
```

## Security Considerations

### Password Requirements
- Minimum 8 characters
- Must contain at least one letter and one number
- Passwords are hashed using bcrypt with cost factor 12

### Rate Limiting
- Login attempts: 5 per minute per IP
- Registration: 3 per minute per IP  
- Token refresh: 10 per minute per user
- General API: 100 requests per minute per user

### Token Security
- Access tokens expire after 24 hours
- Refresh tokens expire after 30 days
- Tokens are invalidated on logout
- No sensitive data in JWT payload

## Error Response Format

All authentication errors follow this format:

```json
{
  "error": {
    "code": "invalid_credentials",
    "message": "The provided credentials are invalid",
    "details": {}
  }
}
```

**Common Error Codes:**
- `invalid_credentials` - Wrong email/password
- `token_expired` - Access token has expired
- `token_invalid` - Malformed or invalid token
- `refresh_token_invalid` - Refresh token is invalid/expired
- `validation_failed` - Input validation errors
- `email_taken` - Email already registered
- `nickname_taken` - Nickname already taken

## Examples

### Complete Registration Flow
```bash
# Register new user
curl -X POST /api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","nickname":"newuser","password":"password123"}'

# Use returned token for authenticated requests
curl -X GET /api/apartments \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Token Refresh Flow
```bash
# When access token expires
curl -X POST /api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"def50200a1b2c3d4e5f6..."}'
```
