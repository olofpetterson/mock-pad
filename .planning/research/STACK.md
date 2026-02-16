# Stack Research

**Domain:** Native iOS local HTTP mock server (on-device NWListener server + endpoint management)
**Researched:** 2026-02-16
**Confidence:** HIGH (core stack is Apple-native; edge cases verified with multiple sources)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Network framework (NWListener + NWConnection) | iOS 12+ (available since iOS 12; iOS 13+ for NWProtocolFramer) | TCP listener for local HTTP server | Apple's official replacement for BSD sockets. No entitlement required for localhost binding. Zero dependencies. Direct flow control via callback-based receive. The only Apple-sanctioned way to run a TCP listener on iOS without third-party code. |
| SwiftUI | iOS 26+ | UI layer | Project requirement. NavigationSplitView for iPad-first split layout. TextEditor with AttributedString support (iOS 26) for response body editing with syntax coloring. |
| SwiftData | iOS 26+ | Persistence for endpoints, request logs, server configurations | Project requirement. Native Swift ORM with Codable-like model definitions. Supports `#Index` (WWDC24) for fast query on request logs. Model inheritance available in iOS 26 for endpoint type hierarchies if needed. |
| StoreKit 2 | iOS 26+ | PRO tier non-consumable purchase | Modern Swift-native IAP with cryptographically signed transactions. Built-in SwiftUI merchandising views reduce boilerplate. |
| Swift Testing | Xcode 26+ | Unit and integration tests | Struct-based test suites with `@Test`, `#expect()`. Used exclusively (no XCTest). |

### HTTP Server Engine

| Component | Approach | Why |
|-----------|----------|-----|
| TCP Listener | `NWListener(using: .tcp, on: port)` with `requiredLocalEndpoint` bound to `127.0.0.1` | Localhost-only binding ensures no local network permission dialog. No `NSLocalNetworkUsageDescription` needed. No Bonjour service registration needed. Connections from the same app (via URLSession or browser on same device) work reliably. |
| Connection Handling | `NWConnection.receive()` recursive callback pattern | Standard Apple pattern: register receive handler, process data, re-register for next chunk. Flow control is implicit -- NWConnection buffers and applies backpressure automatically. |
| HTTP Request Parsing | Manual parsing from raw TCP bytes | No built-in HTTP parser in Network framework. Parse `\r\n`-delimited lines: first line = method + path + version, subsequent lines = headers (split on first colon only), blank line = end of headers. Content-Length header determines body size. |
| HTTP Response Building | Manual string assembly | Status line + headers + `\r\n\r\n` + body. Compute Content-Length from body byte count. Encode as UTF-8 Data and send via `NWConnection.send()`. |
| Server Lifecycle | Actor-isolated `MockServerEngine` | Custom actor (NOT @MainActor) manages NWListener instance, active connections, and server state. Recreate NWListener on restart (do not reuse cancelled instances). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Yams | 6.2.1+ | YAML parsing for OpenAPI import | Only needed for YAML-format OpenAPI specs. Zero Swift package dependencies (bundles LibYAML internally). Swift 6 concurrency-safe. Full Codable support via YAMLDecoder. This is the ONE external dependency for the project -- justified because there is no native YAML parser in Swift/Foundation. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 26+ | IDE, build, test | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `PBXFileSystemSynchronizedRootGroup` for auto-detection of new files |
| Swift Testing | Test framework | Struct-based suites. Test target does NOT get MainActor default isolation -- add `@MainActor` on test structs that touch main-actor-isolated code. |
| Instruments (Network template) | Performance profiling of server | Monitor connection counts, data throughput, and memory during load testing |

## Installation

```
# No package managers needed for core stack (all Apple frameworks).
# Single SPM dependency for YAML:
# In Xcode: File > Add Package Dependencies
# URL: https://github.com/jpsim/Yams.git
# Version: from 6.2.1
```

## Key Technical Decisions

### 1. Manual HTTP Parsing vs. NWProtocolFramer vs. Third-Party

**Decision: Manual HTTP parsing in a dedicated `HTTPRequestParser` enum (caseless, static methods).**

