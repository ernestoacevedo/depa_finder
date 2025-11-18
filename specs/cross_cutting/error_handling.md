# Cross-cutting Specification: Error Handling Patterns

## Overview
Consistent error handling strategies across the apartment matching application, covering API responses, frontend error boundaries, and user experience patterns.

## Error Categories

### API Error Types

**Authentication Errors (401)**
```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required",
    "details": {
      "reason": "token_missing" | "token_expired" | "token_invalid"
    }
  }
}
```

**Authorization Errors (403)**
```json
{
  "error": {
    "code": "forbidden", 
    "message": "Access denied",
    "details": {
      "reason": "not_match_participant" | "not_note_author" | "insufficient_permissions",
      "resource_type": "match" | "note" | "apartment",
      "resource_id": "uuid"
    }
  }
}
```

**Validation Errors (422)**
```json
{
  "error": {
    "code": "validation_failed",
    "message": "Input validation failed", 
    "details": {
      "field_errors": {
        "email": ["is required", "must be valid email"],
        "nickname": ["is too short", "contains invalid characters"],
        "password": ["must be at least 8 characters"]
      }
    }
  }
}
```

**Resource Errors (404)**
```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found",
    "details": {
      "resource_type": "apartment" | "match" | "note" | "user",
      "resource_id": "uuid"
    }
  }
}
```

**Conflict Errors (409)**
```json
{
  "error": {
    "code": "conflict",
    "message": "Resource conflict",
    "details": {
      "reason": "already_liked" | "match_already_exists" | "email_taken",
      "resource_type": "like" | "match" | "user"
    }
  }
}
```

**Rate Limiting Errors (429)**
```json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "Too many requests",
    "details": {
      "retry_after": 60,
      "limit": 100,
      "window": 3600,
      "reset_at": "2025-11-18T21:00:00Z"
    }
  }
}
```

**Server Errors (500)**
```json
{
  "error": {
    "code": "internal_server_error",
    "message": "An unexpected error occurred",
    "details": {
      "reference_id": "error_ref_12345",
      "timestamp": "2025-11-18T20:30:00Z"
    }
  }
}
```

## Backend Error Handling Patterns

### Elixir/Phoenix Error Handling

**Controller Error Handling:**
```elixir
defmodule DepaFinderAPI.ApartmentController do
  use DepaFinderAPI, :controller
  use DepaFinderAPI.ErrorHandler

  def like(conn, %{"id" => apartment_id}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, apartment} <- Apartments.get_apartment(apartment_id),
         {:ok, result} <- Likes.create_like(user.id, apartment_id) do
      render(conn, "like_created.json", result: result)
    else
      {:error, :not_found} ->
        render_error(conn, 404, "apartment_not_found", "Apartment not found")
        
      {:error, :already_liked} ->
        render_error(conn, 409, "already_liked", "You have already liked this apartment")
        
      {:error, changeset} ->
        render_validation_errors(conn, changeset)
        
      {:error, reason} ->
        render_error(conn, 500, "internal_error", "An unexpected error occurred", %{reference: generate_error_ref()})
    end
  end
end
```

**Domain Layer Error Handling:**
```elixir
defmodule DepaFinder.Likes do
  def create_like(user_id, apartment_id) do
    Multi.new()
    |> Multi.run(:validate_apartment, fn _repo, _changes ->
      case Apartments.get_apartment(apartment_id) do
        nil -> {:error, :apartment_not_found}
        apartment -> {:ok, apartment}
      end
    end)
    |> Multi.run(:validate_existing_like, fn _repo, %{validate_apartment: apartment} ->
      case Repo.get_by(Like, user_id: user_id, apartment_id: apartment.id) do
        nil -> {:ok, :no_existing_like}
        _like -> {:error, :already_liked}
      end
    end)
    |> Multi.insert(:like, fn %{validate_apartment: apartment} ->
      %Like{}
      |> Like.changeset(%{user_id: user_id, apartment_id: apartment.id})
    end)
    |> Multi.run(:check_match, fn _repo, %{like: like} ->
      MatchMaker.check_and_create_match(like)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{like: like, check_match: match_result}} -> 
        {:ok, %{like: like, match: match_result}}
      {:error, _step, reason, _changes} -> 
        {:error, reason}
    end
  rescue
    exception ->
      Logger.error("Error creating like: #{inspect(exception)}")
      {:error, :internal_error}
  end
end
```

