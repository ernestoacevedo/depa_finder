# Depa Finder Constitution

## Core Principles

### I. Specification-First Development
All features begin with specifications that serve as the source of truth. Code serves specifications, not the other way around. Specifications must be:
- Precise, complete, and unambiguous enough to generate working systems
- Version controlled and branch-managed like code
- The authoritative documentation that drives implementation
- Living documents that evolve with the system

### II. Library-First Architecture  
Every feature must begin as a standalone library before being integrated into applications:
- Libraries must be self-contained and independently testable
- Clear, single-purpose interfaces required
- No organizational-only libraries without functional value
- Apps compose libraries, never contain business logic directly

### III. CLI Interface Mandate
Every library must expose its functionality through a command-line interface:
- Text in/out protocol: stdin/args → stdout, errors → stderr
- Support both JSON and human-readable formats
- All functionality must be inspectable and testable via CLI
- No hidden or CLI-inaccessible features

### IV. Test-First Imperative (NON-NEGOTIABLE)
Strict Test-Driven Development is mandatory:
- Tests written → User approved → Tests fail (Red) → Implementation (Green) → Refactor
- No implementation code before failing tests exist
- Contract tests mandatory before any integration
- Both unit and integration tests required for all features

### V. Monorepo Harmony
The monorepo supports multiple applications with shared principles:
- Consistent tooling and conventions across apps
- Shared libraries when appropriate, isolated when not
- Cross-app integration through well-defined contracts
- Independent deployment capabilities for each app

### VI. Simplicity and Anti-Abstraction
Start simple and add complexity only when proven necessary:
- Maximum 3 projects for initial implementation of any feature
- Use framework features directly rather than wrapping them
- Single model representation until proven inadequate
- No speculative or "might need" features

### VII. Integration-First Testing
Test in realistic environments, not artificial ones:
- Prefer real databases over mocks
- Use actual service instances over stubs
- Contract tests validate real API boundaries
- End-to-end scenarios test complete user journeys

### VIII. Observability Through Text
Everything must be debuggable and inspectable:
- Structured logging throughout the system
- All operations traceable through text output
- Clear error messages with actionable guidance
- Performance metrics accessible via CLI interfaces

## Technology Stack Requirements

### Backend (apps/api)
- **Language**: Elixir with OTP supervision trees
- **Framework**: Phoenix API (JSON-only, no views/templates)
- **Database**: PostgreSQL for production data, SQLite for development
- **Testing**: ExUnit with contract testing via ExVCR or similar
- **Package Manager**: Mix with hex.pm dependencies

### Frontend (apps/web)  
- **Language**: TypeScript with strict type checking
- **Framework**: React with functional components and hooks
- **Build Tool**: Vite for fast development and optimized production builds
- **Package Manager**: pnpm (configurable to npm/yarn via single config change)
- **Testing**: Vitest for unit/integration, Playwright for E2E
- **State Management**: Context + useReducer (avoid Redux until proven necessary)

### Shared Infrastructure
- **CI/CD**: GitHub Actions with matrix builds for both apps
- **Documentation**: Markdown with mermaid diagrams for architecture
- **Deployment**: Docker containers with health checks
- **Monitoring**: Structured JSON logs with correlation IDs

## Development Workflow

### Specification Process
1. All features begin with `/speckit.specify` command
2. Specifications reviewed and approved before implementation planning
3. Implementation plans created with `/speckit.plan` command
4. Executable tasks generated with `/speckit.tasks` command
5. No coding begins until specifications and plans are approved

### Testing Gates
All implementations must pass these gates in order:
1. **Contract Gate**: API contracts defined and validated
2. **Unit Gate**: All unit tests written and failing (Red phase)  
3. **Integration Gate**: Cross-component tests written and failing
4. **Implementation Gate**: Code written to make tests pass (Green phase)
5. **Refactor Gate**: Code cleaned and optimized while tests remain green

