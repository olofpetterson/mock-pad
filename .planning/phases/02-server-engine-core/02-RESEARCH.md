# Phase 2: Server Engine Core - Research

**Researched:** 2026-02-16
**Domain:** NWListener HTTP server, raw HTTP parsing, endpoint routing, CORS, foreground lifecycle, Swift actor concurrency
**Confidence:** HIGH

## Summary

Phase 2 builds the core HTTP server engine that powers MockPad. The server uses Apple's Network framework (`NWListener` + `NWConnection`) to listen for incoming TCP connections on localhost, parse raw HTTP request data, match requests to user-defined endpoints, and return configured HTTP responses. This is the heart of the app -- without it, MockPad is just a data editor.

The technical domain has three layers: (1) the `MockServerEngine` actor that owns the `NWListener` and manages connections, (2) pure-function services (`HTTPRequestParser`, `HTTPResponseBuilder`, `EndpointMatcher`) that handle the HTTP protocol work without any state, and (3) the integration layer in `ServerStore` that bridges the actor to MainActor for UI updates and SwiftData persistence.

Key challenges are: NWListener cannot be restarted after cancellation (must create a new instance each time), `allowLocalEndpointReuse` has a known bug on real devices (FB8658821 -- acts as `false` regardless of setting), NWConnection is not Hashable (need wrapper or ObjectIdentifier for Set tracking), and DispatchQueue-based callbacks from NWListener must be bridged to actor isolation via `Task { await self?.method() }`. The HTTP parsing is straightforward since MockPad only needs HTTP/1.0-style request/response (close after response, no keep-alive, no chunked transfer encoding).

**Primary recommendation:** Build three pure caseless-enum services first (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher) with comprehensive unit tests, then build the MockServerEngine actor that wires them together, then integrate into ServerStore with scenePhase lifecycle management. Pure services are fully testable without NWListener; the actor integration requires Simulator or device.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Network | iOS 17+ | NWListener (TCP server), NWConnection (connection handling), NWParameters (config) | Apple's first-party networking framework. Replaces BSD sockets with modern Swift API. Required for on-device HTTP server. |
| Foundation | iOS 17+ | Data, String, Date, DateFormatter, CFAbsoluteTimeGetCurrent for timing | Standard library. HTTP parsing uses String/Data manipulation. |
| SwiftUI | iOS 17+ | scenePhase lifecycle detection for auto-stop/restart | Provides `@Environment(\.scenePhase)` for foreground/background transitions. |
| Observation | iOS 17+ | @Observable on ServerStore for reactive UI binding | Already established in Phase 1. ServerStore updates isRunning, port, error for UI. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for parser, builder, matcher services | All test files for pure services. ~45+ tests. |
| SwiftData | iOS 17+ | EndpointStore.endpoints for endpoint matching, EndpointStore.addLogEntry for request logging | Already built in Phase 1. Phase 2 reads endpoints and writes logs. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw TCP + manual HTTP parsing | NWProtocolFramer with HTTP framing | NWProtocolFramer adds complexity with message framing protocols. Manual parsing is ~60 lines, fully testable, and sufficient for HTTP/1.0-style mock server. Use manual parsing. |
| NWListener | GCDAsyncSocket / CocoaAsyncSocket | Third-party dependency. NWListener is first-party, modern, and actively maintained. Zero-dependency constraint requires NWListener. |
| Actor for MockServerEngine | Class with DispatchQueue serial queue | Actor provides compiler-enforced thread safety. DispatchQueue requires manual discipline. Prior decision locks actor pattern. |
| Close-after-response (HTTP/1.0) | HTTP/1.1 keep-alive | Keep-alive requires connection pool management, timeout tracking, pipelining. Massive complexity increase for zero benefit in mock testing. Out of scope per ROADMAP.md. |

## Architecture Patterns

### Recommended Project Structure