**Why not NWProtocolFramer:**
- NWProtocolFramer adds significant boilerplate (`NWProtocolFramerImplementation` protocol with 6+ required methods).
- The only reference implementation (helje5/NWHTTPProtocol) wraps `http_parser.c` inside the framer -- the C parser already does all framing, making the NWProtocolFramer layer redundant overhead.
- For a mock server handling developer requests at low volume, the NWProtocolFramer abstraction provides no meaningful benefit over reading raw bytes and parsing.
- Confidence: HIGH (verified via Apple docs + NWHTTPProtocol source analysis)

**Why not third-party HTTP servers (GCDWebServer, Swifter, Vapor):**
- Zero external dependencies is a project constraint (Yams is the sole exception for YAML).
- GCDWebServer is Objective-C, no longer actively maintained, and uses legacy GCD/BSD sockets.
- Swifter/Vapor/Hummingbird are full server frameworks -- massive overkill for a localhost mock server.
- NWListener is simpler, modern, and fully Apple-supported.
- Confidence: HIGH

**Manual HTTP parsing is simple for HTTP/1.1:**
- Split on `\r\n` to get lines
- First line: `method SP path SP version`
- Headers: `key: value` (split on first colon, trim whitespace, lowercase keys)
- Blank line terminates headers
- Body: read exactly `Content-Length` bytes (or chunked transfer -- defer to v2)
- URL-decode the path with `removingPercentEncoding`
- Confidence: HIGH (well-documented HTTP/1.1 spec, multiple verified implementations)

### 2. Actor Isolation for Server Engine

**Decision: Custom `actor MockServerEngine` (NOT `@MainActor`).**

**Rationale:**
- Network callbacks from NWListener/NWConnection arrive on a DispatchQueue (not the main thread).
- With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, all types default to MainActor unless explicitly opted out.
- The server engine must be a custom actor to: (a) safely manage mutable state (active connections, server status), (b) avoid blocking the main thread with network I/O, (c) allow `nonisolated` methods where needed for NWListener callbacks.
- Use `withCheckedContinuation` to bridge NWConnection's callback-based receive into async/await within the actor.
- Use `AsyncStream` to publish request log events from the server actor to the UI layer.
- Confidence: HIGH (established pattern from prior projects + Swift concurrency best practices)

### 3. JSON Syntax Highlighting

**Decision: Native `AttributedString` with custom JSON tokenizer. No external highlighting library.**

**Rationale:**
- JSON has a tiny grammar: 6 token types (strings, numbers, booleans, null, keys, structural characters). A simple state-machine tokenizer produces `AttributedString` with colored runs.
- SwiftUI `Text(attributedString)` renders colored JSON natively. For editable bodies, iOS 26's `TextEditor` supports `AttributedString` binding directly.
- HighlightSwift and Highlightr are general-purpose multi-language highlighters -- massive overkill for JSON-only.
- A custom tokenizer is ~100 lines, zero dependencies, and can be tuned for performance (e.g., incremental re-highlighting on edit).
- Confidence: HIGH (AttributedString is well-documented; JSON grammar is trivial)

### 4. OpenAPI Import Strategy

**Decision: JSON-only OpenAPI import using Foundation `JSONDecoder` + custom Codable structs. YAML import uses Yams `YAMLDecoder` to decode into the same Codable structs.**

**Rationale:**
- OpenAPI 3.x spec is a well-defined JSON schema. A subset of ~15 Codable structs covers paths, operations, parameters, request bodies, responses, schemas, and components -- sufficient for extracting mock endpoints.
- Foundation's `JSONDecoder` handles JSON natively with zero dependencies.
- For YAML, Yams provides `YAMLDecoder` that decodes directly into the same Codable types (JSON is valid YAML, so the types work for both).
- Apple's Swift OpenAPI Generator is designed for client/server code generation, not for reading specs to extract endpoint definitions. It would pull in unnecessary dependencies.
- OpenAPIKit is a comprehensive library but adds a dependency we can avoid by modeling only the subset we need.
- Confidence: MEDIUM-HIGH (custom Codable structs must cover enough of the spec to be useful; edge cases in complex specs may need iteration)

### 5. Mock Data Generation from OpenAPI Schemas

**Decision: Custom schema walker that generates mock JSON from OpenAPI `schema` objects.**

**Rationale:**
- OpenAPI schemas define types (string, integer, number, boolean, array, object), formats (date-time, email, uuid, uri), enums, and examples.
- A recursive schema walker generates realistic mock values: strings from format hints, numbers from min/max ranges, arrays with 1-3 sample items, objects with all required properties.
- If the schema includes `example`, use it verbatim. If it includes `enum`, pick the first value.
- This is a ~200-line utility, not a library-sized problem.
- Confidence: MEDIUM (complex schemas with `oneOf`/`anyOf`/`allOf` composition will need careful handling)

