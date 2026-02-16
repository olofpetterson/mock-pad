# Pitfalls Research

**Domain:** iOS Local Mock HTTP Server (NWListener-based)
**Researched:** 2026-02-16
**Confidence:** HIGH (NWListener/lifecycle), MEDIUM (App Store review), HIGH (HTTP parsing/concurrency)

## Critical Pitfalls

### Pitfall 1: NWListener Port Stuck After Cancel ("Address Already in Use")

**What goes wrong:**
After calling `.cancel()` on an `NWListener`, attempting to create a new `NWListener` on the same port fails with POSIX error 48: "Address already in use." The server cannot restart without killing the app. This only occurs on **real devices** -- the Simulator always behaves as if `allowLocalEndpointReuse` is `true`, masking the bug entirely during development.

**Why it happens:**
`allowLocalEndpointReuse` is broken on real iOS devices (filed as FB8658821). It always behaves as `false` regardless of the value set. Additionally, if active `NWConnection` objects are not cancelled before the listener is cancelled, their sockets hold the port open.

**How to avoid:**
- Track all active `NWConnection` instances in an array/set on the server actor.
- Cancel every `NWConnection` **before** cancelling the `NWListener`.
- After cancellation, create a **new** `NWListener` instance rather than trying to restart the old one.
- Never rely on `allowLocalEndpointReuse` -- treat it as non-functional.
- Implement a fallback port strategy: if the primary port (e.g., 8080) fails, try 8081, 8082, etc., and surface the actual port in the UI.

**Warning signs:**
- Server restart works in Simulator but fails on device.
- "Address already in use" errors in console only after the first stop/start cycle.
- QA reports "server won't start" after toggling the server off and on.

**Phase to address:**
Core server implementation phase (NWListener setup). This must be correct from day one -- retrofitting connection tracking is error-prone.

---

### Pitfall 2: Server Silently Dies When App Backgrounds (iPad Split View Complication)

**What goes wrong:**
iOS suspends apps shortly after backgrounding. The `NWListener` stops accepting connections but reports no error -- clients connect but get no response. On iPad, Split View introduces a subtler failure: the app may go `.inactive` (not `.background`) when another app takes focus in Split View, and the server continues running but in an ambiguous state. Conversely, when the scene *does* background, the server stops but the UI may not reflect this on return.

**Why it happens:**
`scenePhase` tracks individual scenes (windows), not the entire app. iPad multitasking means your app can be simultaneously visible and partially suspended. The three-state model (`.active`, `.inactive`, `.background`) is too coarse for reliable server lifecycle management.

**How to avoid:**
- Stop the `NWListener` on `.background` and `.inactive` transitions via `.onChange(of: scenePhase)`.
- Restart the `NWListener` (new instance -- see Pitfall 1) on `.active` transition.
- Show a clear "Server Stopped" banner when `scenePhase != .active` so users understand why requests fail.
- Do NOT rely on background execution modes -- `NWListener` is foreground-only by design. Do not request background modes you don't qualify for.
- Test on a real iPad in Split View, Slide Over, and Stage Manager configurations.

**Warning signs:**
- Server works perfectly in Simulator (single scene) but drops connections on iPad.
- Users report "server stops randomly" -- actually correlates with app switching.
- No explicit error in logs when the listener goes deaf during suspension.

**Phase to address:**
Server lifecycle management phase. Must be designed alongside the initial server implementation, not bolted on later.

---

### Pitfall 3: Concurrency Deadlock -- Actor + NWListener DispatchQueue + MainActor Three-Way Bridge

**What goes wrong:**
`NWListener` and `NWConnection` deliver all callbacks on a `DispatchQueue` you provide. The server logic lives on a custom actor. The UI observes server state from `@MainActor`. Bridging these three isolation domains incorrectly causes either: (a) data races (accessing actor state from the DispatchQueue callback without `await`), (b) deadlocks (synchronously waiting on the actor from the DispatchQueue), or (c) UI freezes (blocking MainActor while awaiting actor responses).

**Why it happens:**
NWListener predates Swift concurrency -- its API is callback-based on DispatchQueue. The Swift compiler with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes everything MainActor-isolated by default, which conflicts with background server work. Developers either scatter `nonisolated` everywhere (losing safety) or create implicit blocking bridges.

