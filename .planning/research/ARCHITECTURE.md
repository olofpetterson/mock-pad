# Architecture Research

**Domain:** iOS local HTTP mock server (NWListener-based)
**Researched:** 2026-02-16
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
                              MockPad Architecture
 ===========================================================================

 UI Layer (MainActor)
 ---------------------------------------------------------------------------
  iPad: NavigationSplitView (3-col)    iPhone: TabView + NavigationStack
  +-----------+  +----------------+    +------------+
  | Server    |  | Endpoint       |    | Endpoints  |
  | ControlV  |  | EditorView     |    | Tab        |
  +-----------+  +----------------+    +------------+
  | Endpoint  |  | Request        |    | Log Tab    |
  | ListView  |  | LogView        |    +------------+
  +-----------+  +----------------+    | Settings   |
                 | RequestDetail  |    | Tab        |
                 +----------------+    +------------+

 Store Layer (MainActor, @Observable)
 ---------------------------------------------------------------------------
  +---------------+  +----------------+  +---------------+
  | ServerStore   |  | EndpointStore  |  | ProManager    |
  | - isRunning   |  | - CRUD ops     |  | - isPro       |
  | - port        |  | - SwiftData    |  | - StoreKit 2  |
  | - requestLogs |  | - collections  |  | - gating      |
  | - serverURL   |  +----------------+  +---------------+
  | - error       |
  +-------+-------+
          |
          | owns + bridges via Task { @MainActor }
          |
 Engine Layer (actor, off-main-thread)
 ---------------------------------------------------------------------------
  +-------+----------+
  | MockServerEngine |----> onRequestReceived callback
  | - NWListener     |
  | - connections[]  |
  | - DispatchQueue  |
  +--+--------+------+
     |        |
     v        v
 Service Layer (stateless enums, nonisolated)
 ---------------------------------------------------------------------------
  +-----------------+  +--------------------+  +------------------+
  | HTTPRequest     |  | HTTPResponse       |  | Endpoint         |
  | Parser          |  | Builder            |  | Matcher          |
  | (Data->Parsed)  |  | (Config->Data)     |  | (Req->Endpoint)  |
  +-----------------+  +--------------------+  +------------------+

 Import/Export Layer (stateless enums)
 ---------------------------------------------------------------------------
  +-----------------+  +--------------------+  +-----------------+
  | OpenAPI         |  | JSONSchema         |  | Export          |
  | Importer        |  | Generator          |  | Service         |
  +-----------------+  +--------------------+  +-----------------+
  | YAMLParser      |
  +-----------------+

 Data Layer (SwiftData + UserDefaults)
 ---------------------------------------------------------------------------
  +---------------+  +------------+  +--------------------+
  | MockEndpoint  |  | RequestLog |  | EndpointCollection |
  | (@Model)      |  | (@Model)   |  | (@Model)           |
  +---------------+  +------------+  +--------------------+
                         ServerConfiguration (UserDefaults)
                         ResponseTemplate (bundled JSON + UserDefaults)
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **MockServerEngine** | TCP listener lifecycle, connection accept/close, request dispatch, response send | Swift `actor` wrapping `NWListener` + `Set<NWConnection>` on dedicated `DispatchQueue` |
| **HTTPRequestParser** | Parse raw TCP bytes into structured HTTP request (method, path, headers, body) | Stateless `enum` with `static func parse(data:) -> ParsedRequest?` |
| **HTTPResponseBuilder** | Serialize status code + headers + body into HTTP/1.1 response bytes | Stateless `enum` with `static func build(statusCode:headers:body:) -> Data` |
| **EndpointMatcher** | Match incoming request path+method against configured endpoints, extract path params | Stateless `enum` with `static func match(request:endpoints:) -> MatchResult` |
| **ServerStore** | Bridge engine state to UI, manage request log buffer, server lifecycle via scenePhase | `@Observable final class` on MainActor, owns `MockServerEngine` instance |
| **EndpointStore** | CRUD for MockEndpoint models, query endpoints for matcher, manage sort order | `@Observable final class` on MainActor, uses SwiftData `ModelContext` |
| **ProManager** | StoreKit 2 purchase state, feature gating (3 free endpoints), paywall trigger | `@Observable final class`, singleton pattern |
| **OpenAPIImporter** | Parse OpenAPI 3.x JSON/YAML specs, generate MockEndpoint array | Stateless `enum` with `static func importSpec(from:) throws -> ImportResult` |
| **JSONSchemaGenerator** | Generate realistic mock JSON from OpenAPI schema definitions | Stateless `enum` with `static func generate(from:schemas:) -> String` |
| **YAMLParser** | Minimal YAML-to-Dictionary parser for OpenAPI YAML files | Stateless `enum` with `static func parse(_:) -> Any?` |
| **ExportService** | Serialize endpoint collections to JSON for sharing via iOS share sheet | Stateless `enum` with `static func export(endpoints:) -> Data` |