### 6. Persistence Architecture

**Decision: SwiftData with three core models: `MockEndpoint`, `RequestLog`, `ServerConfiguration`.**

**Rationale:**
- SwiftData provides native SwiftUI integration via `@Query` and `@Environment(\.modelContext)`.
- `#Index` on `RequestLog.timestamp` and `RequestLog.path` for fast log queries on large datasets.
- `fetchLimit` on log queries prevents memory issues from unbounded log growth.
- `ModelContainer` is `Sendable` -- can be passed to the server actor for background log writes.
- Use `@Attribute(.externalStorage)` for large response bodies (images, files) to avoid bloating the SQLite database.
- Confidence: HIGH (established SwiftData patterns from prior projects)

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| NWListener (manual HTTP) | GCDWebServer | If you need a battle-tested embedded HTTP server with routing, file upload, and WebDAV -- but it's Objective-C and unmaintained |
| NWListener (manual HTTP) | Swifter (httpswift/swifter) | If zero-dependency constraint is relaxed and you want built-in routing -- but it adds an external dependency |
| Manual JSON tokenizer | HighlightSwift | If you need multi-language syntax highlighting beyond JSON -- adds an external dependency |
| Custom Codable structs for OpenAPI | OpenAPIKit | If you need full OpenAPI spec validation and round-trip encoding -- adds a dependency and is more than needed for endpoint extraction |
| Yams | Custom YAML subset parser | If you truly need zero external dependencies -- but YAML parsing is complex enough that a hand-rolled parser would be fragile and time-consuming |
| SwiftData | UserDefaults + JSON files | If the data model is trivially simple -- but endpoints + logs + configurations benefit from relational queries and indexing |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| GCDWebServer | Objective-C, unmaintained, uses legacy GCD/BSD sockets. Not Swift 6 concurrency-safe. | NWListener with manual HTTP parsing |
| Vapor / Hummingbird | Full server-side Swift frameworks. Massive dependency graphs, designed for Linux deployment, overkill for an embedded localhost server. | NWListener |
| `URLProtocol` interception | Intercepts URLSession requests at the client level, not a real HTTP server. Cannot serve requests from browsers or other apps on the device. | NWListener (real TCP server) |
| `NWProtocolFramer` for HTTP | Over-engineered for this use case. Adds boilerplate without meaningful benefit for a low-volume localhost mock server. The framing abstraction is designed for custom binary protocols, not HTTP. | Manual HTTP request/response parsing |
| WKWebView for syntax highlighting | Heavyweight for JSON-only highlighting. Introduces web view lifecycle complexity, async bridge overhead, and potential security surface. | Native AttributedString with custom JSON tokenizer |
| `NSAttributedString` (NS prefix) | Legacy Objective-C type. Requires bridging to/from Swift's `AttributedString`. | `AttributedString` (Swift-native, iOS 15+) |
| Apple Swift OpenAPI Generator | Designed for generating client/server stubs, not for reading specs to extract endpoint info. Pulls in build-time plugin dependencies. | Custom Codable structs matching OpenAPI subset |
| Core Data | Legacy persistence framework. SwiftData provides the same SQLite backend with modern Swift syntax and better SwiftUI integration. | SwiftData |

## Stack Patterns by Variant

**If the user imports a JSON-format OpenAPI spec:**
- Decode with Foundation `JSONDecoder` into custom Codable structs
- No Yams dependency needed
- Zero external dependencies for this path

**If the user imports a YAML-format OpenAPI spec:**
- Decode with Yams `YAMLDecoder` into the same Codable structs
- Yams is the single external dependency
- Because YAML is a superset of JSON, the same Codable types work for both formats

**If the mock server needs to serve to the same app (e.g., for in-app API testing):**
- Use `URLSession` pointing at `http://localhost:<port>`
- Add ATS exception in Info.plist for localhost to allow plain HTTP
- No additional entitlements needed

**If the mock server needs to serve to Safari or other apps on the same device:**
- Bind NWListener to `0.0.0.0` (all interfaces) instead of `127.0.0.1`
- This MAY trigger the local network permission dialog (needs validation)
- Add `NSLocalNetworkUsageDescription` to Info.plist as a precaution

