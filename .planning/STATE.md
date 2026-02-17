# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Developers can start a local mock HTTP server in one tap and test their client app against it immediately
**Current focus:** Phase 11 - Accessibility

## Current Position

Phase: 11 of 11 (Accessibility)
Plan: 1 of 3 in current phase
Status: In Progress
Last activity: 2026-02-17 - Completed 11-01-PLAN.md (Theme Accessibility Foundations)

Progress: [████████████████████████████] 96%

## Performance Metrics

**Velocity:**
- Total plans completed: 28
- Average duration: 2 min
- Total execution time: 0.87 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 2 | 4 min | 2 min |
| 02-server-engine-core | 3 | 7 min | 2.3 min |
| 03-endpoint-editor-ui | 3 | 6 min | 2 min |
| 04-request-log | 3 | 5 min | 1.7 min |
| 05-response-templates-delay | 3 | 5 min | 1.7 min |
| 06-path-parameters-wildcard-matching | 2 | 3 min | 1.5 min |
| 07-import-export-collections | 3 | 6 min | 2 min |
| 08-openapi-import | 3 | 8 min | 2.7 min |
| 09-pro-features | 2 | 3 min | 1.5 min |
| 10-navigation-polish | 3 | 6 min | 2 min |
| 11-accessibility | 1 | 1 min | 1 min |

**Recent Trend:**
- Last 5 plans: 09-02 (2 min), 10-01 (2 min), 10-02 (2 min), 10-03 (2 min), 11-01 (1 min)
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
- Plan 07-01: CollectionExporter/CollectionImporter use caseless enum pattern (matches BuiltInTemplates, CurlGenerator convention)
- Plan 07-01: Export format uses "mockpad-collection" identifier and version 1 for future compatibility
- Plan 07-01: Duplicate detection is case-insensitive on path and method
- Plan 07-01: ImportError conforms to Equatable for testable error assertions with Swift Testing
- Plan 07-02: CollectionFilterChipsView uses accent color for active chip (collections have no per-item color semantics)
- Plan 07-02: Filter chips placed above List in VStack to avoid interfering with ForEach move/delete
- Plan 07-02: Picker with .menu style for compact collection assignment in editor
- Plan 07-02: Inline "New Collection" creation resets field state after assignment
- Plan 07-03: ShareLink conditionally shown when isPro and endpoints available, otherwise disabled placeholder button
- Plan 07-03: Menu with Divider separates export/share (PRO) from import (free) actions
- Plan 07-03: Import preview sheet onDismiss triggers engine sync for imported endpoints
- Plan 07-03: ExportedEndpoint uniqueID combines httpMethod + path for ForEach identity
- Plan 08-01: Line-by-line parser with indentation tracking (not tokenizer/AST) for minimal YAML subset
- Plan 08-01: Flow collections ([a,b] and {a:b}) delegated to JSONSerialization instead of hand-rolled parser
- Plan 08-01: Comment stripping requires space before # to avoid false positives in URLs
- Plan 08-01: Multiline blocks (| and >) collected by indent level relative to parent
- Plan 08-01: ConversionError.invalidYAML for empty input; NSNull for empty YAML values
- Plan 08-02: Dictionary tree ([String: Any]) for OpenAPI parsing instead of Codable DTOs -- handles $ref, optional fields, extension keys
- Plan 08-02: MockResponseGenerator.resolveRef is static (not private) to share $ref resolution with OpenAPIParser for response object refs
- Plan 08-02: Response status code priority: 200 > 201 > 204 > first 2xx > default matches real-world OpenAPI conventions
- Plan 08-02: allOf merges properties from all sub-schemas; oneOf/anyOf uses first option only
- Plan 08-02: Path parameter conversion via Swift Regex for {param} -> :param transformation
- Plan 08-02: Global warnings for webhooks, securitySchemes, schema composition; per-endpoint warnings for callbacks and security
- Plan 08-03: Checkbox selection via Button with checkmark.square.fill/square images (toggleStyle(.checkbox) not available on iOS)
- Plan 08-03: Parallel Bool array for selections rather than mutating DiscoveredEndpoint (struct immutability in ForEach)
- Plan 08-03: Reuse existing importError/showImportError state for OpenAPI parse errors (single error alert pattern)
- Plan 08-03: OpenAPI import is PRO-only feature (menu item gated, not just endpoint limit)
- Plan 09-01: PurchaseState enum nested inside ProManager for encapsulated purchase flow state
- Plan 09-01: Transaction listener started in init() for immediate refund/purchase detection
- Plan 09-01: checkEntitlements() revokes isPro if no valid entitlement found (handles refunds)
- Plan 09-01: Verification uses try? payloadValue to skip failed verifications gracefully
- Plan 09-02: Single showPaywall state replaces 3 separate PRO alert states in EndpointListView
- Plan 09-02: Overlay tap target (Color.clear + contentShape + onTapGesture) catches taps on dimmed PRO sections
- Plan 09-02: PRO lock in TemplatePickerView wrapped in Button for direct paywall trigger
- Plan 09-02: Paywall sheet in CollectionFilterChipsView attached to ScrollView inside conditional block
- Plan 10-01: SampleEndpointGenerator uses caseless enum pattern matching BuiltInTemplates, CurlGenerator convention
- Plan 10-01: ServerStatusBarView uses RoundedRectangle button background with 0.15 opacity for subtle start/stop tint
- Plan 10-01: SettingsView uses Binding(get:/set:) wrapper for ServerStore properties (consistent with existing pattern)
- Plan 10-01: Ecosystem links use itms-apps:// URL scheme for direct App Store opening
- Plan 10-01: EmptyStateView auto-starts server after creating sample endpoints for instant gratification
- Plan 10-02: localhostOnly defaults to true (security-first: only localhost connections by default)
- Plan 10-02: NWParameters.requiredLocalEndpoint binds to IPv4 loopback when localhostOnly is true
- Plan 10-02: acceptLocalOnly toggled alongside requiredLocalEndpoint for defense-in-depth
- Plan 10-03: horizontalSizeClass .regular triggers iPad NavigationSplitView, .compact triggers iPhone TabView
- Plan 10-03: iPad settings presented as sheet from toolbar gear button (not a sidebar item)
- Plan 10-03: iPad detail column wraps RequestLogListView in NavigationStack for push navigation
- Plan 10-03: scenePhase and ProManager .task remain at ContentView root level above layout conditional
- Plan 10-03: SidebarView uses List(selection:) with .tag(persistentModelID) for endpoint selection
- Plan 11-01: methodDelete adjusted to #FF6B6B (luminance ~0.28) for 0.06 gap from PATCH (~0.22)
- Plan 11-01: serverStopped and status5xx updated to match new DELETE red for visual consistency
- Plan 11-01: @ScaledMetric relativeTo: .largeTitle for 48pt/42pt icons, .title for 40pt icons

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-17
Stopped at: Completed 11-01-PLAN.md (Theme Accessibility Foundations)
Resume file: .planning/phases/11-accessibility/11-01-SUMMARY.md