## Recommended Project Structure

```
MockPad/MockPad/
├── App/
│   ├── MockPadApp.swift              # @main, ModelContainer, environment injection
│   ├── ServerStore.swift             # @Observable: server lifecycle, request log buffer
│   └── EndpointStore.swift           # @Observable: CRUD for endpoints via SwiftData
│
├── Models/
│   ├── MockEndpoint.swift            # @Model: path, method, response config, collection
│   ├── RequestLog.swift              # @Model: logged incoming request + response status
│   ├── EndpointCollection.swift      # @Model: named group of endpoints
│   ├── ServerConfiguration.swift     # Value type backed by UserDefaults
│   └── ResponseTemplate.swift        # Codable: built-in + custom templates
│
├── Services/
│   ├── MockServerEngine.swift        # actor: NWListener, connection management
│   ├── HTTPRequestParser.swift       # enum: raw Data -> ParsedRequest
│   ├── HTTPResponseBuilder.swift     # enum: config -> HTTP response Data
│   ├── EndpointMatcher.swift         # enum: request + endpoints -> MatchResult
│   ├── OpenAPIImporter.swift         # enum: OpenAPI spec -> [MockEndpoint]
│   ├── JSONSchemaGenerator.swift     # enum: JSON Schema -> mock JSON string
│   ├── YAMLParser.swift              # enum: YAML string -> Dictionary
│   └── ExportService.swift           # enum: endpoints -> JSON Data
│
├── UI/
│   ├── Server/                       # Server control views
│   ├── Endpoints/                    # Endpoint list + editor views
│   ├── RequestLog/                   # Request log + detail views
│   ├── Import/                       # OpenAPI import flow views
│   ├── Templates/                    # Response template picker views
│   ├── Components/                   # Shared UI components (badges, editors)
│   ├── Theme/                        # Colors, animations
│   ├── Pro/                          # Paywall, locked overlay
│   └── Settings/                     # Settings view
│
└── Assets.xcassets/                  # App icons, accent color, images
```

### Structure Rationale

- **App/:** Stores and app entry point. These are the "brain" -- state management and lifecycle. Kept separate from views because stores are injected via `.environment()` and shared across the entire view hierarchy.
- **Models/:** All data types. SwiftData `@Model` classes live here alongside value types like `ServerConfiguration` and `ResponseTemplate`. Clean separation means services can import models without touching UI.
- **Services/:** Stateless logic as caseless `enum` types (cannot be instantiated), plus the `MockServerEngine` actor. Services have zero UI knowledge and zero SwiftData knowledge -- they operate on plain Swift types. This makes them trivially testable.
- **UI/:** Feature-organized view folders. Each folder contains all views for one feature area. Components/ holds reusable pieces shared across features.

## Architectural Patterns

### Pattern 1: Actor-to-MainActor Bridging

**What:** MockServerEngine (actor) runs NWListener on a dedicated DispatchQueue. State changes and request logs must reach the UI on MainActor. The bridge is a callback that ServerStore registers, wrapped in `Task { @MainActor in }`.

**When to use:** Any time an off-main-thread actor needs to push data to @Observable stores that drive SwiftUI views.