**If the app goes to background on iPad:**
- iPad Split View keeps both apps in the foreground -- the recommended user workflow
- When fully backgrounded, iOS suspends the app within ~10-30 seconds; NWListener stops accepting connections
- On return to foreground, recreate the NWListener (do not reuse cancelled instances)
- Disable auto-lock recommendation in the app's server-running UI

## Version Compatibility

| Component | Requires | Notes |
|-----------|----------|-------|
| NWListener | iOS 12+ | Available since iOS 12. `requiredLocalEndpoint` available since iOS 12. |
| NWProtocolFramer | iOS 13+ | NOT recommended for this project, but noted for reference. |
| SwiftData `#Index` | iOS 17+ (WWDC24) | Available in our iOS 26 deployment target. Use for RequestLog queries. |
| SwiftData Model Inheritance | iOS 26+ (WWDC25) | Available in our deployment target. Optional -- use if endpoint type hierarchy benefits from it. |
| TextEditor + AttributedString | iOS 26+ | New in WWDC25. Enables rich text editing with colored JSON display. |
| StoreKit 2 SubscriptionStoreView | iOS 17+ | Available in our deployment target. Use for PRO purchase UI. |
| Yams | Swift 5.7+ / Xcode 14+ | Swift 6 language mode compatible. No package dependencies. Bundles LibYAML (C). |
| Swift Testing | Xcode 16+ | Struct-based `@Test` pattern. No XCTest. |

## NWListener Gotchas (Critical for Implementation)

### 1. Do NOT Reuse Cancelled Listeners
After calling `listener.cancel()`, creating a new `NWListener` instance is required for re-listening. Attempting to restart a cancelled listener may fail silently or with a port-in-use error. There can also be a ~5-second delay before the port becomes available again.
- **Confidence:** HIGH (verified via Swift Forums + Apple Developer Forums)

### 2. Port Binding Race Conditions
If the listener fails to start (port in use), retry with exponential backoff or fall back to `.any` port. Using `NWEndpoint.Port.any` lets the system assign an available port, which you can read from `listener.port` after the `.ready` state.
- **Confidence:** HIGH (documented in Apple docs)

### 3. Background Suspension
iOS suspends apps within 10-30 seconds of backgrounding. The NWListener itself has no built-in timeout, but iOS process suspension stops it from accepting connections. iPad Split View is the primary workaround (both apps stay in foreground).
- **Confidence:** HIGH (verified via Apple Developer Forums + multiple sources)

### 4. ATS Exception Required
Plain HTTP on localhost requires an App Transport Security exception in Info.plist. Without it, URLSession (and WKWebView) connections to `http://localhost:PORT` will fail.
- **Confidence:** HIGH (verified via Apple Developer Forums)

### 5. Simulator vs. Device Behavior Differences
`allowLocalEndpointReuse` behaves differently: on Simulator it always acts as `true`, on device it may act as `false`. Always test NWListener behavior on a real device.
- **Confidence:** MEDIUM (single source: Open Radar FB8658821)

### 6. HTTP Keep-Alive
Web browsers and HTTP clients reuse TCP connections for multiple requests. The recursive receive pattern must handle this: after processing one request and sending a response, loop back to receive the next request on the same connection. Only close the connection when the client disconnects or a timeout occurs.
- **Confidence:** HIGH (verified via multiple implementations)

### 7. Header Parsing Edge Case: Split on First Colon Only
HTTP header values can contain colons (e.g., `Host: localhost:8080`). Always split on the first colon only using `split(separator: ":", maxSplits: 1)`.
- **Confidence:** HIGH (HTTP/1.1 spec)

## Concurrency Architecture Notes