**Error Handler Module:**
```elixir
defmodule DepaFinderAPI.ErrorHandler do
  @moduledoc "Common error handling patterns"
  
  def render_error(conn, status, code, message, details \\ %{}) do
    conn
    |> put_status(status)
    |> render("error.json", %{
      code: code,
      message: message,
      details: details
    })
  end

  def render_validation_errors(conn, changeset) do
    field_errors = 
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    render_error(conn, 422, "validation_failed", "Input validation failed", %{
      field_errors: field_errors
    })
  end

  def generate_error_ref() do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end
end
```

### Database Error Handling

**Connection and Query Errors:**
```elixir
defmodule DepaFinder.DatabaseErrorHandler do
  def handle_db_error({:error, %Postgrex.Error{postgres: %{code: :unique_violation}}}) do
    {:error, :already_exists}
  end

  def handle_db_error({:error, %DBConnection.ConnectionError{}}) do
    Logger.error("Database connection error")
    {:error, :database_unavailable}
  end

  def handle_db_error({:error, %Ecto.Query.CastError{} = error}) do
    Logger.warning("Query parameter casting error: #{inspect(error)}")
    {:error, :invalid_parameters}
  end

  def handle_db_error(error) do
    Logger.error("Unexpected database error: #{inspect(error)}")
    {:error, :database_error}
  end
end
```

## Frontend Error Handling Patterns

### React Error Boundaries

**Main Application Error Boundary:**
```typescript
interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
  errorInfo: ErrorInfo | null
}

class AppErrorBoundary extends Component<PropsWithChildren, ErrorBoundaryState> {
  constructor(props: PropsWithChildren) {
    super(props)
    this.state = { hasError: false, error: null, errorInfo: null }
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    this.setState({ errorInfo })
    
    // Log error to monitoring service
    console.error('App Error Boundary caught error:', error, errorInfo)
    
    // Send to error tracking service
    if (process.env.NODE_ENV === 'production') {
      // Sentry, LogRocket, etc.
    }
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h1>Something went wrong</h1>
          <p>We're sorry! An unexpected error occurred.</p>
          <button onClick={() => window.location.reload()}>
            Reload Page
          </button>
          {process.env.NODE_ENV === 'development' && (
            <details>
              <summary>Error Details</summary>
              <pre>{this.state.error?.stack}</pre>
            </details>
          )}
        </div>
      )
    }

    return this.props.children
  }
}
```

**Component-Specific Error Boundaries:**
```typescript
// For apartment feed specific errors
const ApartmentFeedErrorBoundary: FC<PropsWithChildren> = ({ children }) => (
  <ErrorBoundary
    FallbackComponent={ApartmentFeedErrorFallback}
    onError={(error, errorInfo) => {
      console.error('Apartment Feed Error:', error)
      // Track apartment feed specific errors
    }}
  >
    {children}
  </ErrorBoundary>
)

const ApartmentFeedErrorFallback: FC<FallbackProps> = ({ error, resetErrorBoundary }) => (
  <div className="apartment-feed-error">
    <h2>Unable to load apartments</h2>
    <p>There was a problem loading the apartment feed.</p>
    <button onClick={resetErrorBoundary}>Try Again</button>
    <button onClick={() => window.location.href = '/'}>Go Home</button>
  </div>
)
```

### API Error Handling

