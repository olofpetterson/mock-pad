# Project Research Summary

**Project:** MockPad
**Domain:** Native iOS local HTTP mock server
**Researched:** 2026-02-16
**Confidence:** HIGH

## Executive Summary

MockPad is a native iOS HTTP mock server built on Apple's Network framework (NWListener). Research shows this domain has well-established desktop solutions (WireMock, Mockoon, Postman), but zero native mobile competitors. The technical approach is proven: NWListener for TCP listening on localhost, manual HTTP/1.1 parsing (no frameworks needed), SwiftUI for iPad-first UI with Split View as the killer feature, and SwiftData for endpoint/log persistence. The one external dependency is Yams for YAML OpenAPI import, which is justified given YAML's parsing complexity.

The primary risk is concurrency: bridging NWListener's DispatchQueue callbacks to a custom actor (for server logic) and MainActor (for UI state) requires careful design from day one. Secondary risks include lifecycle management (iOS suspends backgrounded apps, breaking the listener) and HTTP parsing edge cases (TCP framing, pipelined requests, chunked encoding). These are all addressable with established patterns: actor-to-MainActor bridging via Task callbacks, scenePhase observation for lifecycle, and state-machine HTTP parsing with comprehensive tests.

The recommended roadmap prioritizes foundation-first: data models and stores, then the HTTP engine core (parser/builder/matcher/server actor), then endpoint editor UI, then request logging, and finally OpenAPI import and PRO features. This order ensures critical concurrency architecture is correct before UI layers are added, and defers high-complexity features (OpenAPI) until the core loop is validated.

## Key Findings

### Recommended Stack