**Trade-offs:** Simple and direct. The `Task { @MainActor in }` hop introduces a tiny scheduling delay (microseconds), but this is imperceptible for UI updates. Avoids AsyncStream complexity for a one-directional data push.

**Example:**
```swift
// In MockServerEngine (actor)
var onRequestReceived: (@Sendable (RequestLog) -> Void)?

// In ServerStore (MainActor)
func startServer() async {
    await engine.setOnRequestReceived { [weak self] log in
        Task { @MainActor in
            self?.requestLogs.insert(log, at: 0)
        }
    }
    try await engine.start(port: port)
}
```

### Pattern 2: Stateless Enum Services

**What:** Pure-logic services implemented as caseless enums with static methods. Cannot be instantiated. No mutable state. All inputs via parameters, all outputs via return values.

**When to use:** HTTP parsing, response building, endpoint matching, OpenAPI import, JSON generation, YAML parsing, export. Any logic that transforms input to output without side effects.

**Trade-offs:** Extremely testable (no setup, no teardown, no mocks). Cannot hold state, so they cannot cache results. For MockPad's use case, caching is unnecessary -- request volumes are low (mock server, not production).

**Example:**
```swift
enum HTTPRequestParser {
    struct ParsedRequest: Sendable { ... }
    static func parse(data: Data) -> ParsedRequest? { ... }
}

// Test: zero setup required
@Test func parseSimpleGET() {
    let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\n\r\n"
    let result = HTTPRequestParser.parse(data: Data(raw.utf8))
    #expect(result?.method == "GET")
}
```

### Pattern 3: NWListener Lifecycle via DispatchQueue + Actor

**What:** NWListener and NWConnection run on a dedicated DispatchQueue (not the main thread). The actor serializes access to mutable state (listener reference, active connections set). NWListener callbacks use `Task { await self?.method() }` to hop into actor isolation.

**When to use:** Always for MockServerEngine. NWListener's callback-based API requires a DispatchQueue. The actor provides thread-safe state management on top.

**Trade-offs:** The `Task {}` hop from DispatchQueue callbacks into actor isolation is safe but adds a scheduling hop. This is the recommended Apple pattern (WWDC25: "Use Structured Concurrency with Network Framework"). The alternative -- using `@MainActor` for the engine -- would block the main thread during network operations.

**Critical lifecycle rules:**
1. Set `stateUpdateHandler` and `newConnectionHandler` BEFORE calling `listener.start(queue:)`
2. `listener.port` is only valid after state reaches `.ready`
3. Cancellation is permanent -- create a new NWListener to restart
4. All handler callbacks arrive on the queue passed to `start(queue:)`

### Pattern 4: @Observable Store + SwiftUI Environment

**What:** Stores are `@Observable final class` instances created at the app root and injected via `.environment()`. Views access them with `@Environment(ServerStore.self)`. SwiftUI automatically tracks which properties each view reads and re-renders only when those properties change.

**When to use:** ServerStore, EndpointStore, ProManager. Any shared state that multiple views need to observe.

**Trade-offs:** Simpler than `@EnvironmentObject` (no `ObservableObject` protocol needed). Observation tracking is automatic and fine-grained. Requires iOS 17+ (satisfied: target is iOS 26.2+).

## Data Flow

### Request Processing Flow

```
  HTTP Client (Safari, ProbePad, curl)
       |
       | TCP connection to localhost:8080
       v
  NWListener (DispatchQueue: "com.mockpad.server")
       |
       | newConnectionHandler
       v
  MockServerEngine (actor)
       |
       | connection.receive(min:1, max:65536)
       v
  Raw TCP Data (up to 64KB)
       |
       | HTTPRequestParser.parse(data:)
       v
  ParsedRequest { method, path, queryString, headers, body }
       |
       | EndpointMatcher.match(request:, endpoints:)
       v
  MatchResult
       |
       +-- .matched(endpoint, pathParams)
       |       |
       |       | Task.sleep (response delay if configured)
       |       | Inject path params into response body template
       |       | HTTPResponseBuilder.build(statusCode:headers:body:)
       |       v
       |   HTTP Response Data --> connection.send() --> connection.cancel()
       |
       +-- .notFound --> 404 JSON error response
       |
       +-- .methodNotAllowed --> 405 + Allow header
       |
       v
  RequestLog created --> onRequestReceived callback
       |
       | Task { @MainActor in }
       v
  ServerStore.requestLogs (MainActor) --> SwiftUI re-render
```