```
MockPad/MockPad/
├── App/
│   ├── MockPadApp.swift              # Existing: add scenePhase lifecycle
│   ├── EndpointStore.swift           # Existing: Phase 2 reads endpoints, writes logs
│   ├── ServerStore.swift             # Modify: add engine reference, start/stop methods
│   └── ProManager.swift              # Existing: no changes
│
├── Models/
│   ├── MockEndpoint.swift            # Existing: no changes
│   ├── RequestLog.swift              # Existing: no changes
│   ├── HTTPMethod.swift              # Existing: no changes
│   └── ServerConfiguration.swift     # Existing: no changes
│
├── Services/
│   ├── MockServerEngine.swift        # NEW: actor wrapping NWListener + NWConnection
│   ├── HTTPRequestParser.swift       # NEW: caseless enum, parse raw Data -> ParsedRequest
│   ├── HTTPResponseBuilder.swift     # NEW: caseless enum, build HTTP response Data
│   └── EndpointMatcher.swift         # NEW: caseless enum, match request to endpoint
│
└── ContentView.swift                 # Modify: add scenePhase lifecycle observer
```

### Pattern 1: Pure Caseless Enum Service (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher)

**What:** Stateless services implemented as caseless enums with static methods. No instances, no state, no isolation concerns. Pure input-output functions.

**When to use:** All HTTP protocol work -- parsing, response building, endpoint matching.

**Why this pattern:** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, caseless enums with `nonisolated static func` methods are callable from any isolation context -- MainActor, custom actor, or nonisolated. This is critical because these services are called from inside the MockServerEngine actor (off-MainActor) but also need to be testable from tests (which do NOT have MainActor default isolation).

**Example:**
```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.2 + project conventions
enum HTTPRequestParser {
    struct ParsedRequest: Sendable {
        let method: String
        let path: String
        let queryString: String?
        let httpVersion: String
        let headers: [String: String]
        let body: String?
    }

    nonisolated static func parse(data: Data) -> ParsedRequest? {
        guard let rawString = String(data: data, encoding: .utf8) else { return nil }
        // Split headers from body at \r\n\r\n
        // Parse request line: METHOD /path HTTP/1.1
        // Parse headers: Key: Value
        // Return structured ParsedRequest or nil
    }
}
```

**Gotcha:** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, static methods on enums are implicitly MainActor-isolated. Must mark them `nonisolated` explicitly so the MockServerEngine actor can call them without crossing isolation boundaries. The `Sendable` conformance on `ParsedRequest` is required for passing the parsed result across actor boundaries.

### Pattern 2: Swift Actor for Server Engine

**What:** A custom actor (`MockServerEngine`) owns the `NWListener`, manages the `Set` of active `NWConnection`s, and coordinates the request/response cycle. Actor isolation protects mutable state (listener, connections set) from concurrent access across NWListener's DispatchQueue callbacks.

**When to use:** The single server engine instance.

**Why this pattern:** Prior decision locks actor (not MainActor) to avoid blocking UI during NWListener callbacks. NWListener fires callbacks on a DispatchQueue; wrapping handler bodies in `Task { await self?.method() }` bridges from DispatchQueue world to actor isolation safely.

**Example:**
```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.1 + Swift concurrency patterns
actor MockServerEngine {
    private var listener: NWListener?
    private var activeConnections: Set<ObjectIdentifier> = []
    private var connectionMap: [ObjectIdentifier: NWConnection] = [:]
    private let maxConnections = 50
    private let maxRequestSize = 64 * 1024  // 64KB

    var onRequestLogged: (@Sendable (RequestLogData) -> Void)?

    func start(port: UInt16, corsEnabled: Bool) throws {
        // MUST create new NWListener each time (cannot restart cancelled listener)
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        parameters.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MockServerError.invalidPort
        }

        let newListener = try NWListener(using: parameters, on: nwPort)

        newListener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }
        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleNewConnection(connection) }
        }

        newListener.start(queue: DispatchQueue(label: "com.mockpad.server"))
        self.listener = newListener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, connection) in connectionMap {
            connection.cancel()
        }
        connectionMap.removeAll()
        activeConnections.removeAll()
    }
}
```

**Critical gotchas:**
1. **NWListener cannot be restarted** -- once `.cancel()` is called, the instance is dead. Must create a brand new `NWListener` on every start. This is a documented limitation (SR-13918).
2. **`allowLocalEndpointReuse` bug (FB8658821)** -- on real devices, this property is ignored and acts as `false`. On Simulator it always acts as `true`. Mitigation: create new listener each time and accept a brief delay (< 1 second) for port release.
3. **NWConnection is not Hashable** -- use `ObjectIdentifier(connection)` as the Set/Dictionary key for tracking active connections, or wrap in a struct with UUID.
4. **Callback bridging** -- NWListener's `stateUpdateHandler` and `newConnectionHandler` fire on the DispatchQueue passed to `start(queue:)`. Bridge to actor isolation with `Task { [weak self] in await self?.method() }`.

