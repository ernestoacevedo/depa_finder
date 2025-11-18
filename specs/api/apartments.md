# API Specification: Apartments

## Overview
Endpoints for browsing and interacting with pre-scraped apartments.

## Endpoints

### GET /api/apartments

Lists apartments with filtering and pagination support.

**Query Parameters:**
- `page`: integer (default: 1)
- `per_page`: integer (default: 20, max: 50)
- `comuna`: string (filter by comuna)
- `min_price`: integer (minimum price in CLP)
- `max_price`: integer (maximum price in CLP)
- `min_bedrooms`: integer
- `max_bedrooms`: integer
- `min_area`: integer (minimum area in m²)
- `max_area`: integer (maximum area in m²)
- `exclude_liked`: boolean (default: false) - exclude apartments already liked by user

**Success Response (200):**
```json
{
  "data": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Hermoso departamento en Providencia",
      "price_clp": 850000,
      "area_m2": 65.5,
      "bedrooms": 2,
      "bathrooms": 1,
      "address": "Av. Providencia 2547",
      "comuna": "Providencia",
      "url": "https://www.portalinmobiliario.com/...",
      "source": "portalinmobiliario",
      "published_at": "2025-11-15T10:30:00Z",
      "user_liked": false
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total_count": 145,
    "total_pages": 8
  }
}
```

**Examples:**
```
GET /api/apartments?comuna=Providencia&min_bedrooms=2&exclude_liked=true
GET /api/apartments?page=2&per_page=10&max_price=1000000
```

**Edge Cases:**
- Invalid pagination: Returns 422 with validation errors
- No apartments match filters: Returns 200 with empty data array
- Unauthenticated user: Returns 401

### POST /api/apartments/:id/like

Creates a like for the specified apartment.

**Path Parameters:**
- `id`: UUID of the apartment

**Success Response (201):**
```json
{
  "data": {
    "id": "456e7890-e89b-12d3-a456-426614174001",
    "apartment_id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "789e0123-e89b-12d3-a456-426614174002",
    "created_at": "2025-11-18T14:25:00Z",
    "match_created": false
  }
}
```

**Success Response with Match (201):**
```json
{
  "data": {
    "id": "456e7890-e89b-12d3-a456-426614174001",
    "apartment_id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "789e0123-e89b-12d3-a456-426614174002",
    "created_at": "2025-11-18T14:25:00Z",
    "match_created": true,
    "match": {
      "id": "321e6574-e89b-12d3-a456-426614174003",
      "apartment_id": "123e4567-e89b-12d3-a456-426614174000",
      "status": "pending",
      "other_user": {
        "id": "987e6543-e89b-12d3-a456-426614174004",
        "nickname": "apartmentseeker42"
      },
      "created_at": "2025-11-18T14:25:00Z"
    }
  }
}
```

**Error Responses:**
- 404: Apartment not found
- 401: User not authenticated
- 422: User already liked this apartment

**Edge Cases:**
- Liking an apartment already liked by user: Returns 422
- Liking creates a match: Returns 201 with match_created: true
- Apartment doesn't exist: Returns 404

### DELETE /api/apartments/:id/like

Removes a user's like from an apartment.

**Path Parameters:**
- `id`: UUID of the apartment

**Success Response (204):**
Empty body

**Error Responses:**
- 404: Apartment not found OR user hasn't liked this apartment
- 401: User not authenticated

**Edge Cases:**
- Removing like when a match exists: Match should be deleted
- User hasn't liked the apartment: Returns 404

### GET /api/apartments/:id

Gets details for a specific apartment.

**Path Parameters:**
- `id`: UUID of the apartment

**Success Response (200):**
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "title": "Hermoso departamento en Providencia",
    "price_clp": 850000,
    "area_m2": 65.5,
    "bedrooms": 2,
    "bathrooms": 1,
    "address": "Av. Providencia 2547",
    "comuna": "Providencia",
    "url": "https://www.portalinmobiliario.com/...",
    "source": "portalinmobiliario",
    "published_at": "2025-11-15T10:30:00Z",
    "user_liked": true,
    "like_count": 3
  }
}
```

**Error Responses:**
- 404: Apartment not found
- 401: User not authenticated

## Validation Rules

### Pagination
- `page`: Must be positive integer
- `per_page`: Must be between 1 and 50

### Filters
- `min_price`, `max_price`: Must be positive integers
- `min_bedrooms`, `max_bedrooms`: Must be between 0 and 10
- `min_area`, `max_area`: Must be positive integers
- `comuna`: Must be non-empty string if provided

## Business Logic

### Like Creation
1. Validate apartment exists
2. Check if user already liked apartment
3. Create like record
4. Check if another user has liked the same apartment
5. If yes, create match with both users
6. Return like with match information if created

### Like Removal
1. Validate user has liked the apartment
2. Remove like record
3. If a match existed for this apartment + user combination, remove the match
4. Return success

## Performance Requirements
- Apartment listing should respond within 200ms for typical queries
- Like creation should respond within 100ms
- Database queries should use appropriate indexes on frequently filtered fields