### Endpoint Configuration Flow

```
  User (UI)
       |
       | Create/edit endpoint in EndpointEditorView
       v
  EndpointStore (MainActor)
       |
       | modelContext.insert() / save()
       v
  SwiftData (MockEndpoint @Model)
       |
       | @Query auto-refreshes EndpointListView
       v
  UI re-renders with updated endpoint list
       |
       | When request arrives, MockServerEngine calls:
       | EndpointStore.allEndpoints (fetched from SwiftData)
       v
  EndpointMatcher receives current endpoint list
```

### OpenAPI Import Flow

```
  User selects file via document picker (UTType: .json, .yaml)
       |
       v
  OpenAPIImporter.importSpec(from: fileData)
       |
       +-- Try JSON first: JSONSerialization
       +-- Fall back to YAML: YAMLParser.parse()
       |
       v
  Parse paths -> operations -> responses -> schemas
       |
       | JSONSchemaGenerator for mock response bodies
       | Convert {param} to :param path notation
       v
  ImportResult { endpoints: [MockEndpoint], title, version, warnings }
       |
       | User previews in ImportPreviewView (checkboxes)
       v
  Selected endpoints inserted into SwiftData via EndpointStore
```

### Server Lifecycle Flow

```
  App Launch
       |
       v
  MockPadApp creates ServerStore, EndpointStore, ProManager
       |
       | .environment() injection
       v
  ContentView observes scenePhase
       |
       +-- .active + autoStart enabled --> ServerStore.startServer()
       +-- .background --> ServerStore.stopServer() (MANDATORY)
       +-- .active (return from background) --> auto-restart if configured
       |
  ServerStore.startServer()
       |
       | Creates NWListener via MockServerEngine
       | Registers onRequestReceived callback
       | Updates isRunning, port, serverURL
       v
  Server accepting connections
       |
  ServerStore.stopServer()
       |
       | engine.stop() cancels listener + all connections
       | Updates isRunning = false
       v
  Server stopped
```

### Key Data Flows

1. **Request-Response Cycle:** TCP data in -> parse -> match -> build response -> TCP data out. Entire cycle happens within MockServerEngine actor + stateless services. No MainActor involvement until logging.
2. **State Bridging:** Engine state changes (running, port, error) pushed to ServerStore via callbacks wrapped in `Task { @MainActor in }`. SwiftUI observes ServerStore properties and re-renders automatically.
3. **Endpoint Provisioning:** User edits endpoints via UI -> SwiftData persists -> MockServerEngine reads current endpoints from EndpointStore when processing each request. No cache invalidation needed because reads are per-request.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-10 endpoints | Default architecture. Linear scan in EndpointMatcher is sub-millisecond. |
| 10-50 endpoints | Still fine. Linear scan of 50 short path patterns is negligible. |
| 50-200 endpoints (OpenAPI import) | Consider sorting endpoints by specificity (exact > parameterized > wildcard) for predictable matching priority. Linear scan still acceptable. |
| 1000+ request logs | Auto-prune to 1000 entries. SwiftUI List with lazy loading handles rendering. SwiftData query with sort + limit for persistence. |
| 50 concurrent connections | Hard cap enforced in MockServerEngine. HTTP/1.0 close-after-response keeps connection lifetime short. |

### Scaling Priorities

1. **First bottleneck: Request log rendering.** At 1000+ entries, SwiftUI List needs lazy loading. Prune to 1000 entries max. Use SwiftData `@Query` with `fetchLimit` for the persistent log view.
2. **Second bottleneck: Large OpenAPI import.** Parsing a 10MB spec with hundreds of endpoints can take seconds. Show progress indicator. Cap at 200 endpoints per import. Allow selective import via checkboxes.