### Pattern 3: Sendable Data Transfer Object for Cross-Actor Communication

**What:** A lightweight `Sendable` struct that carries request log data from the MockServerEngine actor to MainActor for SwiftData persistence. Cannot pass SwiftData model objects across actor boundaries (ModelContext is MainActor-bound).

**When to use:** When the server engine needs to notify ServerStore (MainActor) about a completed request.

**Why this pattern:** SwiftData `RequestLog` is a `@Model` class bound to a `ModelContext` on MainActor. The engine actor cannot create or insert SwiftData objects. Instead, it creates a plain Sendable struct with all the log data, passes it via a callback, and ServerStore creates the actual `RequestLog` on MainActor.

**Example:**
```swift
struct RequestLogData: Sendable {
    let timestamp: Date
    let method: String
    let path: String
    let queryParameters: [String: String]
    let requestHeaders: [String: String]
    let requestBody: String?
    let responseStatusCode: Int
    let responseBody: String?
    let responseTimeMs: Double
}
```

### Pattern 4: Port Fallback Strategy

**What:** If the configured port (default 8080) is already in use, try ports 8081 through 8090 sequentially. Report the actual port to the user via ServerStore.

**When to use:** Server start flow.

**Why this pattern:** SRVR-06 requirement. NWListener fails with `.failed` state when the port is in use. The stateUpdateHandler receives the error, and the engine can retry with the next port.

**Example:**
```swift
// In ServerStore (MainActor)
func startServer(endpointStore: EndpointStore) async {
    let basePort = ServerConfiguration.port
    let ports = (basePort...min(basePort + 10, UInt16.max)).map { $0 }

    for port in ports {
        do {
            try await engine.start(port: port, corsEnabled: corsEnabled)
            // Wait briefly for state to settle
            if await engine.isListening {
                self.port = port
                self.isRunning = true
                return
            }
        } catch {
            continue  // Try next port
        }
    }
    self.error = "Could not start server on ports \(basePort)-\(basePort + 10)"
}
```

### Pattern 5: scenePhase Lifecycle for Auto-Stop/Restart

**What:** Observe SwiftUI's `scenePhase` environment value. Stop server on `.background`, restart on `.active` if `autoStart` is enabled.

**When to use:** ContentView or App-level lifecycle observer.

**Why this pattern:** SRVR-04 and SRVR-05 requirements. NWListener is automatically suspended by iOS when the app enters background. Clean stop prevents resource leaks; auto-restart provides seamless UX on return.

**Critical detail:** Must create a NEW NWListener instance on restart (cannot reuse cancelled listener). The `.task(id: scenePhase)` pattern is elegant but `onChange(of: scenePhase)` is more explicit for the stop/start logic.

**Example:**
```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active:
        if serverStore.autoStart && !serverStore.isRunning {
            Task { await serverStore.startServer(endpointStore: endpointStore) }
        }
    case .background:
        Task { await serverStore.stopServer() }
    default:
        break
    }
}
```

### Anti-Patterns to Avoid

- **Restarting a cancelled NWListener:** Once `cancel()` is called, the listener transitions to `.cancelled` and cannot be started again. Always create a new instance. This is the most common NWListener mistake.

- **Calling actor-isolated methods directly from NWListener callbacks:** NWListener callbacks run on a DispatchQueue, not on the actor. Must use `Task { await self?.method() }` to bridge. Direct calls will cause concurrency violations in Swift 6.

- **Storing NWConnection in a Set directly:** NWConnection does not conform to Hashable. Use `ObjectIdentifier(connection)` as key or wrap in a Hashable struct.

- **Using MainActor for the server engine:** Prior decision: use a custom actor. NWListener callbacks involve potentially blocking operations (HTTP parsing, endpoint matching). Running these on MainActor would block UI updates.