**HTTP Client Error Interceptor:**
```typescript
interface ApiError {
  code: string
  message: string
  details: Record<string, any>
  status: number
}

class ApiClient {
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: '/api',
      timeout: 10000
    })

    this.setupInterceptors()
  }

  private setupInterceptors() {
    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        const apiError = this.parseApiError(error)
        
        // Handle specific error types globally
        switch (apiError.code) {
          case 'unauthorized':
            this.handleUnauthorized(apiError)
            break
          case 'rate_limit_exceeded':
            this.handleRateLimit(apiError)
            break
          default:
            // Let component handle specific errors
        }

        return Promise.reject(apiError)
      }
    )
  }

  private parseApiError(error: AxiosError): ApiError {
    if (error.response?.data?.error) {
      return {
        ...error.response.data.error,
        status: error.response.status
      }
    }

    // Network errors, timeouts, etc.
    if (error.code === 'ECONNABORTED') {
      return {
        code: 'timeout',
        message: 'Request timed out',
        details: {},
        status: 0
      }
    }

    if (!error.response) {
      return {
        code: 'network_error',
        message: 'Network error occurred',
        details: {},
        status: 0
      }
    }

    return {
      code: 'unknown_error',
      message: 'An unknown error occurred',
      details: {},
      status: error.response.status
    }
  }

  private handleUnauthorized(error: ApiError) {
    // Clear auth tokens and redirect to login
    localStorage.removeItem('auth_token')
    window.location.href = '/login'
  }

  private handleRateLimit(error: ApiError) {
    // Show global rate limit notification
    toast.error(`Rate limit exceeded. Try again in ${error.details.retry_after} seconds.`)
  }
}
```

**React Query Error Handling:**
```typescript
// Global error handling for React Query
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error: ApiError) => {
        // Don't retry on client errors (4xx)
        if (error.status >= 400 && error.status < 500) {
          return false
        }
        // Retry up to 3 times for server errors
        return failureCount < 3
      },
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
    },
    mutations: {
      retry: false, // Don't retry mutations by default
    }
  }
})

// Component-level error handling
const useApartments = (filters: ApartmentFilters) => {
  return useQuery({
    queryKey: ['apartments', filters],
    queryFn: () => apiClient.getApartments(filters),
    onError: (error: ApiError) => {
      // Component-specific error handling
      switch (error.code) {
        case 'validation_failed':
          toast.error('Invalid search filters')
          break
        case 'network_error':
          toast.error('Connection problem. Please check your internet.')
          break
        default:
          toast.error('Failed to load apartments')
      }
    }
  })
}
```

### Form Error Handling

**Form Validation and Error Display:**
```typescript
interface FormErrors {
  [field: string]: string[]
}

const useFormErrorHandler = () => {
  const [errors, setErrors] = useState<FormErrors>({})

  const handleApiError = (error: ApiError) => {
    if (error.code === 'validation_failed' && error.details.field_errors) {
      setErrors(error.details.field_errors)
    } else {
      toast.error(error.message)
    }
  }

  const clearFieldError = (field: string) => {
    setErrors(prev => ({
      ...prev,
      [field]: []
    }))
  }

  const hasFieldError = (field: string) => {
    return errors[field]?.length > 0
  }

  const getFieldError = (field: string) => {
    return errors[field]?.[0] || ''
  }

  return {
    errors,
    handleApiError,
    clearFieldError,
    hasFieldError,
    getFieldError
  }
}

// Usage in form components
const LoginForm: FC = () => {
  const { handleApiError, hasFieldError, getFieldError, clearFieldError } = useFormErrorHandler()
  const loginMutation = useMutation({
    mutationFn: login,
    onError: handleApiError
  })

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        name="email"
        onChange={() => clearFieldError('email')}
        className={hasFieldError('email') ? 'error' : ''}
      />
      {hasFieldError('email') && (
        <span className="error-message">{getFieldError('email')}</span>
      )}
    </form>
  )
}
```

## User Experience Error Patterns

### Toast Notifications

**Error Toast Types:**
```typescript
interface ToastConfig {
  type: 'error' | 'warning' | 'info' | 'success'
  message: string
  duration?: number
  action?: {
    label: string
    handler: () => void
  }
}

const errorToasts = {
  network: {
    type: 'error',
    message: 'Connection problem. Please check your internet.',
    action: { label: 'Retry', handler: () => window.location.reload() }
  },
  
  unauthorized: {
    type: 'warning', 
    message: 'Please log in to continue',
    action: { label: 'Login', handler: () => navigate('/login') }
  },

  apartmentNotFound: {
    type: 'error',
    message: 'This apartment is no longer available'
  },

  likeFailed: {
    type: 'error',
    message: 'Failed to like apartment',
    action: { label: 'Try again', handler: () => retryLike() }
  }
}
```

### Inline Error States

