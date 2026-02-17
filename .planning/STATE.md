# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Developers can start a local mock HTTP server in one tap and test their client app against it immediately
**Current focus:** Phase 6 - Path Parameters & Wildcard Matching

## Current Position

Phase: 6 of 11 (Path Parameters & Wildcard Matching)
Plan: 2 of 2 in current phase (phase complete)
Status: Phase Complete
Last activity: 2026-02-17 - Completed 06-02-PLAN.md (MockServerEngine PathParamReplacer Integration)

Progress: [██████░░░░] 59%

## Performance Metrics

**Velocity:**
- Total plans completed: 16
- Average duration: 2 min
- Total execution time: 0.50 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2 | 4 min | 2 min |
| 02-server-engine-core | 3 | 7 min | 2.3 min |
| 03-endpoint-editor-ui | 3 | 6 min | 2 min |
| 04-request-log | 3 | 5 min | 1.7 min |
| 05-response-templates-delay | 3 | 5 min | 1.7 min |
| 06-path-parameters-wildcard-matching | 2 | 3 min | 1.5 min |

**Recent Trend:**
- Last 5 plans: 05-01 (2 min), 05-02 (1 min), 05-03 (2 min), 06-01 (2 min), 06-02 (1 min)
- Trend: Consistent

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Phase 1: Comprehensive depth (11 phases) derives natural delivery boundaries from 56 requirements across 8 categories
- Phase 2: Server engine uses custom actor (not MainActor) to avoid blocking UI during NWListener callbacks
- Phase 8: OpenAPI import is separate phase due to high complexity (circular $ref, YAML parsing, schema generation)
- Plan 01-01: HTTP methods stored as plain strings for SwiftData migration safety
- Plan 01-01: Dictionary fields persisted as JSON-encoded Data with computed property accessors
- Plan 01-01: ServerConfiguration uses defensive object(forKey:)==nil check for Bool defaults
- Plan 01-02: EndpointStore centralizes both endpoint CRUD and RequestLog insertion/pruning
- Plan 01-02: ServerStore uses didSet write-through for immediate UserDefaults persistence
- Plan 01-02: ProManager singleton injected via .environment() for global consistency with view testability
- Plan 02-01: HTTP request validation uses method uppercase check + path prefix '/' guard for malformed input rejection
- Plan 02-01: EndpointMatcher uses sorted() on allowed methods for deterministic 405 responses
- Plan 02-01: HTTPResponseBuilder sorts headers alphabetically for deterministic test assertions
- Plan 02-01: EndpointMatcher.EndpointData uses tuple typealias to decouple from SwiftData MockEndpoint model
- Plan 02-02: EndpointSnapshot Sendable struct carries endpoint config across actor boundary (MockEndpoint cannot cross)
- Plan 02-02: ObjectIdentifier used as dictionary key for NWConnection tracking (NWConnection is not Hashable)
- Plan 02-02: All NWListener/NWConnection callbacks use [weak self] + Task bridging for actor isolation
- Plan 02-02: 503 Service Unavailable returned when 50-connection limit exceeded
- Plan 02-02: HTTP/1.0 close-after-response: connection cancelled after every response send
- Plan 02-03: Port fallback tries configured port then +1 through +10 before reporting error
- Plan 02-03: Engine created fresh for each port attempt (NWListener cannot restart after cancel)
- Plan 02-03: 50ms sleep after start() gives NWListener time to transition to .ready state
- Plan 02-03: setOnRequestLogged setter added to engine actor for cross-actor callback assignment
- Plan 02-03: scenePhase .active only auto-starts if autoStart enabled AND server not already running
- Plan 03-01: Toggle uses Binding closure wrapper instead of @Bindable for read-only EndpointRowView
- Plan 03-01: Debounced sync uses Task cancellation pattern (300ms) to batch rapid mutations
- Plan 03-01: PRO limit alert uses basic Alert (full paywall deferred to Phase 9)
- Plan 03-02: @Bindable for EndpointEditorView enables direct two-way binding to @Model properties
- Plan 03-02: NavigationLink wraps EndpointRowView (avoids Hashable conformance issues with @Model)
- Plan 03-02: Auto-save on every field onChange with immediate SwiftData save + 300ms debounced engine sync
- Plan 03-03: JSONValidationResult private enum with valid/invalid/empty cases for clear badge state
- Plan 03-03: JSONSerialization with .prettyPrinted and .sortedKeys for deterministic JSON formatting
- Plan 03-03: Tuple array with UUID identity for ForEach over header pairs (tuples not Identifiable)
- Plan 03-03: Safe array subscript extension prevents index-out-of-bounds during binding updates
- Plan 04-01: Response headers stored as JSON-encoded Data with computed property (3rd instance of established pattern)
- Plan 04-01: CurlGenerator omits -X flag for GET (curl default) for cleaner output
- Plan 04-01: CurlGenerator sorts headers alphabetically for deterministic testable output
- Plan 04-01: Single quote escaping uses shell '\'' convention for cURL body content
- Plan 04-02: Toolbar NavigationLink on ContentView (not EndpointListView) avoids modifying EndpointListView's existing toolbar
- Plan 04-02: Placeholder Text destination for NavigationLink in log list (Plan 04-03 replaces with RequestDetailView)
- Plan 04-02: Filter AND logic: empty filter set means 'show all' for that category
- Plan 04-03: DisclosureGroup with @State expanded booleans for independent section collapse control
- Plan 04-03: Button label swaps text and icon on copy for inline 'Copied!' feedback (no overlay/toast needed)
- Plan 05-01: responseDelayMs default 0 ensures lightweight migration safety for existing MockEndpoint records
- Plan 05-01: BuiltInTemplates uses caseless enum pattern (matches HTTPMethod, EndpointMatcher convention)
- Plan 05-01: JSON bodies in templates use sorted keys with 2-space indentation matching JSONSerialization convention
- Plan 05-02: TemplatePickerView uses @Query for live custom template updates without manual refresh
- Plan 05-02: Sheet attached to EmptyView to avoid layout issues when view contains multiple Form Sections
- Plan 05-02: Binding(get:/set:) wrapper for Int-to-Double Slider conversion
- Plan 05-02: Group + opacity/allowsHitTesting pattern for PRO feature gating on form sections
- Plan 05-03: Task.sleep in actor method (non-blocking via reentrancy at suspension point)
- Plan 05-03: Delay applied after response build but before response time calculation
- Plan 05-03: Only matched endpoints have delay; 404/405 responses skip delay (server-generated, not endpoint-configured)
- Plan 06-01: matchPath uses .split(separator: "/") to normalize leading/trailing slashes consistently
- Plan 06-01: Wildcard * only valid at end of pattern (no mid-path wildcards)
- Plan 06-01: Specificity scoring: 0=exact, 1=parameterized, 2=wildcard; stable sort preserves array order within same score
- Plan 06-01: PathParamReplacer uses simple string replacement loop (no escaping, no JSON awareness)
- Plan 06-01: MockServerEngine applies token substitution after match, before response build
- Plan 06-02: No code changes needed: Plan 06-01 executor completed all 06-02 integration work as a Rule 3 deviation

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 06-02-PLAN.md (MockServerEngine PathParamReplacer Integration) - Phase 06 complete
Resume file: .planning/phases/06-path-parameters-wildcard-matching/06-02-SUMMARY.md