- **Passing SwiftData model objects across actor boundaries:** ModelContext is MainActor-bound. Create Sendable DTOs for cross-actor communication instead.

- **Expecting `allowLocalEndpointReuse` to work on device:** Known bug FB8658821 means this flag is ignored on real devices. Design the restart flow to tolerate a brief port-release delay.

- **Parsing HTTP with regex:** String splitting is simpler, faster, and more readable for HTTP/1.0 parsing. The request line and headers are well-structured with clear delimiters (`\r\n`, `: `, ` `).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TCP server | Custom socket server with BSD sockets | NWListener + NWConnection (Network framework) | First-party, modern Swift API, handles TLS/QUIC upgrade path, iOS-optimized |
| HTTP/1.1 chunked transfer encoding | Manual chunk parsing | Close-after-response (HTTP/1.0 style) | Mock server does not need keep-alive. Close connection after each response. Out of scope per ROADMAP.md. |
| Thread-safe mutable state | DispatchQueue + locks | Swift actor (MockServerEngine) | Compiler-enforced isolation. Prior decision. |
| Date formatting for HTTP Date header | Manual string construction | DateFormatter with en_US_POSIX locale, GMT timezone | HTTP Date header has strict format (RFC 7231). DateFormatter handles it correctly. |

**Key insight:** The entire HTTP server is built from one Apple framework (Network) plus string parsing. No external libraries, no complex protocols. The simplicity comes from the HTTP/1.0 close-after-response design choice, which eliminates connection pool management, pipelining, and chunked encoding entirely.

## Common Pitfalls

### Pitfall 1: NWListener Cannot Be Restarted After Cancel

**What goes wrong:** Developer calls `listener.cancel()` on background, then tries to call `listener.start(queue:)` on foreground return. Nothing happens -- the listener stays in `.cancelled` state.

**Why it happens:** NWListener is a one-shot object. Once cancelled, it is permanently dead. This is documented behavior but not obvious from the API surface. Filed as SR-13918.

**How to avoid:** Always create a new NWListener instance for each start. Set `self.listener = nil` after cancel. In `start()`, guard `listener == nil` and create fresh.

**Warning signs:** Server appears to start (no error) but never receives connections after backgrounding and returning.

### Pitfall 2: DispatchQueue Callback to Actor Isolation Mismatch

**What goes wrong:** NWListener callbacks (`stateUpdateHandler`, `newConnectionHandler`) and NWConnection callbacks (`receive`, `stateUpdateHandler`) fire on the DispatchQueue passed to `start(queue:)`. If these callbacks directly access actor-isolated state, Swift 6 strict concurrency will error.

**Why it happens:** NWListener was designed before Swift Concurrency. Its API is callback-based on DispatchQueues, not async/await.

**How to avoid:** Wrap every callback body in `Task { [weak self] in await self?.actorMethod() }`. Use `[weak self]` to avoid retain cycles with the listener.

**Warning signs:** Compiler errors about accessing actor-isolated property from nonisolated context. Runtime crashes from `dispatch_assert_queue` in debug builds.

### Pitfall 3: Port Already in Use on Server Restart

**What goes wrong:** Server stops on background, user returns to foreground, server tries to restart on same port but gets EADDRINUSE because the OS hasn't fully released the port from the cancelled listener.

**Why it happens:** TCP port release has a TIME_WAIT period. The `allowLocalEndpointReuse` flag that should fix this is bugged on real devices (FB8658821).

**How to avoid:** Implement port fallback (SRVR-06): try configured port, then 8081-8090. Also add a small delay (~100ms) before restart attempt. On Simulator this works fine due to the `allowLocalEndpointReuse` bug working in our favor.

**Warning signs:** "Server failed to start" errors after backgrounding and returning, especially on physical devices.

### Pitfall 4: Incomplete HTTP Request Data

**What goes wrong:** `NWConnection.receive` returns before the full HTTP request has arrived. The parser gets truncated data and returns nil (400 Bad Request) for a valid request.

**Why it happens:** TCP is a stream protocol. `receive(minimumIncompleteLength: 1, maximumLength: 65536)` returns as soon as ANY data is available, which may not be the complete HTTP request.