## Anti-Patterns

### Anti-Pattern 1: Running NWListener on MainActor

**What people do:** Put MockServerEngine on MainActor (or make it a regular class accessed from main thread) because "everything is @MainActor by default."
**Why it's wrong:** NWListener callbacks fire frequently during request processing. Running network I/O on the main thread blocks UI rendering. Connection accept, data receive, response send -- all would block scroll performance in the endpoint list or request log.
**Do this instead:** MockServerEngine is an explicit `actor` (not MainActor). NWListener runs on a dedicated `DispatchQueue("com.mockpad.server")`. Bridge to MainActor only for UI state updates via `Task { @MainActor in }`.

### Anti-Pattern 2: Caching Endpoints in the Engine

**What people do:** Copy the endpoint list into MockServerEngine at server start and require "refresh" when endpoints change.
**Why it's wrong:** Creates stale data. User edits an endpoint while the server is running, but the cached copy does not reflect the change. Requests hit old config until user manually refreshes.
**Do this instead:** Read endpoints from EndpointStore on every request. At mock-server request volumes (tens per minute, not thousands per second), the SwiftData query cost is negligible. Endpoints always reflect the latest configuration.

### Anti-Pattern 3: Using AsyncStream for Simple Callbacks

**What people do:** Create an AsyncStream to bridge engine events to ServerStore, requiring `for await` consumption loops and careful cancellation handling.
**Why it's wrong:** Overengineered for one-directional event push. AsyncStream requires the consumer to continuously iterate, adds cancellation complexity, and is harder to debug than a simple callback.
**Do this instead:** Use a `@Sendable` closure callback from MockServerEngine to ServerStore. The closure wraps UI updates in `Task { @MainActor in }`. Simple, debuggable, no lifecycle management needed.

### Anti-Pattern 4: Storing Headers as [String: String] in SwiftData

**What people do:** Try to store `[String: String]` directly as a SwiftData property.
**Why it's wrong:** SwiftData does not natively support Dictionary storage. The property either fails silently or requires Transformable configuration.
**Do this instead:** Store headers as `Data?` (JSON-encoded) with a computed property that encodes/decodes. This is the pattern used in the PRD: `responseHeadersData: Data?` with `var responseHeaders: [String: String] { get/set }`.

### Anti-Pattern 5: Forgetting Foreground-Only Constraint

**What people do:** Assume the server keeps running when the user switches apps.
**Why it's wrong:** NWListener is suspended by iOS when the app enters background. Connections drop silently. On return, the listener may be in `.cancelled` state and cannot be restarted (must create new one).
**Do this instead:** Monitor `scenePhase`. Stop server cleanly on `.background`. Restart on `.active` if auto-start is enabled. Show clear UI messaging about the foreground-only constraint.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI <-> ServerStore | `@Environment` + `@Observable` property observation | SwiftUI reads `isRunning`, `port`, `requestLogs`. Calls `startServer()`, `stopServer()`. |
| UI <-> EndpointStore | `@Environment` + `@Observable` + `@Query` | Views use `@Query` for endpoint lists. Store exposes CRUD methods. |
| ServerStore <-> MockServerEngine | `async` method calls + `@Sendable` callback | ServerStore calls `engine.start()`, `engine.stop()`. Engine calls back via `onRequestReceived`. |
| MockServerEngine <-> Services | Direct static method calls | Engine calls `HTTPRequestParser.parse()`, `EndpointMatcher.match()`, `HTTPResponseBuilder.build()` synchronously within actor isolation. |
| OpenAPIImporter <-> EndpointStore | Return value -> store insertion | Importer returns `[MockEndpoint]`. UI previews, then EndpointStore inserts selected endpoints. |

### External Interfaces

| Interface | Pattern | Notes |
|-----------|---------|-------|
| HTTP clients | TCP via NWListener on localhost (or LAN) | Any HTTP client can connect. Default port 8080. |
| File import | UTType .json / .yaml via document picker | OpenAPI spec files. |
| File export | JSON via UIActivityViewController (share sheet) | Endpoint collection export. |
| StoreKit 2 | Product.products() / purchase() | PRO unlock. No server component. |