**Core technologies:**
- **Network framework (NWListener)** — TCP listener for localhost HTTP server. Apple-native, zero dependencies, no entitlements required for localhost binding. This is the only sanctioned way to run a TCP server on iOS.
- **SwiftUI (iOS 26+)** — NavigationSplitView for iPad 3-column layout, TextEditor with AttributedString for JSON syntax highlighting.
- **SwiftData (iOS 26+)** — Persistence for endpoints, request logs, collections. Native ORM with #Index support for fast log queries.
- **StoreKit 2** — PRO tier non-consumable purchase (3 free endpoints, $5.99 unlimited).
- **Swift Testing** — Struct-based test suites (@Test, #expect).

**Supporting libraries:**
- **Yams 6.2.1+** — YAML parsing for OpenAPI import. This is the sole external dependency, justified because Swift has no native YAML parser and the format is too complex to hand-roll reliably.

**Key technical decisions:**
- Manual HTTP parsing (not NWProtocolFramer or third-party servers) — NWProtocolFramer adds boilerplate without benefit for low-volume mock servers; third-party servers conflict with zero-dependency goal.
- Custom actor for MockServerEngine (not @MainActor) — NWListener callbacks arrive on DispatchQueue; must not block main thread.
- Native AttributedString JSON highlighting (not external library) — JSON has a tiny grammar; custom tokenizer is ~100 lines vs. pulling in a multi-language highlighter.
- Custom Codable structs for OpenAPI (not swift-openapi-generator) — Generator is for code generation, not spec reading; custom structs cover needed subset.

### Expected Features

**Must have (table stakes):**
- Endpoint CRUD (path, method, status code, response body, custom headers) — core interaction loop
- Multiple HTTP methods per path — REST semantics expected
- JSON response body editor with syntax highlighting — JSON dominates APIs
- Custom response headers — essential for Content-Type, auth, caching
- Response delay simulation — test loading states and timeouts
- Multiple response variants per endpoint — test success/error paths
- Path parameter support (/users/:id) — real APIs use this universally
- Live request log — developers need confirmation the mock is being hit
- Server start/stop with port display — basic server control
- Export/import endpoint configs — sharing and backup
- PRO paywall (3 free, $5.99 unlimited) — monetization from day one
- iPad multitasking support — the killer use case (split view: mock + client app)

**Should have (competitive):**
- OpenAPI v3 import — generate endpoints from specs, massive time-saver
- Response templates library — pre-built patterns for common responses
- Request detail drill-down — tap log entry to see full headers/body/timing
- Endpoint grouping/folders — organize 10+ endpoints by feature area
- Bonjour/mDNS advertisement — discover server on local network

**Defer (v2+):**
- Dynamic response templating (Handlebars/Faker) — high complexity, niche need
- Record & playback (proxy mode) — requires HTTP proxy, SSL cert handling, massive scope
- Stateful scenarios (WireMock-style state machines) — power-user feature, tiny segment
- HTTPS support — unnecessary for localhost dev mocking
- GraphQL mocking — different protocol, specialized tooling

### Architecture Approach

**Component structure:** Three-layer architecture with clear isolation boundaries. UI layer (MainActor, SwiftUI views) observes stores (MainActor, @Observable classes holding SwiftData ModelContext). Stores bridge to engine layer (custom actor wrapping NWListener/NWConnection on dedicated DispatchQueue). Services are stateless caseless enums (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher, OpenAPIImporter) callable from any isolation context.

**Major components:**
1. **MockServerEngine (actor)** — NWListener lifecycle, connection accept/close, request dispatch, response send. Custom actor (not MainActor) to avoid blocking UI during network I/O.
2. **ServerStore (@Observable, MainActor)** — Bridge engine state to UI, manage request log buffer, server lifecycle via scenePhase. Owns MockServerEngine instance.
3. **EndpointStore (@Observable, MainActor)** — CRUD for MockEndpoint models via SwiftData, query endpoints for matcher, manage sort order.
4. **HTTPRequestParser/Builder/Matcher (stateless enums)** — Pure functions for HTTP parsing, response building, endpoint matching. Zero state, trivially testable.
5. **OpenAPIImporter (enum)** — Parse OpenAPI 3.x JSON/YAML specs, generate MockEndpoint array. Uses Yams for YAML, Foundation JSONDecoder for JSON.

**Key patterns:**
- Actor-to-MainActor bridging via `Task { @MainActor in }` callbacks — engine pushes request logs to ServerStore for UI updates
- Stateless enum services for all pure logic — no mutable state, no setup/teardown, zero mocks in tests
- NWListener on dedicated DispatchQueue, callbacks hop into actor isolation via `Task { await self.method() }`
- SwiftData #Index on RequestLog.timestamp and .path for fast log queries at scale

### Critical Pitfalls

1. **NWListener port stuck after cancel (error 48: "Address already in use")** — After `.cancel()`, creating a new NWListener on the same port fails. `allowLocalEndpointReuse` is broken on real devices (FB8658821). **Avoid:** Track all NWConnection instances, cancel them before cancelling the listener. Create a new NWListener instance to restart (never reuse cancelled instances). Implement fallback port strategy. Test on real device, not just Simulator (Simulator masks this bug).

2. **Server dies silently when app backgrounds** — iOS suspends apps 10-30 seconds after backgrounding. NWListener stops accepting connections but reports no error. iPad Split View complicates this: app may go `.inactive` but server continues. **Avoid:** Stop NWListener on `.background` and `.inactive` scenePhase transitions. Restart (new instance) on `.active`. Show "Server Paused" banner when not active. Test on iPad in Split View/Slide Over/Stage Manager.

3. **Concurrency deadlock: actor + NWListener DispatchQueue + MainActor** — NWListener callbacks arrive on DispatchQueue. Server logic on custom actor. UI on MainActor. Bridging incorrectly causes data races, deadlocks, or UI freezes. **Avoid:** Make MockServerEngine an explicit `actor` (not @MainActor). In NWListener callbacks, use `Task { await self.handleEvent() }` to hop onto actor. Publish state to UI via callbacks wrapped in `Task { @MainActor in }`. Never pass NWConnection across actor boundaries (not Sendable). Design actor boundaries before writing any server logic.

4. **Incomplete HTTP parsing (TCP framing ignorance)** — `NWConnection.receive()` delivers arbitrary TCP chunks, not complete HTTP requests. One request may arrive in multiple chunks, or multiple pipelined requests in one chunk. **Avoid:** Implement stateful HTTP/1.1 parser that accumulates data across `receive()` calls. Parse headers first, then read Content-Length bytes for body. Handle chunked transfer encoding or reject with 411. Set max header size (8KB) and max body size (10MB). Always call `receive()` recursively after processing. Test with pipelined requests and large bodies.

5. **OpenAPI circular $ref infinite loops** — OpenAPI specs use `$ref` for schema reuse and `allOf`/`oneOf`/`anyOf` for inheritance. Circular refs like `Schema A -> allOf[Schema B] -> $ref Schema A` are valid for recursive data structures but cause infinite parser loops. **Avoid:** Implement $ref resolution with visited-set for cycle detection. Resolve $ref lazily (on demand) not eagerly (all at once). Cap recursion depth (20 levels). Test with Stripe API spec (deeply nested allOf) and self-referencing schemas.

6. **YAML parsing complexity without Yams** — Swift has no built-in YAML parser. YAML 1.2 spec is extremely complex (anchors, aliases, tags, multi-line strings). Hand-rolling a parser will fail on real-world OpenAPI specs. **Avoid:** Accept Yams as a dependency (zero transitive deps, Swift 6 compatible). Alternatively, accept JSON-only for v1 and document YAML limitation prominently. Never attempt a full YAML 1.2 parser from scratch.

## Implications for Roadmap

Based on research, suggested phase structure follows dependency order and risk reduction strategy:

### Phase 1: Foundation (Data Models + Stores)
**Rationale:** All other components depend on the data model (MockEndpoint, RequestLog, EndpointCollection, ServerConfiguration). EndpointStore provides CRUD that engine, UI, and import all need. Must be built first. No external dependencies yet.

**Delivers:** SwiftData models with correct relationships and indexes, EndpointStore with CRUD operations, ServerStore scaffold (without engine), ProManager scaffold.

**Addresses:** Table-stakes persistence for endpoints and logs.

**Avoids:** SwiftData anti-pattern (storing headers as [String: String] directly — use Data with computed property).

**Testing:** Model validation, EndpointStore CRUD with in-memory SwiftData container.

### Phase 2: HTTP Engine Core
**Rationale:** This is the spine of the app. Parser/builder/matcher are stateless and independently testable. MockServerEngine wires them together with NWListener. This phase validates the hardest technical risks: concurrency bridging, NWListener lifecycle, HTTP parsing edge cases.

**Delivers:** HTTPRequestParser (stateless enum), HTTPResponseBuilder (stateless enum), EndpointMatcher (stateless enum), MockServerEngine (actor), ServerStore integration with engine lifecycle.

**Addresses:** Core table-stakes feature (server start/stop, request handling, response serving).

**Avoids:**
- Pitfall 1 (port stuck) — cancel all connections before listener
- Pitfall 2 (background suspension) — scenePhase observation, stop on background
- Pitfall 3 (concurrency deadlock) — actor boundaries designed correctly from start
- Pitfall 4 (HTTP parsing) — stateful parser with comprehensive tests

**Testing:** Parser tests (~25 covering edge cases), builder tests (~15), matcher tests (~20), engine integration test (start/stop/restart on device), scenePhase lifecycle test.

**Research flag:** Standard patterns. NWListener well-documented, no additional research needed.

### Phase 3: Endpoint Editor UI
**Rationale:** With models, store, and engine in place, wire up the core UI loop. Users can create endpoints, start the server, send requests via curl, see responses. This validates the full stack end-to-end before adding complexity.

**Delivers:** EndpointListView, EndpointEditorView, ResponseEditorView, HeaderEditorView, ServerControlView, iPad NavigationSplitView layout (3-column), iPhone TabView layout.

**Addresses:** Table-stakes endpoint CRUD, JSON editor, custom headers, status code selection, server control UI, iPad multitasking (automatic with NavigationSplitView).

**Avoids:** No special pitfalls — standard SwiftUI patterns.

**Testing:** Manual testing (create endpoint, start server, curl request, verify response). UI tests for endpoint creation flow.

**Research flag:** Standard SwiftUI patterns, no research needed.

### Phase 4: Request Log
**Rationale:** Request log consumes the `requestLogs` array from ServerStore, which is populated by engine callback. Needs the engine running to generate logs. Extends the core loop with observability.

**Delivers:** RequestLogView (live-updating list), RequestLogRowView, RequestDetailView (drill-down), RequestFilterBar, live streaming from ServerStore, log pruning (max 1000 entries).

**Addresses:** Table-stakes request log, competitive drill-down feature.

**Avoids:** Performance trap (unbounded log growth) — ring buffer with 1000 entry cap.

**Testing:** Send requests, verify log entries appear in real-time, verify pruning at 1001 entries, verify drill-down shows full headers/body.

**Research flag:** Standard patterns, no research needed.

### Phase 5: Response Delay + Path Params
**Rationale:** Low-complexity additions to existing endpoint model and matcher. Response delay uses `Task.sleep`. Path params extend EndpointMatcher with :param extraction. Both are table-stakes features that add immediate testing value.

**Delivers:** Response delay field in endpoint editor (milliseconds), Task.sleep in MockServerEngine before sending response, path parameter syntax (/users/:id) in endpoint path, path param extraction in EndpointMatcher, path param injection into response body templates.

**Addresses:** Table-stakes delay simulation and path parameters.

**Avoids:** No special pitfalls.

**Testing:** Endpoint with 2000ms delay shows timing in log, path /users/:id matches /users/123 and extracts id=123.

**Research flag:** Standard patterns, no research needed.

### Phase 6: Multiple Response Variants
**Rationale:** Table-stakes feature that enables testing success/error paths without creating duplicate endpoints. Extends MockEndpoint model with variants array and adds variant picker to editor UI.

**Delivers:** Response variant model (array of response configs per endpoint), variant selector in endpoint editor, manual variant switching in list view, active variant indicator.

**Addresses:** Table-stakes multiple responses per endpoint.

**Avoids:** Anti-pattern of stateful scenarios (WireMock state machines) — keep it simple with manual selection.

**Testing:** Endpoint with 3 variants (200 success, 404 not found, 500 error), switch active variant, send request, verify correct response.

**Research flag:** Standard patterns, no research needed.

### Phase 7: Export/Import + Collections
**Rationale:** Table-stakes sharing feature and organizational feature for PRO tier. Export/import uses JSON serialization. Collections are a grouping model.

**Delivers:** ExportService (endpoints -> JSON), ImportService (JSON -> endpoints), share sheet integration, EndpointCollection model, collection picker in endpoint editor, collection filter in list view.

**Addresses:** Table-stakes export/import, competitive endpoint grouping.

**Avoids:** Anti-pattern of cloud sync (Postman workspaces) — file-based only for v1.

**Testing:** Export 5 endpoints, share via AirDrop, import on another device, verify all fields intact. Create collection, add endpoints, filter list by collection.

**Research flag:** Standard patterns, no research needed.

### Phase 8: JSON Syntax Highlighting + Templates
**Rationale:** Competitive features that enhance productivity. JSON highlighting is custom AttributedString tokenizer (~100 lines). Templates are pre-built endpoint configs.

**Delivers:** JSONTokenizer (enum with static tokenize method), AttributedString rendering in response body editor, 10-15 built-in ResponseTemplate configs (auth token, paginated list, error envelope, empty array, 401/403/404 errors), TemplatePickerView, template insertion into endpoint editor.

**Addresses:** Competitive JSON editor, competitive templates library.

**Avoids:** Anti-pattern of external highlighting library (overkill for JSON-only).

**Testing:** Edit JSON with syntax errors, verify highlighting updates, select template, verify response body populated.

**Research flag:** Standard patterns (AttributedString well-documented, JSON grammar trivial), no research needed.

### Phase 9: OpenAPI Import
**Rationale:** High-value competitive feature but high complexity (circular $ref, YAML parsing). Deferred until core loop is validated. Only phase that adds external dependency (Yams).

**Delivers:** Yams SPM dependency, OpenAPIImporter (enum with parse/resolve/$ref handling), JSONSchemaGenerator (enum with schema -> mock JSON), YAMLParser integration, OpenAPIImportView (file picker), ImportPreviewView (checkboxes for endpoint selection), import result report (X imported, Y skipped, Z warnings).

**Addresses:** Competitive OpenAPI import, massive time-saver for API-first teams.

**Avoids:**
- Pitfall 5 (circular $ref) — visited-set cycle detection, lazy resolution, recursion cap
- Pitfall 6 (YAML complexity) — Yams dependency accepted

**Testing:** Import Petstore spec (baseline), Stripe API spec (deeply nested allOf), GitHub API spec (polymorphic oneOf), self-referencing schema (circular $ref), verify no hangs/crashes, verify reasonable mock data generated.

**Research flag:** NEEDS RESEARCH. OpenAPI $ref resolution, allOf/oneOf/anyOf handling, and JSON Schema mock generation have edge cases. Plan to run `/gsd:research-phase` for detailed guidance on schema traversal and Yams API.

### Phase 10: PRO Features (StoreKit + Paywall)
**Rationale:** Monetization layer wraps existing features. Needs endpoint editor (Phase 3), collections (Phase 7), import (Phase 9) to gate. Can be built in parallel with Phase 9 if desired.

**Delivers:** ProManager StoreKit 2 integration, Product.products() fetch, purchase flow, endpoint creation limit enforcement (3 free, unlimited PRO), paywall UI overlay, restore purchases, PRO badge in UI.

**Addresses:** Monetization, PRO tier gating.

**Avoids:** No special pitfalls — StoreKit 2 is well-documented.

**Testing:** Create 3 endpoints as free user, 4th triggers paywall, purchase PRO, create 4th endpoint succeeds, restore purchases on new device.

**Research flag:** Standard StoreKit 2 patterns, no research needed.

### Phase 11: Bonjour Advertisement (Optional)
**Rationale:** Competitive differentiator but not required for launch. Enables discovery on local network. Can be added post-launch if user demand warrants.

**Delivers:** NWListener Bonjour service advertisement (_http._tcp), service name configuration, NSLocalNetworkUsageDescription in Info.plist (may trigger permission dialog), mDNS browsing test app.

**Addresses:** Competitive Bonjour discovery feature.

**Avoids:** Permission dialog friction — bind to localhost by default, Bonjour is opt-in PRO feature.

**Testing:** Advertise server, discover from another device via Bonjour browser, connect and send request.

**Research flag:** NEEDS RESEARCH. Bonjour triggers local network permission dialog on iOS 14+ under certain conditions. Plan to research NSLocalNetworkUsageDescription requirements and permission flow.

### Phase 12: Polish + App Store Prep
**Rationale:** Final polish, accessibility, empty states, App Store assets, TestFlight.

**Delivers:** Empty state views (no endpoints, no logs), "Create Sample API" quick-start flow, VoiceOver labels, dynamic type support, App Store screenshots, description, privacy policy, TestFlight build.

**Addresses:** User onboarding, accessibility, App Store readiness.

**Avoids:** No special pitfalls.

**Testing:** VoiceOver navigation, dynamic type at largest size, empty state flows.

**Research flag:** Standard patterns, no research needed.

### Phase Ordering Rationale

- **Foundation first (Phase 1):** All layers depend on models and stores. Must be correct before anything else.
- **Engine before UI (Phase 2 before Phase 3):** Validates hardest technical risks (concurrency, NWListener lifecycle) before investing in UI polish. Engine tests are faster to run than UI tests.
- **Core loop early (Phases 1-4):** Establish create endpoint -> start server -> send request -> see log flow by Phase 4. This is the MVP. Everything after is enhancement.
- **Complexity deferred (Phase 9 OpenAPI, Phase 11 Bonjour):** High-complexity features come after core is validated. OpenAPI and Bonjour are the only phases flagged for additional research.
- **PRO last (Phase 10):** Wraps existing features, so all gateable features must be complete first.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 9 (OpenAPI Import):** Complex domain. $ref resolution, allOf/oneOf/anyOf composition, JSON Schema traversal, Yams API usage. Plan to run `/gsd:research-phase OpenAPI $ref resolution strategies` and `/gsd:research-phase JSON Schema mock data generation patterns`.
- **Phase 11 (Bonjour):** Local network permission dialog mechanics unclear. Plan to research NSLocalNetworkUsageDescription triggers and permission flow.

**Phases with standard patterns (skip research-phase):**
- **Phases 1-8, 10, 12:** SwiftData, NWListener, SwiftUI, StoreKit 2 are all well-documented with established patterns. Research completed in this project research phase covers these areas sufficiently.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | NWListener is Apple-native with extensive WWDC coverage and forum posts. SwiftUI/SwiftData/StoreKit 2 are mainstream. Yams is the de facto Swift YAML library. Only Yams is external, and it's well-maintained. |
| Features | HIGH | Competitor analysis across 6 major mock server tools (Postman, WireMock, Mockoon, Prism, json-server, MockServer) provides clear picture of table-stakes vs. differentiators. Feature dependencies mapped. |
| Architecture | HIGH | Actor-to-MainActor bridging, stateless enum services, NWListener on DispatchQueue are proven patterns from prior projects and Apple guidance (WWDC25 session on structured concurrency + Network framework). SwiftData ModelContext Sendable limitations well-documented. |
| Pitfalls | HIGH (lifecycle/concurrency), MEDIUM (OpenAPI) | NWListener lifecycle gotchas verified across multiple high-confidence sources (Apple forums, Open Radar, Swift forums). Concurrency patterns established from WWDC and prior projects. OpenAPI $ref handling is MEDIUM confidence — edge cases exist but cycle detection strategies are documented. |

**Overall confidence:** HIGH

### Gaps to Address

- **OpenAPI $ref resolution edge cases:** Research identified circular refs as a pitfall, but specific resolution strategies for `allOf`/`oneOf`/`anyOf` composition need validation during Phase 9 planning. Stripe API spec will be the validation test case.

- **Bonjour permission dialog triggers:** Research shows NSLocalNetworkUsageDescription is required, but conditions that trigger the permission dialog on iOS 14+ are not fully clear. Some sources say localhost binding avoids the dialog, others say Bonjour advertisement always triggers it. Needs validation on real device during Phase 11.

- **HTTP chunked transfer encoding:** Research shows chunked encoding is part of HTTP/1.1 spec, but whether to support it in v1 is TBD. Defer to Phase 2 testing — if clients send chunked bodies and parser fails, add support; if not observed in practice, reject with 411 and defer to v2.

- **SwiftData migration strategy:** Models will evolve post-launch. Research did not cover migration patterns. Plan to add lightweight migration attributes during Phase 1 and document migration strategy before first App Store release.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: NWListener, NWConnection, NWProtocolFramer, SwiftData, StoreKit 2, Swift Testing
- WWDC Sessions: WWDC18-715 (Introducing Network.framework), WWDC19-713 (Advances in Networking), WWDC24 (SwiftData #Index), WWDC25-250 (Structured Concurrency with Network Framework)
- Apple Developer Forums: NWListener lifecycle threads (130132, 129452, 772637, 766433), concurrency threads (719402)
- Apple TN3179: Understanding Local Network Privacy
- RFC 9112: HTTP/1.1 specification
- OpenAPI 3.x Specification (official schema)

### Secondary (MEDIUM confidence)
- ko9.org: Simple Web Server in Swift (NWListener implementation patterns)
- rderik.com: Building a server-client with Network Framework (recursive receive pattern)
- Always Right Institute: NWHTTPProtocol analysis (NWProtocolFramer evaluation)
- Swift Forums: NWListener lifecycle thread (39354 — cancel/restart gotcha)
- Hacking with Swift: SwiftData performance optimization (#Index, fetchLimit, externalStorage)
- Jacob Bartlett: High Performance SwiftData (background ModelContainer, Sendable patterns)
- Donnywals.com: MainActor isolation patterns (Swift 6.2)
- Avanderlee.com: Approachable Concurrency (nonisolated patterns)
- Jesse Squires: SwiftUI scenePhase issues (lifecycle gotchas)
- pb33f.io: Circular References in OpenAPI (cycle detection strategies)
- Competitor documentation: Postman Mock Server, WireMock, Mockoon, Prism, json-server, MockServer (feature analysis)

### Tertiary (LOW confidence)
- Open Radar FB8658821: allowLocalEndpointReuse bug (single source, not confirmed by Apple, but consistent with field reports)

---
*Research completed: 2026-02-16*
*Ready for roadmap: yes*