**How to avoid:** For MockPad's use case (small mock requests, typically < 1KB), a single receive with `minimumIncompleteLength: 1, maximumLength: 65536` will almost always get the full request in one read. For extra safety, check if the data contains `\r\n\r\n` (header-body separator). If not, do one more receive and concatenate. This is acceptable because mock requests are small and the 64KB limit caps total size.

**Warning signs:** Intermittent 400 errors for valid requests, especially with larger POST bodies.

### Pitfall 5: MainActor Isolation on Static Enum Methods

**What goes wrong:** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, static methods on `HTTPRequestParser`, `HTTPResponseBuilder`, `EndpointMatcher` are implicitly MainActor-isolated. The MockServerEngine actor cannot call them without an async hop to MainActor, which defeats the purpose of the off-main-thread actor.

**Why it happens:** The build setting applies MainActor isolation to ALL declarations in the main target, including static methods on enums.

**How to avoid:** Mark all static methods on the three service enums as `nonisolated`. This removes the implicit MainActor isolation and allows the actor to call them synchronously.

**Warning signs:** Compiler errors saying "call to main actor-isolated static method in a synchronous nonisolated context" inside MockServerEngine.

### Pitfall 6: Forgetting CORS on Error Responses

**What goes wrong:** Developer adds CORS headers to matched endpoint responses but forgets to add them to 404, 405, and 400 error responses. Browser JavaScript `fetch()` calls fail with CORS errors even for known-bad paths, confusing the developer using MockPad.

**Why it happens:** CORS headers must be on EVERY response, not just successful ones. Error responses without CORS headers are blocked by browsers before the developer can see the error JSON.

**How to avoid:** Add CORS headers in `HTTPResponseBuilder.build()` unconditionally (when CORS is enabled). This ensures 404, 405, 400 responses all include CORS headers. The CORS toggle in ServerConfiguration controls whether headers are added.

**Warning signs:** Browser console shows "CORS error" for requests that should return 404 JSON.

### Pitfall 7: Memory Leak from Strong Self in NWListener Callbacks

**What goes wrong:** NWListener and NWConnection callback closures capture `self` (the actor) strongly. If the actor tries to stop the server but callbacks still hold references, the actor is never deallocated.

**Why it happens:** Closures registered on NWListener/NWConnection capture their environment. Without `[weak self]`, the listener/connections hold a strong reference to the actor.

**How to avoid:** Always use `[weak self]` in callback closures registered on NWListener and NWConnection. Guard `self` at the top of the Task block.

**Warning signs:** Memory usage grows over time as server is started/stopped repeatedly. Instruments shows leaked MockServerEngine instances.

## Code Examples

Verified patterns from project conventions and Apple documentation:

### HTTP Request Parsing (Pure Function)

```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.2 + HTTP/1.1 RFC 7230
enum HTTPRequestParser {
    struct ParsedRequest: Sendable {
        let method: String           // "GET", "POST", etc.
        let path: String             // "/api/users"
        let queryString: String?     // "page=1&limit=20"
        let httpVersion: String      // "HTTP/1.1"
        let headers: [String: String]
        let body: String?
    }

    nonisolated static func parse(data: Data) -> ParsedRequest? {
        guard let rawString = String(data: data, encoding: .utf8) else { return nil }

        // Split headers from body at double CRLF
        let parts = rawString.components(separatedBy: "\r\n\r\n")
        guard let headerSection = parts.first else { return nil }
        let body = parts.count > 1 ? parts.dropFirst().joined(separator: "\r\n\r\n") : nil

        // Parse request line: "GET /api/users?page=1 HTTP/1.1"
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count >= 2 else { return nil }

        let method = String(requestParts[0])
        let fullPath = String(requestParts[1])
        let httpVersion = requestParts.count >= 3 ? String(requestParts[2]) : "HTTP/1.1"

        // Separate path from query string
        let pathComponents = fullPath.components(separatedBy: "?")
        let path = pathComponents[0]
        let queryString = pathComponents.count > 1
            ? pathComponents.dropFirst().joined(separator: "?")
            : nil

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { break }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = String(headerParts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return ParsedRequest(
            method: method,
            path: path,
            queryString: queryString,
            httpVersion: httpVersion,
            headers: headers,
            body: body?.isEmpty == true ? nil : body
        )
    }

    /// Parse query string into key-value dictionary
    nonisolated static func parseQueryString(_ queryString: String?) -> [String: String] {
        guard let queryString, !queryString.isEmpty else { return [:] }
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                params[key] = value
            } else if kv.count == 1 {
                params[String(kv[0])] = ""
            }
        }
        return params
    }
}
```