## Concurrency Model

### Actor Boundaries

```
MainActor (default for app target)
├── All SwiftUI Views
├── ServerStore (@Observable)
├── EndpointStore (@Observable)
├── ProManager (@Observable)
└── SwiftData ModelContext

MockServerEngine (explicit actor)
├── NWListener (lifecycle)
├── Set<NWConnection> (active connections)
├── DispatchQueue (NWListener + connections run here)
└── Callbacks bridge to MainActor via Task { @MainActor in }

Stateless Services (nonisolated)
├── HTTPRequestParser (enum, static methods)
├── HTTPResponseBuilder (enum, static methods)
├── EndpointMatcher (enum, static methods)
├── OpenAPIImporter (enum, static methods)
├── JSONSchemaGenerator (enum, static methods)
├── YAMLParser (enum, static methods)
└── ExportService (enum, static methods)
```

### Concurrency Rules

1. **MainActor is default.** All types in the app target are implicitly `@MainActor` unless explicitly marked otherwise. This is enforced by build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
2. **MockServerEngine is an explicit `actor`.** This overrides the MainActor default. The actor serializes access to `listener` and `activeConnections` from multiple DispatchQueue callbacks.
3. **Stateless enum services are nonisolated.** They have no mutable state, so they are safe to call from any isolation context (MainActor, MockServerEngine actor, or nonisolated).
4. **NWListener runs on a dedicated DispatchQueue.** This is required by the Network framework API. The DispatchQueue is NOT the main queue. Handler callbacks (`stateUpdateHandler`, `newConnectionHandler`) fire on this queue.
5. **DispatchQueue -> Actor hop.** NWListener callbacks use `Task { await self?.handleMethod() }` to enter actor isolation. This is safe and recommended (WWDC25).
6. **Actor -> MainActor hop.** MockServerEngine pushes state updates to ServerStore via `Task { @MainActor in }`. This ensures UI updates happen on the main thread.
7. **Test target does NOT have MainActor default.** Test structs that access MainActor-isolated types need explicit `@MainActor` annotation.
8. **SwiftData models need `@preconcurrency Codable`** if used with JSONEncoder/JSONDecoder from nonisolated contexts (the `responseHeadersData` encode/decode pattern).

## Suggested Build Order

Build order follows dependency chains. Each layer depends only on layers below it.

### Phase 1: Foundation (no dependencies)
**Build:** SwiftData models (MockEndpoint, RequestLog, EndpointCollection, ServerConfiguration, ResponseTemplate) + EndpointStore + app scaffold (replace template Item.swift)
**Rationale:** Models are the foundation everything else depends on. EndpointStore provides CRUD that the engine, UI, and import flows all need. Must be built first.
**Testable immediately:** Model validation, EndpointStore CRUD with in-memory SwiftData container.

### Phase 2: HTTP Engine Core (depends on Phase 1 models)
**Build:** HTTPRequestParser + HTTPResponseBuilder + EndpointMatcher + MockServerEngine + ServerStore
**Rationale:** These are the "spine" of the app. Parser/builder/matcher are stateless and independently testable. MockServerEngine wires them together with NWListener. ServerStore bridges to UI.
**Testable immediately:** Parser tests (~25), builder tests (~15), matcher tests (~20), engine start/stop integration test.

### Phase 3: Endpoint Editor UI (depends on Phase 1 + Phase 2)
**Build:** EndpointListView + EndpointEditorView + ResponseEditorView + HeaderEditorView + ServerControlView + iPad NavigationSplitView layout
**Rationale:** With models, store, and engine in place, the UI can be wired up. Server control needs ServerStore. Endpoint list needs EndpointStore. Editor needs MockEndpoint model.
**Testable:** Manual testing (start server, create endpoint, send request via curl, see response).