### Quality Assurance
- All code changes require passing test suites in both apps
- No direct commits to main branch - all changes via pull requests
- Automated testing in CI before merge approval
- Manual verification of E2E scenarios for user-facing changes

### Monorepo Coordination
- Apps can be developed and tested independently
- Shared contracts versioned and backwards-compatible when possible  
- Cross-app changes require coordination and testing of both apps
- Deployment can be independent unless shared components are modified

## Spec-Kit Integration

### Drivers Configuration
Two primary drivers support the monorepo architecture:

#### elixir_api Driver
- **Working Directory**: `apps/api`
- **Test Command**: `MIX_ENV=test mix test`
- **Spec Locations**: `apps/api/test/**/*_test.exs`, `apps/api/test/**/*_spec.exs`
- **Source Mapping**: `apps/api/lib` for implementation, `apps/api/test` for specs
- **Environment**: Requires PostgreSQL for integration tests

#### react_web Driver  
- **Working Directory**: `apps/web`
- **Test Command**: `pnpm test` or `pnpm vitest`
- **Spec Locations**: `apps/web/src/**/*.{test,spec}.{ts,tsx}`
- **Source Mapping**: `apps/web/src` for components and logic
- **Environment**: Node.js with pnpm package manager

### Spec Domains
Specifications are organized by domain and responsibility:

#### API Domain (elixir_api driver)
- **HTTP Contracts**: Request/response schemas, status codes, error formats
- **Business Logic**: Domain models, validation rules, business workflows  
- **Data Layer**: Database schemas, migrations, query patterns
- **Integration**: External service interactions, webhook handling

#### UI Domain (react_web driver)
- **Component Behavior**: Props, state management, event handling
- **User Interactions**: Form handling, navigation, accessibility
- **API Integration**: Service calls, error handling, loading states
- **Visual Presentation**: Layout, styling, responsive behavior

#### E2E Domain (both drivers)
- **User Journeys**: Complete workflows from UI to API to database
- **Cross-App Integration**: How frontend and backend work together
- **Performance**: Load times, response times, resource usage

### Workflows
Named workflows orchestrate testing across the monorepo:

#### fast_specs
Run unit-level specs only for rapid feedback:
- Backend: Unit tests excluding integration database tests
- Frontend: Component tests excluding API integration tests
- Execution time target: < 30 seconds

#### api_specs  
Run all backend specifications:
- All tests in `apps/api/test/` 
- Database integration tests included
- Contract validation tests
- Execution time target: < 2 minutes

#### web_specs
Run all frontend specifications:
- All tests in `apps/web/src/`
- Component integration tests included  
- Mock API integration tests
- Execution time target: < 1 minute

#### full_specs
Run complete test suite for CI:
- All backend specs (api_specs)
- All frontend specs (web_specs) 
- Cross-app E2E scenarios
- Performance validation tests
- Execution time target: < 5 minutes

#### slow_specs  
Run comprehensive E2E and performance tests:
- Real browser automation via Playwright
- Full database integration scenarios
- Load testing and performance benchmarks
- Security scanning and vulnerability tests
- Execution time: No limit, run nightly

## Governance

### Constitutional Authority
This constitution supersedes all other development practices and guidelines. All code reviews, architectural decisions, and feature implementations must verify compliance with these principles.

### Amendment Process  
Modifications to this constitution require:
- Explicit documentation of rationale for change
- Review and approval by project maintainers
- Backwards compatibility assessment for existing specifications
- Migration plan for any breaking changes

### Enforcement
- All pull requests must pass constitutional compliance checks
- Complexity exceeding these guidelines must be documented and justified
- Regular constitutional reviews ensure principles remain relevant
- Violations require remediation before merge approval

### Development Guidance
For day-to-day development decisions not covered by this constitution, refer to the living guidance documents in `.specify/memory/guidance.md` and individual spec documentation.

**Version**: 1.0.0 | **Ratified**: 2025-11-18 | **Last Amended**: 2025-11-18