### HTTP Response Building (Pure Function)

```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.3 + HTTP/1.1 RFC 7231
enum HTTPResponseBuilder {
    nonisolated static func build(
        statusCode: Int,
        headers: [String: String] = [:],
        body: String = "",
        corsEnabled: Bool = true
    ) -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusPhrase(statusCode))\r\n"

        var allHeaders = headers
        allHeaders["Server"] = allHeaders["Server"] ?? "MockPad/1.0"
        allHeaders["Date"] = allHeaders["Date"] ?? httpDateString()
        allHeaders["Content-Length"] = String(body.utf8.count)
        allHeaders["Connection"] = "close"

        if corsEnabled {
            allHeaders["Access-Control-Allow-Origin"] =
                allHeaders["Access-Control-Allow-Origin"] ?? "*"
            allHeaders["Access-Control-Allow-Methods"] =
                allHeaders["Access-Control-Allow-Methods"] ?? "GET, POST, PUT, DELETE, PATCH, OPTIONS"
            allHeaders["Access-Control-Allow-Headers"] =
                allHeaders["Access-Control-Allow-Headers"] ?? "Content-Type, Authorization, Accept"
        }

        // Sort headers for deterministic output (helps testing)
        for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            response += "\(key): \(value)\r\n"
        }

        response += "\r\n"
        response += body

        return Data(response.utf8)
    }

    nonisolated static func buildPreflightResponse(corsEnabled: Bool) -> Data {
        build(
            statusCode: 204,
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept",
                "Access-Control-Max-Age": "86400"
            ],
            body: "",
            corsEnabled: corsEnabled
        )
    }

    nonisolated private static func statusPhrase(_ code: Int) -> String {
        switch code {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        default: "Unknown"
        }
    }

    nonisolated private static func httpDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: Date()) + " GMT"
    }
}
```

### Endpoint Matching (Pure Function, Phase 2 Scope)

```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.4
// NOTE: Phase 2 implements EXACT path matching only.
// Path parameters (:id) and wildcards (*) are Phase 6.
enum EndpointMatcher {
    enum MatchResult: Sendable {
        case matched(path: String, method: String, statusCode: Int,
                     responseBody: String, responseHeaders: [String: String])
        case notFound
        case methodNotAllowed(allowedMethods: [String])
    }

    /// Match request to endpoint. Phase 2: exact path match only.
    nonisolated static func match(
        method: String,
        path: String,
        endpoints: [(path: String, method: String, statusCode: Int,
                      responseBody: String, responseHeaders: [String: String],
                      isEnabled: Bool)]
    ) -> MatchResult {
        let enabledEndpoints = endpoints.filter { $0.isEnabled }

        // Find endpoints matching the path
        let pathMatches = enabledEndpoints.filter {
            $0.path.lowercased() == path.lowercased()
        }

        guard !pathMatches.isEmpty else { return .notFound }

        // Find endpoint matching both path and method
        if let match = pathMatches.first(where: {
            $0.method.uppercased() == method.uppercased()
        }) {
            return .matched(
                path: match.path,
                method: match.method,
                statusCode: match.statusCode,
                responseBody: match.responseBody,
                responseHeaders: match.responseHeaders
            )
        }

        // Path matched but method did not -> 405
        let allowedMethods = Array(Set(pathMatches.map { $0.method.uppercased() }))
        return .methodNotAllowed(allowedMethods: allowedMethods)
    }
}
```

**Design note on EndpointMatcher:** The match function accepts a tuple array rather than `[MockEndpoint]` directly. This is intentional -- MockEndpoint is a SwiftData `@Model` class (MainActor-isolated). The MockServerEngine actor cannot safely access MockEndpoint properties. ServerStore (MainActor) extracts the tuple data from MockEndpoint objects and passes it to the engine, which passes it to the matcher. This keeps the matcher pure and testable without SwiftData.

### Sendable DTO for Cross-Actor Request Logging