**Component Error States:**
```typescript
const ApartmentCard: FC<ApartmentCardProps> = ({ apartment, onLike }) => {
  const [likeState, setLikeState] = useState<'idle' | 'loading' | 'error'>('idle')
  const [errorMessage, setErrorMessage] = useState<string>('')

  const handleLike = async () => {
    setLikeState('loading')
    setErrorMessage('')
    
    try {
      await onLike(apartment.id)
      setLikeState('idle')
    } catch (error: ApiError) {
      setLikeState('error')
      setErrorMessage(getErrorMessage(error))
    }
  }

  const getErrorMessage = (error: ApiError) => {
    switch (error.code) {
      case 'already_liked':
        return 'You have already liked this apartment'
      case 'apartment_not_found':
        return 'This apartment is no longer available'
      default:
        return 'Failed to like apartment'
    }
  }

  return (
    <div className="apartment-card">
      {/* Apartment content */}
      
      <button 
        onClick={handleLike}
        disabled={likeState === 'loading'}
        className={`like-button ${likeState}`}
      >
        {likeState === 'loading' ? 'Liking...' : 'Like'}
      </button>
      
      {likeState === 'error' && (
        <div className="error-inline">
          <span className="error-message">{errorMessage}</span>
          <button onClick={handleLike} className="retry-button">
            Try again
          </button>
        </div>
      )}
    </div>
  )
}
```

### Graceful Degradation

**Offline State Handling:**
```typescript
const useOnlineStatus = () => {
  const [isOnline, setIsOnline] = useState(navigator.onLine)

  useEffect(() => {
    const handleOnline = () => setIsOnline(true)
    const handleOffline = () => setIsOnline(false)

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  return isOnline
}

const ApartmentFeed: FC = () => {
  const isOnline = useOnlineStatus()
  const { data: apartments, error, isLoading } = useApartments()

  if (!isOnline) {
    return (
      <div className="offline-state">
        <h2>You're offline</h2>
        <p>Please check your internet connection and try again.</p>
        {apartments && (
          <>
            <p>Here are the apartments you were viewing:</p>
            <ApartmentList apartments={apartments} readonly />
          </>
        )}
      </div>
    )
  }

  // Normal online rendering
  return <ApartmentList apartments={apartments} />
}
```

## Error Monitoring and Logging

### Structured Logging

**Backend Logging:**
```elixir
defmodule DepaFinder.ErrorLogger do
  require Logger

  def log_api_error(error, request_context) do
    Logger.error("API Error", %{
      error_code: error.code,
      error_message: error.message,
      user_id: request_context.user_id,
      endpoint: request_context.endpoint,
      request_id: request_context.request_id,
      timestamp: DateTime.utc_now()
    })
  end

  def log_database_error(error, query_context) do
    Logger.error("Database Error", %{
      error_type: error.__struct__,
      query: query_context.query,
      params: query_context.params,
      duration_ms: query_context.duration,
      timestamp: DateTime.utc_now()
    })
  end
end
```

**Frontend Error Tracking:**
```typescript
interface ErrorContext {
  userId?: string
  component: string
  action: string
  url: string
  userAgent: string
  timestamp: string
}

const logError = (error: Error, context: ErrorContext) => {
  const errorData = {
    message: error.message,
    stack: error.stack,
    context,
    level: 'error'
  }

  // Send to monitoring service
  if (process.env.NODE_ENV === 'production') {
    // Send to Sentry, LogRocket, etc.
  } else {
    console.error('Frontend Error:', errorData)
  }
}
```

### Health Monitoring

**System Health Checks:**
```elixir
defmodule DepaFinderAPI.HealthController do
  def check(conn, _params) do
    checks = %{
      database: check_database(),
      redis: check_redis(),
      external_apis: check_external_apis()
    }
    
    overall_status = if Enum.all?(checks, fn {_key, status} -> status == "ok" end) do
      "healthy"
    else
      "unhealthy"
    end
    
    status_code = if overall_status == "healthy", do: 200, else: 503
    
    conn
    |> put_status(status_code)
    |> json(%{status: overall_status, checks: checks, timestamp: DateTime.utc_now()})
  end

  defp check_database() do
    try do
      DepaFinder.Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end
  end
end
```