### Phase 4: Request Log (depends on Phase 2 engine)
**Build:** RequestLogView + RequestLogRowView + RequestDetailView + RequestFilterBar + live streaming from ServerStore
**Rationale:** Request log consumes the `requestLogs` array from ServerStore, which is populated by the engine callback. Needs the engine running to generate logs.
**Testable:** Send requests to running server, verify log entries appear in real-time.

### Phase 5: Templates + JSON Editor (depends on Phase 1 + Phase 3)
**Build:** ResponseTemplate built-in set + TemplateListView + TemplatePickerView + JSONEditorView (syntax highlighting) + DelayConfigView
**Rationale:** Templates enhance the endpoint editor. JSON editor enhances the response body field. These are productivity features that layer on top of the existing editor.
**Testable:** Select template, verify response body populated. Edit JSON, verify highlighting.

### Phase 6: OpenAPI Import (depends on Phase 1 models)
**Build:** OpenAPIImporter + JSONSchemaGenerator + YAMLParser + OpenAPIImportView + ImportPreviewView + FileImportView
**Rationale:** Import creates MockEndpoint instances from OpenAPI specs. Depends only on models (not on engine or UI). Can be built in parallel with Phases 3-5 if desired.
**Testable immediately:** Importer tests (~15), generator tests (~10), YAML parser tests (~10). Full flow: import spec file, preview endpoints, insert into store.

### Phase 7: PRO Features (depends on Phase 1 + Phase 3 + Phase 6)
**Build:** ProManager (StoreKit 2) + endpoint limit enforcement + collections + export/share + response delay + custom templates + paywall UI
**Rationale:** PRO gating wraps existing features. Needs endpoint editor (Phase 3), collections (Phase 1 model), import (Phase 6), and templates (Phase 5) to gate.
**Testable:** Verify free tier limits, purchase flow, feature unlocking.

### Phase 8: Polish + iPhone (depends on all above)
**Build:** iPhone TabView layout + theme refinement + empty states + "Create Sample API" quick-start + accessibility + App Store assets
**Rationale:** Polish phase. iPhone layout is a reorganization of existing views into TabView. Theme and accessibility are cross-cutting.
**Testable:** iPhone layout verification, VoiceOver testing, empty state flows.

### Build Order Dependency Graph

```
Phase 1: Models + EndpointStore
    |
    +------+------+
    |             |
Phase 2:      Phase 6:
Engine Core   OpenAPI Import
    |             |
    +------+------+
    |
Phase 3: Endpoint Editor UI
    |
    +------+------+
    |             |
Phase 4:      Phase 5:
Request Log   Templates + JSON Editor
    |             |
    +------+------+
    |
Phase 7: PRO Features
    |
Phase 8: Polish + iPhone
```

**Key insight:** Phase 6 (OpenAPI Import) has no dependency on the engine or UI -- only on models. It can be built in parallel with Phases 2-5 if resources allow.

## Sources

- [NWListener | Apple Developer Documentation](https://developer.apple.com/documentation/network/nwlistener) -- HIGH confidence
- [Use Structured Concurrency with Network Framework - WWDC25](https://developer.apple.com/videos/play/wwdc2025/250/) -- HIGH confidence (Apple first-party, confirms actor + DispatchQueue bridging pattern)
- [Building a server-client application using Apple's Network Framework](https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/) -- MEDIUM confidence (community tutorial, consistent with Apple docs)
- [NWListener in background iOS | Apple Developer Forums](https://developer.apple.com/forums/thread/772637) -- HIGH confidence (confirms foreground-only constraint)
- [Swift actors tutorial - a beginner's guide to thread safe concurrency](https://theswiftdev.com/swift-actors-tutorial-a-beginners-guide-to-thread-safe-concurrency/) -- MEDIUM confidence (community, consistent with Swift docs)
- [MainActor usage in Swift explained](https://www.avanderlee.com/swift/mainactor-dispatch-main-thread/) -- MEDIUM confidence (well-known Swift blog, consistent with Apple docs)
- MockPad PRD: `.planning/mockpad/MOCKPAD-TECHNICAL.md` -- project-internal, authoritative for this app

---
*Architecture research for: iOS local HTTP mock server (NWListener-based)*
*Researched: 2026-02-16*