```swift
// Source: Project pattern (Sendable DTO for cross-actor communication)
struct RequestLogData: Sendable {
    let timestamp: Date
    let method: String
    let path: String
    let queryParameters: [String: String]
    let requestHeaders: [String: String]
    let requestBody: String?
    let responseStatusCode: Int
    let responseBody: String?
    let responseTimeMs: Double
}
```

### Server Error Enum

```swift
enum MockServerError: Error, LocalizedError {
    case invalidPort
    case portInUse(UInt16)
    case listenerFailed(String)
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .invalidPort: "Invalid port number"
        case .portInUse(let port): "Port \(port) is already in use"
        case .listenerFailed(let msg): "Server failed: \(msg)"
        case .alreadyRunning: "Server is already running"
        }
    }
}
```

### Unit Test Pattern for Pure Services

```swift
// Source: Project testing conventions (TESTING.md)
import Testing
import Foundation
@testable import MockPad

struct HTTPRequestParserTests {
    @Test func parseSimpleGET() {
        let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request?.method == "GET")
        #expect(request?.path == "/api/users")
        #expect(request?.headers["Host"] == "localhost")
        #expect(request?.body == nil)
    }

    @Test func parsePOSTWithBody() {
        let raw = "POST /api/users HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"name\":\"John\"}"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request?.method == "POST")
        #expect(request?.body == "{\"name\":\"John\"}")
    }

    @Test func invalidRequest_returnsNil() {
        let raw = "not an http request"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request == nil)
    }

    @Test func headerWithColonInValue() {
        let raw = "GET / HTTP/1.1\r\nHost: localhost:8080\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request?.headers["Host"] == "localhost:8080")
    }

    @Test func queryStringParsing() {
        let raw = "GET /api/users?page=1&limit=20 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request?.path == "/api/users")
        #expect(request?.queryString == "page=1&limit=20")
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BSD sockets (socket/bind/listen/accept) | NWListener + NWConnection (Network framework) | iOS 13 / 2019 | Modern Swift API, automatic TLS negotiation, no manual file descriptor management |
| DispatchQueue for thread safety | Swift actor | Swift 5.5 / 2021 | Compiler-enforced isolation, no manual locking, eliminates data race classes |
| GCDAsyncSocket (third-party) | NWListener (first-party) | iOS 13 / 2019 | Zero-dependency, Apple-maintained, future-proof (HTTP/3 upgrade path) |
| ObservableObject for ServerStore | @Observable macro | iOS 17 / 2023 | Finer-grained tracking, simpler syntax. Already established in Phase 1. |
| NotificationCenter for app lifecycle | @Environment(\.scenePhase) | iOS 14 / 2020 | Declarative SwiftUI pattern, automatic scene tracking |

**Deprecated/outdated:**
- `CFSocket` / `GCDAsyncSocket`: Replaced by Network framework. Do not use.
- `UIApplication.willResignActiveNotification`: Still works but `scenePhase` is the SwiftUI-native approach.

## Open Questions

1. **Should the endpoint data be passed to the engine as a snapshot or fetched per-request?**
   - What we know: EndpointStore.endpoints is a computed property that fetches from SwiftData on every access. Phase 1 research noted this might be slow for per-request matching.
   - What's unclear: Whether the engine should cache a snapshot of endpoint configs (updated on add/delete/edit) or whether ServerStore should pass fresh data per request.
   - Recommendation: Pass endpoint snapshot to engine at start and on any endpoint change. The engine stores a `[EndpointSnapshot]` array (Sendable tuple/struct). ServerStore calls `await engine.updateEndpoints(...)` when endpoints change. This avoids per-request SwiftData fetches from the actor and keeps the hot path fast (<1ms).

2. **How to handle the brief gap between NWListener cancel and port release on real devices?**
   - What we know: `allowLocalEndpointReuse` is bugged on devices. Port release may take up to TIME_WAIT (~2 minutes for TCP, but usually much shorter for localhost).
   - What's unclear: Exact port release timing on iOS devices after NWListener cancel.
   - Recommendation: Use port fallback (SRVR-06) as primary mitigation. If the original port fails, try next available. Also set `allowLocalEndpointReuse = true` anyway (it works on Simulator and may be fixed in future iOS). Show actual port to user in UI.

3. **Should HTTPResponseBuilder create a static DateFormatter or new one per call?**
   - What we know: DateFormatter creation is expensive (~1ms). For a mock server handling many requests, this adds up.
   - What's unclear: Whether the cost matters given typical mock server load (< 10 req/sec).
   - Recommendation: Use a `nonisolated(unsafe) static let` for the DateFormatter since it is only used from one isolation context at a time. Alternatively, use ISO 8601 manual string construction for the HTTP Date header to avoid DateFormatter entirely.

## Sources

### Primary (HIGH confidence)
- [NWListener | Apple Developer Documentation](https://developer.apple.com/documentation/network/nwlistener) -- NWListener API, state handling, port binding
- [NWConnection | Apple Developer Documentation](https://developer.apple.com/documentation/network/nwconnection) -- Connection handling, receive/send API
- [NWParameters | Apple Developer Documentation](https://developer.apple.com/documentation/network/nwparameters) -- acceptLocalOnly, allowLocalEndpointReuse, TCP options
- [ScenePhase | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/scenephase) -- App lifecycle detection for background/foreground
- Project codebase: Phase 1 files (MockEndpoint.swift, RequestLog.swift, EndpointStore.swift, ServerStore.swift) -- Existing data layer this phase builds on
- `.planning/mockpad/MOCKPAD-TECHNICAL.md` -- Server engine architecture spec (Sections 3.1-3.4)

### Secondary (MEDIUM confidence)
- [Swift Forums -- NWListener cancel and re-listen](https://forums.swift.org/t/how-to-listen-cancel-and-re-listen-with-nwlistener/39354) -- Confirmed: must create new NWListener instance after cancel
- [SR-13918 -- NWListener can't cancel and relisten](https://github.com/swiftlang/swift/issues/56316) -- Known bug documentation
- [Apple Developer Forums -- NWListener port in use](https://developer.apple.com/forums/thread/129452) -- Port reuse patterns, allowLocalEndpointReuse workarounds
- [openradar FB8658821 -- allowLocalEndpointReuse ignored](https://openradar.appspot.com/FB8658821) -- Known bug: property ignored on real devices
- [rderik.com -- Building server-client with Network Framework](https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/) -- NWListener/NWConnection patterns, connection tracking
- [ko9.org -- Simple Web Server in Swift](https://ko9.org/posts/simple-swift-web-server/) -- HTTP request parsing, receive loop pattern
- [alwaysrightinstitute.com -- Intro to Network.framework Servers](http://www.alwaysrightinstitute.com/network-framework/) -- NWListener as BSD socket replacement, HTTP response building
- [Swift Forums -- Library callbacks and actor isolation](https://forums.swift.org/t/library-callbacks-and-actor-isolation/58138) -- Pattern for bridging DispatchQueue callbacks to actor isolation
- [HackingWithSwift -- scenePhase tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-when-your-app-moves-to-the-background-or-foreground-with-scenephase) -- scenePhase usage patterns
- [Cancelling SwiftUI Tasks on Background](https://medium.com/@y.mimura1995/cancelling-swiftui-tasks-when-the-app-goes-to-background-5d5fcd2a8f27) -- .task(id: scenePhase) pattern

### Tertiary (LOW confidence)
- None -- all findings verified with official docs or multiple community sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Network framework is the only option for on-device TCP servers on iOS. NWListener API is well-documented and stable since iOS 13.
- Architecture: HIGH -- Actor pattern for server engine is a prior decision. Pure enum services match project conventions (caseless enum pattern from HTTPMethod, ServerConfiguration). Cross-actor communication via Sendable DTOs is standard Swift Concurrency practice.
- Pitfalls: HIGH -- NWListener restart limitation confirmed via SR-13918 bug report and multiple Swift Forum threads. allowLocalEndpointReuse bug confirmed via openradar FB8658821. MainActor isolation on static methods confirmed via build settings analysis.
- Code examples: HIGH -- HTTP parsing based on RFC 7230 + MOCKPAD-TECHNICAL.md verified patterns. Response building based on RFC 7231. All examples use project conventions (caseless enum, nonisolated static, Swift Testing).

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (Network framework is stable, NWListener API unchanged since iOS 13)
