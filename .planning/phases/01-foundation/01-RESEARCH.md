# Phase 1: Foundation - Research

**Researched:** 2026-02-16
**Domain:** SwiftData models, @Observable stores, UserDefaults configuration, Keychain PRO state
**Confidence:** HIGH

## Summary

Phase 1 establishes the data layer that every subsequent phase builds on. The scope is five components: MockEndpoint (SwiftData model), RequestLog (SwiftData model), EndpointStore (@Observable CRUD store), ServerStore (@Observable server configuration), and ProManager (@Observable purchase state with Keychain persistence). No UI screens are built in this phase -- only the models, stores, and their unit tests.

The technical domain is well-understood: SwiftData model definition with computed properties for dictionary storage, @Observable final class stores injected via SwiftUI `.environment()`, UserDefaults for simple server configuration, and Apple Security framework Keychain APIs for PRO purchase state. All components use established patterns from prior projects (DeltaPad, GuardPad, Remynder) and Apple documentation.

The primary challenge is correct SwiftData dictionary storage (headers and query parameters stored as `Data` with computed property accessors) and the concurrency implications of `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on model types that need `Codable` encoding from nonisolated contexts. The `@preconcurrency Codable` conformance pattern resolves this.

**Primary recommendation:** Build models first with comprehensive tests using in-memory ModelContainer, then stores with CRUD tests, then wire into MockPadApp. Replace the template Item.swift before any device runs to avoid unnecessary SwiftData migrations.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Response body stored as String (JSON text) -- supports JSON, plain text, HTML. No binary response support needed
- HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS (extended set)
- Default new endpoint: status 200, body `{}` (empty JSON object)
- Explicit `sortOrder` Int field for manual drag-to-reorder (supports ENDP-09 in Phase 3)
- Store full request + response bodies, capped at 64KB. Truncate larger bodies with "[truncated]" indicator
- Log entries persist across app launches (SwiftData model stored to disk)
- Query parameters stored as separate structured field ([String: String]) alongside the path
- Auto-prune to 1,000 entries handled by the store (not the model) -- store checks count after each insert, deletes oldest
- Default port: 8080
- CORS: on by default
- Auto-start (restart on foreground): on by default
- Server configuration stored in UserDefaults (not SwiftData) -- simple key-value for settings
- 3-endpoint limit counts ALL endpoints (enabled + disabled). "You have 3 slots total"
- Offline PRO verification: trust cached purchase state, keep working, re-verify on next launch with network
- PRO purchase state stored in Keychain (survives reinstall, harder to tamper)
- Import at limit: blocked. Can't import if it would exceed 3 total endpoints

### Claude's Discretion
- SwiftData model relationships and cascade rules
- Store method signatures and error handling patterns
- Exact Keychain wrapper implementation for ProManager
- Whether to use @Observable or ObservableObject for stores

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftData | iOS 26+ | Persistence for MockEndpoint and RequestLog models | Native Swift ORM with @Model macro, @Query reactive binding, automatic SwiftUI integration. Project already uses it. |
| SwiftUI | iOS 26+ | App entry point, environment injection for stores | Provides `.environment()` for @Observable store injection, `.modelContainer()` for SwiftData setup. |
| Foundation | iOS 26+ | JSONEncoder/JSONDecoder for Data<->Dictionary encoding, UserDefaults for server config | Standard library types. No alternatives needed. |
| Security | iOS 26+ | Keychain Services (SecItemAdd, SecItemCopyMatching, SecItemUpdate, SecItemDelete) for PRO state | Apple's native secure storage API. Zero dependencies. Survives app reinstall. |
| Observation | iOS 17+ | @Observable macro for store classes | Replaces ObservableObject pattern. Finer-grained observation tracking, simpler syntax, no @Published needed. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for models and stores | All test files. struct-based suites, @Test func, #expect() assertions. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @Observable | ObservableObject | ObservableObject requires @Published on every property and explicit protocol conformance. @Observable is simpler, has finer-grained tracking, and is the current Apple recommendation for iOS 17+. Use @Observable. |
| Security framework Keychain | SwiftKeychainWrapper / KeychainAccess | Third-party libraries add a dependency for minimal benefit. The Keychain API surface needed here is tiny (save/load/delete a Bool). Hand-roll a ~40-line wrapper using Security framework directly. |
| UserDefaults | SwiftData for server config | Overkill for 4 key-value settings (port, CORS, auto-start, localhost-only). UserDefaults is simpler and matches the DeltaPad/GuardPad pattern. Locked decision. |

## Architecture Patterns

### Recommended Project Structure

```
MockPad/MockPad/
├── App/
│   ├── MockPadApp.swift              # @main, ModelContainer setup, environment injection
│   ├── EndpointStore.swift           # @Observable: CRUD for endpoints via SwiftData
│   ├── ServerStore.swift             # @Observable: server config via UserDefaults, running state
│   └── ProManager.swift              # @Observable: PRO purchase state via Keychain
│
├── Models/
│   ├── MockEndpoint.swift            # @Model: path, method, status, body, headers, enabled, sortOrder
│   ├── RequestLog.swift              # @Model: timestamp, method, path, query params, headers, body, status, timing
│   ├── HTTPMethod.swift              # String enum: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
│   └── ServerConfiguration.swift     # Value type backed by UserDefaults
│
└── Utilities/
    └── KeychainService.swift         # Zero-dependency Keychain wrapper using Security framework