**How to avoid:**
- Create the server as a dedicated `actor` (not `@MainActor`).
- In NWListener/NWConnection callbacks (which run on the DispatchQueue), use `Task { await self.handleEvent(...) }` to hop onto the actor -- never access actor state directly from the callback closure.
- Publish server state changes to the UI via `AsyncStream` (actor pushes events, `@MainActor` ViewModel consumes them) -- this avoids the ViewModel polling the actor.
- Mark the server actor's public observation properties as `nonisolated` only for immutable/`Sendable` values.
- Do NOT pass `NWConnection` objects across actor boundaries -- they are not `Sendable`.

**Warning signs:**
- Swift 6 concurrency warnings about non-sendable types crossing actor boundaries.
- UI hangs when the server is under load (MainActor blocked awaiting actor).
- Intermittent crashes on "actor-isolated property accessed from non-isolated context."

**Phase to address:**
Architecture/foundation phase. The actor boundary design must be established before any server logic is written. Retrofitting actor isolation onto callback-based code is a rewrite.

---

### Pitfall 4: Incomplete HTTP Request Parsing (TCP Framing Ignorance)

**What goes wrong:**
`NWConnection.receive()` delivers arbitrary chunks of TCP data -- not complete HTTP requests. A single HTTP request may arrive as multiple `receive()` callbacks, or multiple pipelined requests may arrive in a single callback. Naive parsing that assumes one `receive()` = one complete request either drops data, crashes on malformed input, or silently misparses requests.

**Why it happens:**
TCP is a stream protocol with no message boundaries. `NWListener`/`NWConnection` are transport-layer APIs with zero HTTP awareness. Developers accustomed to `URLSession` (which handles framing internally) underestimate the complexity of raw TCP parsing.

**How to avoid:**
- Implement a proper HTTP/1.1 request parser that accumulates data across multiple `receive()` calls.
- Parse the request line and headers first. Once `Content-Length` is known, continue reading until the body is complete.
- Handle `Transfer-Encoding: chunked` if supporting POST/PUT with streaming bodies (or reject it with 411 if out of scope for v1.0).
- Set a maximum header size (e.g., 8KB) and maximum body size (e.g., 10MB) to prevent memory exhaustion from malformed/malicious requests.
- Always call `receive()` again after processing the current data -- forgetting this causes the connection to appear to hang.
- Consider using the `swift-http-structured-headers` package or porting the lightweight `http_parser` (Joyent/Node.js C parser) if hand-rolling feels risky.

**Warning signs:**
- Works with `curl` but fails with browsers (which send larger headers or pipeline requests).
- Intermittent "request body missing" errors under load.
- POST requests with bodies larger than one TCP segment fail silently.

**Phase to address:**
HTTP parsing phase. This is foundational infrastructure that everything else depends on. Must be built with tests covering partial delivery, pipelining, and oversized requests before any route handling is added.

---

### Pitfall 5: OpenAPI Spec Parsing -- Circular `$ref` and Polymorphic Schema Infinite Loops

**What goes wrong:**
OpenAPI specs commonly use `$ref` for schema reuse, and `allOf`/`oneOf`/`anyOf` for inheritance and polymorphism. A `$ref` chain like `Schema A -> allOf[Schema B] -> $ref Schema A` creates a cycle. Naive recursive parsing enters an infinite loop or causes a stack overflow. Even non-circular specs can have deeply nested `allOf` compositions that explode combinatorially when resolving to flat response schemas.

**Why it happens:**
Circular references are explicitly valid in OpenAPI 3.x for recursive data structures (e.g., a tree node referencing itself). Without cycle detection during `$ref` resolution, the parser recurses infinitely. Apple's `swift-openapi-generator` itself has open issues with `oneOf`/`allOf` handling, demonstrating the complexity.

**How to avoid:**
- Implement `$ref` resolution with a visited-set to detect cycles. When a cycle is detected, emit a placeholder or stop recursion.
- Resolve `$ref` lazily (on demand) rather than eagerly (all at once on load) -- this naturally limits recursion depth.
- Cap recursion depth (e.g., 20 levels) as a safety net.
- For `allOf`, merge properties from all sub-schemas into one flat schema. For `oneOf`, generate a Swift `enum` with associated values per variant.
- Test with real-world specs: Stripe API (deeply nested `allOf`), GitHub API (polymorphic `oneOf`), Petstore (baseline).