With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`:

| Type | Isolation | Rationale |
|------|-----------|-----------|
| SwiftUI Views | MainActor (default) | Standard -- UI must be on main thread |
| SwiftData @Model classes | MainActor (default) | ModelContext is not Sendable; keep on main actor |
| `MockServerEngine` | Custom `actor` | Network I/O must not block main thread. Manages NWListener, connections, server state. |
| `HTTPRequestParser` | `enum` (caseless) with `static` methods | Pure functions, no mutable state. `nonisolated` by being static on a value type. |
| `HTTPResponseBuilder` | `enum` (caseless) with `static` methods | Same pattern as parser. |
| `OpenAPIImporter` | `enum` (caseless) with `static` methods | Pure parsing logic. |
| `MockDataGenerator` | `enum` (caseless) with `static` methods | Deterministic mock data generation from schemas. |
| Stores (`EndpointStore`, `LogStore`) | MainActor (default, `@Observable`) | Hold SwiftData ModelContext references. Bridge between actor and UI. |

Bridging pattern: `MockServerEngine` (actor) sends request log events to `LogStore` (MainActor) via `AsyncStream`. The store observes the stream in a `.task` modifier and writes to SwiftData on the main actor.

## Sources

- [Apple Developer Documentation -- NWListener](https://developer.apple.com/documentation/network/nwlistener) -- PRIMARY: API reference, platform availability, state management (HIGH confidence)
- [Apple Developer Documentation -- NWProtocolFramer](https://developer.apple.com/documentation/network/nwprotocolframer) -- Evaluated and rejected for this use case (HIGH confidence)
- [WWDC18 Session 715 -- Introducing Network.framework](https://developer.apple.com/videos/play/wwdc2018/715/) -- NWListener architecture, connection handling patterns (HIGH confidence)
- [WWDC19 Session 713 -- Advances in Networking, Part 2](https://developer.apple.com/videos/play/wwdc2019/713/) -- NWProtocolFramer introduction, NWBrowser (HIGH confidence)
- [ko9.org -- Simple Web Server in Swift](https://ko9.org/posts/simple-swift-web-server/) -- Complete NWListener HTTP server implementation, parsing patterns, gotchas (MEDIUM confidence)
- [rderik.com -- Building a server-client application using Apple's Network Framework](https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/) -- Recursive receive pattern, connection lifecycle (MEDIUM confidence)
- [Always Right Institute -- Intro to Network.framework Servers](http://www.alwaysrightinstitute.com/network-framework/) -- NWProtocolFramer HTTP analysis, server patterns (MEDIUM confidence)
- [helje5/NWHTTPProtocol GitHub](https://github.com/helje5/NWHTTPProtocol) -- NWProtocolFramer HTTP implementation analysis (evaluated and rejected) (MEDIUM confidence)
- [Apple Developer Forums -- NWListener not working in iOS](https://developer.apple.com/forums/thread/130132) -- Localhost binding patterns, entitlement requirements (MEDIUM confidence)
- [Apple Developer Forums -- NWConnection + async/await](https://developer.apple.com/forums/thread/719402) -- withCheckedContinuation bridging pattern (MEDIUM confidence)
- [Swift Forums -- How to listen, cancel, and re-listen with NWListener](https://forums.swift.org/t/how-to-listen-cancel-and-re-listen-with-nwlistener/39354) -- Lifecycle gotcha: must create new listener after cancel (MEDIUM confidence)
- [Open Radar FB8658821](https://openradar.appspot.com/FB8658821) -- allowLocalEndpointReuse bug on device vs simulator (LOW confidence, single source)
- [Apple TN3179 -- Understanding Local Network Privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) -- Local network permission not needed for localhost (HIGH confidence)
- [Nonstrict -- Request and check local network permission](https://nonstrict.eu/blog/2024/request-and-check-for-local-network-permission/) -- Permission dialog mechanics (MEDIUM confidence)
- [Hacking with Swift -- SwiftData Performance Optimization](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps) -- #Index, fetchLimit, external storage patterns (HIGH confidence)
- [Jacob Bartlett -- High Performance SwiftData Apps](https://blog.jacobstechtavern.com/p/high-performance-swiftdata) -- Background ModelContainer usage, Sendable patterns (MEDIUM confidence)
- [Yams GitHub](https://github.com/jpsim/Yams) -- Swift 6 compatibility, Codable API, version 6.2.1 (HIGH confidence)
- [Swift Package Index -- Yams](https://swiftpackageindex.com/jpsim/Yams) -- Platform compatibility verification (HIGH confidence)
- [Donnywals.com -- Should you opt-in to Swift 6.2's Main Actor isolation?](https://www.donnywals.com/should-you-opt-in-to-swift-6-2s-main-actor-isolation/) -- MainActor default isolation patterns (MEDIUM confidence)
- [Avanderlee.com -- Approachable Concurrency in Swift 6.2](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) -- @concurrent, nonisolated patterns (MEDIUM confidence)

---
*Stack research for: MockPad -- Native iOS local HTTP mock server*
*Researched: 2026-02-16*