```

### Pattern 1: SwiftData Dictionary Storage via Data + Computed Property

**What:** SwiftData cannot store `[String: String]` directly. Store as `Data` (JSON-encoded) and expose via computed property with get/set.

**When to use:** Response headers on MockEndpoint, request headers on RequestLog, query parameters on RequestLog.

**Why this pattern:** SwiftData persists only stored properties. Computed properties are automatically transient (never persisted). The `Data` property holds the JSON-encoded dictionary; the computed property provides ergonomic access. SwiftData properties do NOT support `willSet`/`didSet`, so the computed property pattern is the only clean approach.

**Example:**
```swift
// Source: Apple Developer Forums + Hacking with Swift SwiftData tutorials
@Model
final class MockEndpoint {
    // Persisted as JSON-encoded Data
    var responseHeadersData: Data?

    // Computed property for ergonomic access (NOT persisted)
    var responseHeaders: [String: String] {
        get {
            guard let data = responseHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            responseHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    init(responseHeaders: [String: String] = ["Content-Type": "application/json"]) {
        self.responseHeadersData = try? JSONEncoder().encode(responseHeaders)
    }
}
```

**Gotcha:** The `Data` property is the persisted one. The computed property is the API consumers use. Do NOT add `@Transient` to the computed property (it is already implicitly transient). Do NOT try to add `willSet`/`didSet` to SwiftData stored properties -- it is not supported.

### Pattern 2: @Observable Store with SwiftData ModelContext

**What:** An `@Observable final class` store holds a reference to `ModelContext` and provides CRUD methods. The store is created at the app root and injected via `.environment()`. Views access it with `@Environment(EndpointStore.self)`.

**When to use:** EndpointStore for endpoint CRUD, ServerStore for server configuration state.

**Why this pattern:** @Observable provides automatic fine-grained observation tracking. SwiftUI re-renders only views that read changed properties. No @Published boilerplate. The store owns the ModelContext and encapsulates all persistence logic, keeping views thin.

**Example:**
```swift
// Source: SwiftData architecture patterns (azamsharp.com, hackingwithswift.com)
@Observable
final class EndpointStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var endpoints: [MockEndpoint] {
        let descriptor = FetchDescriptor<MockEndpoint>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var endpointCount: Int {
        let descriptor = FetchDescriptor<MockEndpoint>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func addEndpoint(_ endpoint: MockEndpoint) {
        modelContext.insert(endpoint)
        try? modelContext.save()
    }

    func deleteEndpoint(_ endpoint: MockEndpoint) {
        modelContext.delete(endpoint)
        try? modelContext.save()
    }
}
```

**Gotcha:** `ModelContext` is NOT Sendable. It must stay on MainActor. Since `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this is the default behavior -- the store and its ModelContext are naturally on MainActor. Do NOT try to pass ModelContext to a background actor.

### Pattern 3: UserDefaults-Backed Server Configuration

**What:** A value type (struct) that reads/writes server settings from UserDefaults. Provides a `static var current` accessor and individual setters that persist immediately.

**When to use:** ServerStore reads configuration from this type. Settings UI writes to it.

**Example:**
```swift
struct ServerConfiguration {
    static var port: UInt16 {
        get {
            let value = UserDefaults.standard.integer(forKey: "serverPort")
            return value == 0 ? 8080 : UInt16(clamping: value)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "serverPort") }
    }

    static var corsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "corsEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "corsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "corsEnabled") }
    }

    static var autoStart: Bool {
        get { UserDefaults.standard.object(forKey: "autoStart") == nil ? true : UserDefaults.standard.bool(forKey: "autoStart") }
        set { UserDefaults.standard.set(newValue, forKey: "autoStart") }
    }
}
```

**Gotcha for defaults:** `UserDefaults.standard.bool(forKey:)` returns `false` when the key does not exist. For settings where the default should be `true` (CORS, auto-start), check `object(forKey:) == nil` first to distinguish "never set" from "explicitly set to false". Alternatively, register defaults in `MockPadApp.init()` using `UserDefaults.standard.register(defaults:)`.

### Pattern 4: Zero-Dependency Keychain Wrapper

**What:** A small utility enum/struct wrapping Apple's Security framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`) for storing the PRO purchase state as a boolean.

**When to use:** ProManager reads/writes PRO status via this wrapper.

**Example:**
```swift
// Source: Apple Security framework docs + radude89.com + advancedswift.com
enum KeychainService {
    private static let service = "com.olof.petterson.MockPad"

    static func saveBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        // Delete existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadBool(forKey key: String) -> Bool? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            return nil
        }
        return data[0] == 1
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

**Why zero-dependency:** The Keychain API surface for this use case is 3 operations (save, load, delete) on a single Bool value. SwiftKeychainWrapper and KeychainAccess are overkill. A ~40-line enum covers everything needed. Matches the zero-dependency philosophy of the project.

### Pattern 5: ProManager with Cached Keychain State

**What:** An `@Observable` singleton that caches the PRO purchase state in memory, backed by Keychain persistence. Provides `isPro` property and `canAddEndpoint(currentCount:)` gating method.

**When to use:** Any feature that needs to check PRO status or enforce the 3-endpoint limit.

**Example:**
```swift
@Observable
final class ProManager {
    static let shared = ProManager()

    private(set) var isPro: Bool

    private init() {
        self.isPro = KeychainService.loadBool(forKey: "isPro") ?? false
    }

    func setPro(_ value: Bool) {
        isPro = value
        KeychainService.saveBool(value, forKey: "isPro")
    }

    func canAddEndpoint(currentCount: Int) -> Bool {
        isPro || currentCount < 3
    }

    func canImportEndpoints(currentCount: Int, importCount: Int) -> Bool {
        isPro || (currentCount + importCount) <= 3
    }
}
```

**Design note:** ProManager is a singleton (`shared`) because purchase state is global and must be consistent across all views. It is injected via `.environment()` at the app root. The actual StoreKit 2 integration is Phase 9 -- this phase only provides the state container and gating logic.

### Anti-Patterns to Avoid

- **Storing [String: String] directly in SwiftData:** SwiftData does not natively support Dictionary storage. It either fails silently or requires Transformable configuration. Use `Data` with computed property instead.

- **Using @Transient in predicates:** `@Transient` properties compile into `#Predicate` expressions but crash at runtime because the data does not exist in the SQLite store. Never filter/sort on transient properties.

- **Adding willSet/didSet to SwiftData stored properties:** SwiftData does not support property observers on stored properties. The macro-generated accessors interfere. Use computed properties or explicit setter methods instead.

- **Using ObservableObject instead of @Observable:** ObservableObject requires @Published on every property and objectWillChange publishers. @Observable is the modern replacement (iOS 17+), provides finer-grained tracking, and is simpler. Since deployment target is iOS 26.2, always use @Observable.

- **Storing PRO state in UserDefaults:** UserDefaults is trivially accessible and modifiable by users with device access. Keychain is encrypted, survives reinstall, and is harder to tamper with. Locked decision: use Keychain.

- **Creating ModelContext on a background thread:** ModelContext is NOT Sendable. It must live on MainActor. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, this is the default. Do not pass ModelContext to a background actor or create one on a background thread.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secure persistent storage | Custom encryption on UserDefaults | Apple Security framework Keychain (SecItemAdd/SecItemCopyMatching) | OS-level encryption, survives reinstall, ~40 lines of wrapper code |
| Dictionary persistence in SwiftData | Custom SQLite or JSON file management | Data property + JSONEncoder/JSONDecoder computed property | Standard SwiftData pattern, no custom persistence layer needed |
| Reactive observation for stores | Custom notification-based pub/sub | @Observable macro (Observation framework) | Automatic fine-grained tracking, no manual subscription management |
| Settings persistence | Custom plist or file-based settings | UserDefaults with register(defaults:) | Apple-provided, KVO-compatible, trivial to use |

**Key insight:** Every component in Phase 1 uses Apple-provided frameworks with thin wrappers. No custom persistence engines, no third-party observation libraries, no external Keychain packages. The complexity is in correct wiring, not novel technology.

## Common Pitfalls

### Pitfall 1: SwiftData Migration When Replacing Item.swift

**What goes wrong:** The project ships with a template `Item.swift` model. If the app is run on a device/simulator before replacing Item with the real models, SwiftData creates a persistent store with the Item schema. When Item is removed and MockEndpoint/RequestLog are added, the schema mismatch causes a crash at `ModelContainer` initialization.

**Why it happens:** SwiftData performs automatic lightweight migration for additive changes (new models, new properties) but cannot handle removal of a model class that was previously registered.

**How to avoid:** Replace Item.swift with the real models BEFORE any device/simulator run. If the app has already been run, delete the app from the simulator/device first, or use an in-memory store during development until the schema stabilizes.

**Warning signs:** `fatalError("Could not create ModelContainer")` at app launch after changing the model schema.

### Pitfall 2: UserDefaults Bool Defaults to False

**What goes wrong:** `UserDefaults.standard.bool(forKey: "corsEnabled")` returns `false` on first launch because the key does not exist. But the locked decision says CORS should be ON by default.

**Why it happens:** UserDefaults returns the zero-value (`false` for Bool, `0` for Int) when a key has never been set. This is indistinguishable from "user explicitly set to false."

**How to avoid:** Use `UserDefaults.standard.register(defaults:)` in `MockPadApp.init()` to set initial values for all config keys. Or check `object(forKey:) == nil` before reading the Bool.

**Warning signs:** CORS or auto-start appear disabled on first app launch despite the spec saying they should be on by default.

### Pitfall 3: @preconcurrency Codable for MainActor-Isolated Models

**What goes wrong:** With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, SwiftData model classes are implicitly MainActor-isolated. If the computed properties use JSONEncoder/JSONDecoder, and those types are called from a nonisolated context (e.g., a background actor in Phase 2), the compiler emits concurrency warnings or errors.

**Why it happens:** JSONEncoder and JSONDecoder are not MainActor-isolated, but the model properties that call them are (by default isolation). The types cross isolation boundaries implicitly.

**How to avoid:** Mark model types with `@preconcurrency Codable` if they need to be encoded/decoded from nonisolated contexts. For Phase 1, since all access is from MainActor, this is not yet a problem -- but plan for it. The computed properties on MockEndpoint and RequestLog that use JSONEncoder/JSONDecoder are fine because they are called from MainActor stores.

**Warning signs:** Swift concurrency warnings about `JSONEncoder.encode` crossing actor boundaries in Phase 2+.

### Pitfall 4: Request Log Auto-Prune Deleting Wrong Entries

**What goes wrong:** The auto-prune logic deletes the oldest entries when count exceeds 1,000. If the fetch order is wrong, the prune might delete the newest entries instead of the oldest.

**Why it happens:** FetchDescriptor sort order determines which entries are "oldest." If sorted ascending by timestamp (oldest first), the last entries in the array are newest. Deleting from the end deletes new entries. Must delete from the beginning.

**How to avoid:** After inserting a new log entry, fetch all entries sorted by timestamp ascending. If count exceeds 1,000, delete entries from index 0 up to (count - 1000). Alternatively, fetch with a predicate that finds entries older than the 1000th newest.

**Warning signs:** Recent log entries disappear while old entries remain after pruning.

### Pitfall 5: Keychain Access Failing Silently on Simulator

**What goes wrong:** Keychain operations may behave differently on Simulator vs. real device. Some Simulator configurations share Keychain state between app runs in unexpected ways.

**Why it happens:** The Simulator's Keychain is a simplified version of the device Keychain. Items may persist across app deletions on Simulator differently than on device.

**How to avoid:** Test Keychain operations on a real device during development. For unit tests, use a protocol-based mock (KeychainServiceProtocol) to decouple ProManager from the real Keychain.

**Warning signs:** PRO state appears to persist on Simulator even after "deleting" it, or PRO state is lost on Simulator when it should persist.

## Code Examples

Verified patterns from project conventions and Apple documentation:

### SwiftData Model with All Phase 1 Fields (MockEndpoint)

```swift
// Source: CONTEXT.md locked decisions + MOCKPAD-TECHNICAL.md model spec
import Foundation
import SwiftData

@Model
final class MockEndpoint {
    var path: String
    var httpMethod: String          // "GET", "POST", etc.
    var responseStatusCode: Int
    var responseBody: String        // JSON text, plain text, or HTML
    var responseHeadersData: Data?  // JSON-encoded [String: String]
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date

    // Computed property for headers (NOT persisted)
    var responseHeaders: [String: String] {
        get {
            guard let data = responseHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            responseHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        path: String,
        httpMethod: String = "GET",
        responseStatusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = ["Content-Type": "application/json"],
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.path = path
        self.httpMethod = httpMethod
        self.responseStatusCode = responseStatusCode
        self.responseBody = responseBody
        self.responseHeadersData = try? JSONEncoder().encode(responseHeaders)
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
```

### SwiftData Model (RequestLog) with Body Truncation

```swift
// Source: CONTEXT.md locked decisions (64KB cap, query params as [String: String])
import Foundation
import SwiftData

@Model
final class RequestLog {
    var timestamp: Date
    var method: String
    var path: String
    var queryParametersData: Data?   // JSON-encoded [String: String]
    var requestHeadersData: Data?    // JSON-encoded [String: String]
    var requestBody: String?
    var responseStatusCode: Int
    var responseBody: String?
    var responseTimeMs: Double

    // Computed properties for dictionary fields
    var queryParameters: [String: String] {
        get {
            guard let data = queryParametersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            queryParametersData = try? JSONEncoder().encode(newValue)
        }
    }

    var requestHeaders: [String: String] {
        get {
            guard let data = requestHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            requestHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    private static let maxBodySize = 64 * 1024  // 64KB

    static func truncateBody(_ body: String?) -> String? {
        guard let body, !body.isEmpty else { return body }
        if body.utf8.count > maxBodySize {
            let truncated = String(body.prefix(maxBodySize))
            return truncated + "\n[truncated]"
        }
        return body
    }

    init(
        timestamp: Date = Date(),
        method: String,
        path: String,
        queryParameters: [String: String] = [:],
        requestHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseStatusCode: Int,
        responseBody: String? = nil,
        responseTimeMs: Double
    ) {
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.queryParametersData = try? JSONEncoder().encode(queryParameters)
        self.requestHeadersData = try? JSONEncoder().encode(requestHeaders)
        self.requestBody = Self.truncateBody(requestBody)
        self.responseStatusCode = responseStatusCode
        self.responseBody = Self.truncateBody(responseBody)
        self.responseTimeMs = responseTimeMs
    }
}
```

### Unit Test for SwiftData Model (In-Memory Container)

```swift
// Source: Project testing conventions (TESTING.md)
import Testing
import Foundation
@testable import MockPad
import SwiftData

@MainActor
struct MockEndpointTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func createEndpointWithDefaults() throws {
        let context = try makeContext()
        let endpoint = MockEndpoint(path: "/api/users")

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched.count == 1)
        #expect(fetched[0].path == "/api/users")
        #expect(fetched[0].httpMethod == "GET")
        #expect(fetched[0].responseStatusCode == 200)
        #expect(fetched[0].responseBody == "{}")
        #expect(fetched[0].isEnabled == true)
    }

    @Test func responseHeadersRoundTrip() throws {
        let context = try makeContext()
        let headers = ["Content-Type": "application/json", "X-Custom": "value"]
        let endpoint = MockEndpoint(path: "/test", responseHeaders: headers)

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched[0].responseHeaders == headers)
    }

    @Test func sortOrderPersists() throws {
        let context = try makeContext()
        let e1 = MockEndpoint(path: "/first", sortOrder: 0)
        let e2 = MockEndpoint(path: "/second", sortOrder: 1)

        context.insert(e1)
        context.insert(e2)
        try context.save()

        let descriptor = FetchDescriptor<MockEndpoint>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched[0].path == "/first")
        #expect(fetched[1].path == "/second")
    }
}
```

### App Entry Point with Store Injection

```swift
// Source: MOCKPAD-TECHNICAL.md Section 2.3 + ARCHITECTURE.md Pattern 4
import SwiftUI
import SwiftData

@main
struct MockPadApp: App {
    let modelContainer: ModelContainer

    @State private var endpointStore: EndpointStore
    @State private var serverStore: ServerStore
    @State private var proManager = ProManager.shared

    init() {
        // Register UserDefaults defaults (CORS on, auto-start on, port 8080)
        UserDefaults.standard.register(defaults: [
            "serverPort": 8080,
            "corsEnabled": true,
            "autoStart": true
        ])

        do {
            let container = try ModelContainer(
                for: MockEndpoint.self, RequestLog.self
            )
            self.modelContainer = container
            let context = ModelContext(container)
            self._endpointStore = State(initialValue: EndpointStore(modelContext: context))
            self._serverStore = State(initialValue: ServerStore())
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(endpointStore)
                .environment(serverStore)
                .environment(proManager)
        }
        .modelContainer(modelContainer)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ObservableObject + @Published | @Observable macro | iOS 17 / WWDC23 | Simpler syntax, finer-grained tracking, no @Published boilerplate |
| @EnvironmentObject | .environment() with @Observable | iOS 17 / WWDC23 | Type-safe injection, no protocol conformance needed |
| Core Data + NSManagedObject | SwiftData + @Model | iOS 17 / WWDC23 | Pure Swift, macro-driven, automatic @Observable conformance |
| NSKeyedArchiver for Codable in Core Data | SwiftData native Codable support for value types | iOS 17 / WWDC23 | Structs/enums conforming to Codable can be stored directly in SwiftData |
| FetchRequest + NSPredicate | @Query + #Predicate | iOS 17 / WWDC23 | Type-safe predicates, compile-time checking |
| Manual observation with NotificationCenter | Observation framework automatic tracking | iOS 17 / WWDC23 | No manual subscription/unsubscription needed |

**Deprecated/outdated:**
- `ObservableObject` protocol: Still works but is legacy. Use `@Observable` for all new code.
- `@EnvironmentObject`: Still works but replaced by `.environment()` with `@Observable` types.
- `@FetchRequest`: Still works in SwiftUI but `@Query` is the SwiftData-native replacement.

## Open Questions

1. **Should EndpointStore expose endpoints as a computed property or hold a cached array?**
   - What we know: Computed property (fetching on access) is always fresh. Cached array requires manual invalidation.
   - What's unclear: Performance of fetching on every access for Phase 2's per-request endpoint matching.
   - Recommendation: Start with computed property. In Phase 2, if per-request fetching is too slow (unlikely at <200 endpoints), add caching with invalidation on insert/update/delete.

2. **Should RequestLog store response headers and response body?**
   - What we know: The CONTEXT.md says "Store full request + response bodies." The success criteria mentions "response time, headers, body." The RequestLog model in MOCKPAD-TECHNICAL.md only stores request-side data.
   - What's unclear: Whether "response body" in the success criteria refers to the log entry itself or inspection of the matched endpoint.
   - Recommendation: Store response headers and response body on RequestLog for complete request/response inspection. The 64KB truncation cap keeps storage manageable. Phase 4 will need this for the request detail drill-down view.

3. **HTTPMethod: String raw value vs. stored String?**
   - What we know: SwiftData can persist enums that conform to Codable with raw values. Using a String enum for HTTP methods provides type safety.
   - What's unclear: Whether SwiftData handles enum migration well if new cases are added later.
   - Recommendation: Use a plain String for `httpMethod` on the model (migration-safe). Provide an `HTTPMethod` enum with static constants for type-safe comparison in code, but store the raw String value. This matches the MOCKPAD-TECHNICAL.md design.

## Sources

### Primary (HIGH confidence)
- [SwiftData | Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata) -- @Model, ModelContainer, ModelContext, @Query
- [Keychain Services | Apple Developer Documentation](https://developer.apple.com/documentation/security/keychain_services) -- SecItemAdd, SecItemCopyMatching, SecItemDelete
- [Observation framework | Apple Developer Documentation](https://developer.apple.com/documentation/observation) -- @Observable macro
- Project codebase: `MockPad/MockPad.xcodeproj/project.pbxproj` -- build settings verification (SWIFT_DEFAULT_ACTOR_ISOLATION, PBXFileSystemSynchronizedRootGroup)
- Project codebase: `MockPad/MockPad/MockPadApp.swift`, `Item.swift`, `ContentView.swift` -- current template state
- `.planning/mockpad/MOCKPAD-TECHNICAL.md` -- data models spec (MockEndpoint, RequestLog, ServerConfiguration)
- `.planning/codebase/CONVENTIONS.md`, `TESTING.md`, `ARCHITECTURE.md` -- project patterns

### Secondary (MEDIUM confidence)
- [Building Type-Safe, High-Performance SwiftData Models](https://fatbobman.com/en/posts/building-typesafe-highperformance-swiftdata-core-data-models/) -- Data + computed property pattern for dictionaries
- [SwiftData Architecture Patterns and Practices](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html) -- @Observable store with ModelContext injection
- [How to make transient attributes in SwiftData](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-make-transient-attributes-in-a-swiftdata-model) -- @Transient gotchas (crashes in predicates)
- [Solving actor-isolated protocol conformance errors in Swift 6.2](https://www.donnywals.com/solving-actor-isolated-protocol-conformance-related-errors-in-swift-6-2/) -- @preconcurrency Codable pattern
- [Secure Data With Keychain In Swift](https://www.advancedswift.com/secure-private-data-keychain-swift/) -- Zero-dependency Keychain wrapper pattern
- [A Glimpse Into the iOS Keychain](https://www.radude89.com/blog/a-glimpse-into-the-ios-keychain.html) -- SecItemAdd/SecItemCopyMatching implementation
- [SwiftData Deep Dive: CRUD Operations](https://medium.com/@appaiah.nb/swiftdata-deep-dive-mastering-modelcontainer-modelcontext-model-objects-and-crud-operations-0f68dbeb83c6) -- ModelContext CRUD patterns

### Tertiary (LOW confidence)
- None -- all findings verified with official or multiple secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All Apple-native frameworks, well-documented, used in prior projects (DeltaPad, GuardPad, Remynder)
- Architecture: HIGH -- @Observable stores, SwiftData models, UserDefaults, Keychain are established patterns with extensive documentation
- Pitfalls: HIGH -- SwiftData dictionary storage, UserDefaults defaults, @preconcurrency Codable all verified across multiple sources
- Code examples: HIGH -- Patterns derived from project conventions (TESTING.md, CONVENTIONS.md) and verified against Apple documentation

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (stable frameworks, 60-day window)