**Warning signs:**
- Parser hangs on certain user-provided specs with no error.
- Memory usage spikes when loading large specs.
- Stack overflow crash on deeply nested schemas.

**Phase to address:**
OpenAPI parsing phase. Must be implemented with cycle detection from the start -- adding it retroactively requires rewriting the entire resolution pipeline.

---

### Pitfall 6: YAML Parsing Without External Dependencies -- Hidden Complexity

**What goes wrong:**
Swift has no built-in YAML parser. Developers either: (a) add Yams as a dependency (breaking a zero-dependency constraint), (b) try to write a YAML parser from scratch (massive undertaking -- YAML 1.2 spec is notoriously complex with anchors, aliases, multi-document, flow/block styles), or (c) require JSON-only input (losing OpenAPI ecosystem compatibility since most specs are YAML).

**Why it happens:**
YAML looks simple but is one of the most complex serialization formats. The full spec includes features like anchors (`&`), aliases (`*`), tags (`!!`), multi-line strings with various chomping indicators, and document separators (`---`). A "simple" hand-rolled parser will fail on real-world OpenAPI specs that use these features.

**How to avoid:**
- Accept the Yams dependency. It has zero transitive dependencies itself, is Swift 6 compatible, and powers SwiftLint/SwiftGen. The "zero dependency" goal should not override correctness.
- Alternatively, accept JSON-only for v1.0 and add YAML support in a later phase -- but document this as a known limitation prominently in the UI.
- If YAML is required without Yams, implement a **subset parser** that handles only the YAML features used in OpenAPI specs (block mappings, block sequences, quoted/unquoted scalars, multi-line strings). Explicitly reject anchors/aliases/tags with a clear error.
- Never attempt a full YAML 1.2 parser from scratch -- it is a multi-month effort.

**Warning signs:**
- "Works with my test YAML" but fails on user-provided specs.
- Multi-line description fields in OpenAPI specs parse incorrectly.
- Anchors/aliases in specs cause silent data loss or crashes.

**Phase to address:**
Spec import phase. The YAML decision must be made before any OpenAPI parsing work begins, as it determines the entire import pipeline architecture.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| String-based HTTP parsing (split on `\r\n`) | Fast to implement | Fails on edge cases (headers with colons in values, multi-line headers, binary bodies) | Never -- use a proper state machine or library |
| Single hardcoded port (8080) | No port selection UI needed | Unusable when port is occupied by another app/service | MVP only -- add port picker in v1.1 at latest |
| Ignoring `Transfer-Encoding: chunked` | Simplifies HTTP parser | POST/PUT with chunked bodies silently fail | v1.0 if clearly documented; add chunked support by v1.1 |
| Passing `NWConnection` across actor boundaries | Avoids wrapper types | Swift 6 concurrency errors, potential data races | Never -- wrap in actor-local handler from day one |
| Eager full-spec resolution on import | Simpler code path | Memory explosion on large specs (Stripe API = 100K+ lines) | Never -- use lazy resolution |
| Storing mock responses as raw strings in SwiftData | No schema design needed | No structured editing, search, or content-type awareness | MVP only -- migrate to structured model before v1.1 |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| NWListener + scenePhase | Observing scenePhase at the App level (gets aggregate of all scenes) | Observe scenePhase at the **View** level inside the active WindowGroup scene |
| NWConnection receive loop | Calling `receive()` once and expecting all data | Call `receive()` recursively after each completion -- the connection only delivers data when a receive is pending |
| SwiftData ModelContext + server actor | Creating ModelContext on MainActor and passing to server actor | Create a separate ModelContext via `ModelActor` on the server actor's isolation -- `ModelContext` is not Sendable |
| OpenAPI `$ref` resolution | Resolving `$ref` relative to current file location | Resolve relative to the **document root** per OpenAPI spec -- `#/components/schemas/Foo` is always root-relative |
| App Transport Security (ATS) | Forgetting that even localhost HTTP is blocked by default | Add `NSAllowsLocalNetworking: true` in Info.plist (or `NSExceptionDomains` for `localhost`) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Parsing full OpenAPI spec synchronously on main thread | UI freezes for 2-5 seconds on large specs | Parse on background actor, stream progress to UI | Specs > 5,000 lines (common for real APIs) |
| Accumulating all request logs in memory | Memory grows unbounded, app killed by OS | Ring buffer with configurable max entries (e.g., 500), persist overflow to SwiftData | After ~1,000 logged requests with full bodies |
| Creating new NWListener per request (misunderstanding the API) | Port exhaustion, "address already in use" errors | One NWListener instance, multiple NWConnection instances | Immediately -- first concurrent request fails |
| Rendering large JSON response bodies in SwiftUI Text view | Scroll lag, dropped frames | Use lazy rendering (paginated text) or syntax-highlighted code view with virtualization | Response bodies > 50KB |
| Synchronous `$ref` resolution on every request match | Latency spikes on first request to complex endpoints | Pre-resolve and cache flattened schemas at import time | Specs with > 50 shared `$ref` schemas |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Binding NWListener to `0.0.0.0` instead of `127.0.0.1` | Exposes mock server to entire local network -- other devices can send requests, potentially leaking mock data or exploiting parsing bugs | Always bind to `NWEndpoint.hostPort(host: .ipv4(.loopback), port: ...)` explicitly |
| No request size limits on HTTP parser | Memory exhaustion attack -- malicious client sends infinite headers or body | Enforce max header size (8KB), max body size (configurable, default 10MB), max URL length (2KB) |
| Executing user-provided response templates with string interpolation | Template injection -- if response bodies support `{{variable}}` syntax, ensure no code execution path exists | Use a sandboxed template engine with no access to app internals; treat all template output as data, never code |
| Storing sensitive mock data (API keys, tokens in response bodies) unencrypted in SwiftData | Data persists on device; if device is compromised, mock secrets are exposed | Document that MockPad is for development data only; optionally offer an in-memory-only mode for sensitive mocks |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual indication that server stopped when app backgrounded | User switches back, thinks server is running, wonders why requests fail | Show prominent "Server Paused" overlay on return; auto-restart with animation |
| Requiring manual port entry | Users unfamiliar with ports enter invalid values or conflict with existing services | Default to 8080 with auto-increment on conflict; show the actual URL (`http://localhost:8080`) as a copyable badge |
| Silent OpenAPI parse failures | User imports a spec, sees partial routes, doesn't know which failed | Show import report: X routes imported, Y skipped (with reasons), Z warnings |
| No request log when server is working correctly | User can't verify their client is actually hitting MockPad vs. a real server | Always show a live request log with timestamps, method, path, status code -- even (especially) for successful requests |
| Requiring app to stay in foreground with screen on | iPad users can't use MockPad alongside their development app | Document the foreground requirement clearly; consider suggesting Split View as the intended workflow |

## "Looks Done But Isn't" Checklist

- [ ] **HTTP Parser:** Often missing support for HTTP pipelining (multiple requests in one TCP connection without waiting for response) -- verify with `curl --http1.1` sending pipelined requests
- [ ] **NWListener restart:** Often works in Simulator but fails on device -- verify stop/start cycle on a physical iPhone/iPad
- [ ] **OpenAPI import:** Often handles simple specs but crashes on `allOf` composition -- verify with Stripe API spec (most complex widely-used spec)
- [ ] **Response headers:** Often missing `Content-Length` on static responses -- verify with `curl -v` that all responses include correct `Content-Length` or chunked encoding
- [ ] **CORS headers:** Often forgotten entirely -- verify that browser-based clients (fetch/XHR) receive `Access-Control-Allow-Origin: *` on both preflight OPTIONS and actual requests
- [ ] **IPv6 dual-stack:** NWListener may accept both IPv4 and IPv6 connections, causing duplicate handler calls -- verify connection deduplication logic
- [ ] **Scene restoration:** Often server port/state lost after app termination -- verify that killing and relaunching the app restores the last-used configuration
- [ ] **Large spec import:** Often tested with Petstore (50 endpoints) but never with real specs (500+ endpoints) -- verify with a 10K+ line spec that import completes in < 5 seconds

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Port stuck after cancel | LOW | Kill and relaunch the app; port is freed after process termination. Implement auto-fallback to next port. |
| Corrupt HTTP parser state | MEDIUM | Reset the NWConnection (cancel and accept a new one). If parser is stateful, ensure it can be reset per-connection without affecting other connections. |
| Circular $ref infinite loop | LOW | Implement a parsing timeout (5 seconds). On timeout, abort import and show error with the cycle path. |
| SwiftData migration failure | HIGH | Ship with a "Reset All Data" option accessible from Settings. Use lightweight migration only; never force-delete the store automatically. |
| Server actor deadlock | HIGH | Requires architectural fix. Prevent by designing actor boundaries correctly from the start (see Pitfall 3). |
| Wrong scenePhase observation point | MEDIUM | Refactor observation from App level to View level. Requires restructuring where the server lifecycle coordinator lives. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Port stuck after cancel | Server Core (NWListener setup) | Automated test: start, stop, restart on device -- no error 48 |
| Background suspension | Server Lifecycle | Manual test: background app, foreground, verify server accepts connections within 1 second |
| Actor/DispatchQueue/MainActor bridge | Architecture Foundation | Swift 6 strict concurrency mode compiles with zero warnings |
| Incomplete HTTP parsing | HTTP Parser | Test suite covering partial delivery, pipelining, oversized requests, malformed input |
| Circular $ref in OpenAPI | OpenAPI Parser | Import Stripe API spec without hang; import self-referencing schema without crash |
| YAML parsing complexity | Spec Import | Import 10 real-world YAML OpenAPI specs (Stripe, GitHub, Twilio, etc.) without errors |
| App Store review risk | Pre-submission | Ensure app description clearly states "developer tool for local API mocking"; no network extension usage; localhost-only binding |
| CORS missing | HTTP Response Builder | Browser-based test: fetch() from a local HTML file hits MockPad without CORS errors |
| iPad Split View lifecycle | Server Lifecycle | Manual test: run MockPad in Split View alongside Safari, toggle focus, verify server state matches UI indicator |
| Request log memory growth | Request Logging | Stress test: send 10,000 requests, verify memory stays under 100MB |

## Sources

- [Apple Developer Forums -- NWListener not working in iOS](https://developer.apple.com/forums/thread/130132)
- [Apple Developer Forums -- Stop and restart of NWListener fails](https://developer.apple.com/forums/thread/129452)
- [Apple Developer Forums -- NWListener in background iOS](https://developer.apple.com/forums/thread/772637)
- [Apple Developer Forums -- Multiple NWListeners on same port](https://developer.apple.com/forums/thread/766433)
- [Open Radar -- FB8658821: NWListener ignores allowLocalEndpointReuse](https://openradar.appspot.com/FB8658821)
- [Apple Developer Documentation -- NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [Apple Developer Documentation -- TN3179: Understanding Local Network Privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Apple Developer Forums -- Can an iOS app be a TCP socket server](https://developer.apple.com/forums/thread/127509)
- [Apple Developer Forums -- Getting four accepts for single connection](https://developer.apple.com/forums/thread/654953)
- [Jesse Squires -- SwiftUI app lifecycle: issues with ScenePhase](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/)
- [SwiftUI scenePhase documentation -- ScenePhase.inactive](https://developer.apple.com/documentation/swiftui/scenephase/inactive)
- [RFC 9112 -- HTTP/1.1](https://datatracker.ietf.org/doc/html/rfc9112)
- [GitHub -- apple/swift-openapi-generator oneOf/allOf issues (#534)](https://github.com/apple/swift-openapi-generator/issues/534)
- [pb33f.io -- Circular References in OpenAPI](https://pb33f.io/libopenapi/circular-references/)
- [GitHub -- jpsim/Yams](https://github.com/jpsim/Yams)
- [Always Right Institute -- Intro to Network.framework Servers](http://www.alwaysrightinstitute.com/network-framework/)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Proxyman -- Network Debug Tool on the App Store](https://apps.apple.com/us/app/proxyman-network-debug-tool/id1551292695)
- [Ole Begemann -- How the Swift compiler knows DispatchQueue.main implies @MainActor](https://oleb.net/2024/dispatchqueue-mainactor/)
- [Fat Bob Man -- Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [Apple Developer Forums -- NWConnection send buffer and when to send more data](https://developer.apple.com/forums/thread/689059)

---
*Pitfalls research for: iOS Local Mock HTTP Server (NWListener-based)*
*Researched: 2026-02-16*
