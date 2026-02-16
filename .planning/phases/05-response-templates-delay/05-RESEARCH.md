# Phase 5: Response Templates + Delay - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI forms, SwiftData model additions, actor-based async delay, response template data modeling
**Confidence:** HIGH

## Summary

Phase 5 adds three features to MockPad: (1) 8 built-in response templates that populate an endpoint's status code, response body, and headers in one tap; (2) custom response templates saved from the current endpoint configuration (PRO); and (3) per-endpoint response delay 0-10,000ms (PRO). All three features build directly on existing patterns in the codebase -- no new frameworks or external dependencies are required.

The built-in templates are pure static data (a caseless enum with 8 template definitions). Custom templates require a new SwiftData `ResponseTemplate` model. Response delay requires a new `responseDelayMs` Int field on `MockEndpoint`, a corresponding field on `EndpointSnapshot` for cross-actor transfer, and a `Task.sleep` call in `MockServerEngine.handleReceivedData` before sending the response. The delay feature is the most architecturally interesting because the sleep must happen inside the actor's request-processing method without blocking other connections (Swift actors are reentrant at suspension points, so `Task.sleep` naturally allows other connections to be processed concurrently).

**Primary recommendation:** Implement in 3 plans: (1) model + data layer (ResponseTemplate model, MockEndpoint.responseDelayMs, EndpointSnapshot.responseDelayMs, built-in template definitions, unit tests), (2) template picker + delay UI (TemplatePicker section in EndpointEditorView, delay Slider section, save-as-template sheet), (3) server engine delay integration (Task.sleep in handleReceivedData, EndpointMatcher tuple expansion, engine test verification).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | ResponseTemplate model persistence | Already used for MockEndpoint, RequestLog |
| SwiftUI | iOS 17+ | Template picker, delay slider UI | Already the UI framework |
| Foundation | N/A | Task.sleep for delay, JSONSerialization for template bodies | Already imported everywhere |

### Supporting
No new libraries needed. All features are built with existing framework capabilities.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData for custom templates | UserDefaults JSON array | SwiftData is consistent with existing patterns; UserDefaults would be simpler but inconsistent |
| Task.sleep for delay | DispatchQueue.asyncAfter | Task.sleep is structured concurrency native, works naturally inside actor methods, is cancellable |
| Static enum for built-in templates | JSON file in bundle | Enum is simpler, type-safe, no I/O needed, matches HTTPMethod pattern |

## Architecture Patterns

### Recommended File Structure
```
MockPad/
├── Models/
│   ├── MockEndpoint.swift        # ADD: responseDelayMs Int field
│   └── ResponseTemplate.swift    # NEW: @Model for custom templates
├── Services/
│   ├── EndpointSnapshot.swift    # ADD: responseDelayMs field
│   ├── MockServerEngine.swift    # ADD: Task.sleep delay before response
│   └── BuiltInTemplates.swift    # NEW: caseless enum with 8 template definitions
├── Views/
│   ├── EndpointEditorView.swift  # ADD: template picker section, delay section
│   ├── TemplatePickerView.swift  # NEW: built-in + custom template list
│   └── SaveTemplateSheet.swift   # NEW: save-as-custom-template sheet (PRO)
└── App/
    ├── EndpointStore.swift       # ADD: endpointSnapshots includes delay
    └── MockPadApp.swift          # ADD: ResponseTemplate to ModelContainer
```

### Pattern 1: Built-In Templates as Static Data
**What:** Caseless enum with static properties defining each template (name, statusCode, responseBody, responseHeaders, category/icon)
**When to use:** Static data that never changes, no persistence needed
**Why this pattern:** Matches existing `HTTPMethod` enum pattern exactly. Type-safe, no I/O.

```swift
enum BuiltInTemplates {
    struct Template: Sendable {
        let name: String
        let statusCode: Int
        let responseBody: String
        let responseHeaders: [String: String]
        let icon: String       // SF Symbol name
        let category: String   // "Success", "Error", etc.
    }

    static let all: [Template] = [success, userObject, userList, notFound, unauthorized, validationError, serverError, rateLimited]

    static let success = Template(
        name: "Success",
        statusCode: 200,
        responseBody: "{\n  \"success\" : true\n}",
        responseHeaders: ["Content-Type": "application/json"],
        icon: "checkmark.circle",
        category: "Success"
    )
    // ... 7 more templates
}
```

### Pattern 2: SwiftData Model for Custom Templates
**What:** `@Model` class for user-saved response templates, persisted alongside MockEndpoint
**When to use:** User-created data that must survive app launches
**Why this pattern:** Consistent with MockEndpoint and RequestLog models

```swift
@Model
final class ResponseTemplate {
    var name: String
    var statusCode: Int
    var responseBody: String
    var responseHeadersData: Data?  // JSON-encoded [String: String], same pattern as MockEndpoint
    var createdAt: Date

    var responseHeaders: [String: String] {
        get { /* same decode pattern as MockEndpoint */ }
        set { /* same encode pattern */ }
    }
}
```

### Pattern 3: Actor-Safe Delay with Task.sleep
**What:** `Task.sleep(for: .milliseconds(delay))` inside `MockServerEngine.handleReceivedData` before `sendResponse`
**When to use:** When a delay must happen inside an actor without blocking other connections
**Why this pattern:** Swift actors are reentrant at await suspension points. When one connection's handler hits `Task.sleep`, the actor can process other incoming connections during the wait. This is exactly the desired behavior -- delay one response without blocking the entire server.

```swift
// Inside MockServerEngine.handleReceivedData, after building responseData:
if snapshot.responseDelayMs > 0 {
    try? await Task.sleep(for: .milliseconds(snapshot.responseDelayMs))
}
sendResponse(responseData, on: connection, id: id)
```

**CRITICAL: Actor reentrancy is the feature here, not a bug.** During the sleep, other connections proceed normally. No thread blocking occurs.

### Pattern 4: Delay Field Flow Through Existing Architecture
**What:** `responseDelayMs` must flow from SwiftData model -> EndpointSnapshot -> MockServerEngine
**When to use:** Any new per-endpoint field that affects server behavior

The existing data flow is:
1. `MockEndpoint.responseDelayMs` (SwiftData, MainActor)
2. `EndpointStore.endpointSnapshots` maps to `EndpointSnapshot` (Sendable DTO)
3. `MockServerEngine` receives `[EndpointSnapshot]` and uses them for matching
4. `EndpointMatcher.EndpointData` tuple carries the field through matching
5. `MatchResult.matched` returns the delay value
6. Engine applies delay before sending

### Pattern 5: Template Application to Endpoint
**What:** Applying a template overwrites endpoint's statusCode, responseBody, and responseHeaders
**When to use:** When user taps a built-in or custom template
**Why this pattern:** Templates are "presets" -- they set multiple fields at once. The existing auto-save `onChange` pattern in EndpointEditorView handles persistence automatically.

```swift
func applyTemplate(_ template: BuiltInTemplates.Template, to endpoint: MockEndpoint) {
    endpoint.responseStatusCode = template.statusCode
    endpoint.responseBody = template.responseBody
    endpoint.responseHeaders = template.responseHeaders
    // onChange handlers trigger saveAndSync() automatically
}
```

### Anti-Patterns to Avoid
- **Blocking the actor with Thread.sleep:** Never use `Thread.sleep` or `usleep` inside an actor -- it blocks the entire cooperative thread pool executor. Always use `Task.sleep`.
- **Storing delay in EndpointMatcher.EndpointData but not using it:** The delay must be extracted from the match result and applied in the engine, not in the matcher.
- **Applying template without triggering save:** Must ensure `saveAndSync()` fires after template application. The `onChange` modifiers on EndpointEditorView fields handle this.
- **Making handleReceivedData async without considering current callers:** `handleReceivedData` is already called inside a `Task` from the receive callback -- adding `await Task.sleep` does not change the call pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async delay | DispatchQueue timers, manual RunLoop | `Task.sleep(for: .milliseconds(n))` | Built into structured concurrency, cancellable, actor-safe |
| JSON template bodies | String interpolation with manual escaping | JSONSerialization with .prettyPrinted + .sortedKeys | Matches existing pattern in ResponseBodyEditorView, deterministic output |
| Template persistence | File-based storage, UserDefaults | SwiftData @Model | Consistent with existing data layer, queryable, migrateable |

**Key insight:** This phase requires zero external dependencies. All features are achievable with Foundation + SwiftUI + SwiftData, following patterns already established in Phases 1-4.

## Common Pitfalls

### Pitfall 1: Forgetting to Add ResponseTemplate to ModelContainer
**What goes wrong:** App crashes on launch with "type not found in schema" error
**Why it happens:** SwiftData requires all model types to be registered in the ModelContainer initializer
**How to avoid:** Add `ResponseTemplate.self` to the `ModelContainer(for:)` call in `MockPadApp.init()`
**Warning signs:** Fatal error on launch after adding the new model

### Pitfall 2: Actor Reentrancy Mutating State After Sleep
**What goes wrong:** After `Task.sleep`, the connection may have been cancelled or the endpoint list may have changed
**Why it happens:** Actor reentrancy means other code can run during the suspension point
**How to avoid:** After sleep, check that the connection is still valid before sending. The existing `sendResponse` -> `connection.send` pattern handles cancelled connections gracefully (NWConnection.send to a cancelled connection is a no-op that calls the completion with an error).
**Warning signs:** Responses sent to already-cancelled connections (benign but wasteful)

### Pitfall 3: SwiftData Lightweight Migration for New Field
**What goes wrong:** Existing MockEndpoint records fail to load after adding responseDelayMs
**Why it happens:** New non-optional field without default value
**How to avoid:** Give `responseDelayMs` a default value of `0` in the @Model. SwiftData lightweight migration handles new fields with defaults automatically.
**Warning signs:** Fetch returns empty arrays after app update

### Pitfall 4: Template Picker Overwriting Headers User Expects to Keep
**What goes wrong:** User has carefully configured custom headers, applies template, and loses them
**Why it happens:** Template application sets responseHeaders to the template's headers, overwriting all custom headers
**How to avoid:** This is expected behavior (template is a "preset"), but the UI should make it clear that applying a template replaces the current configuration. A confirmation or "undo" is nice-to-have but not required for v1.
**Warning signs:** User confusion about lost headers

### Pitfall 5: Delay Slider Precision at High Values
**What goes wrong:** Slider becomes imprecise when range is 0-10,000ms; difficult to set exact values like 500ms
**Why it happens:** Linear Slider over a 10,000-point range maps each pixel to many milliseconds
**How to avoid:** Use a Slider for quick selection + a TextField for precise entry (same pattern as StatusCodePickerView's quick-select + custom input). Consider snapping to common values (100, 250, 500, 1000, 2000, 5000, 10000).
**Warning signs:** User frustration with imprecise slider

### Pitfall 6: Delay Value Included in Response Time Logging
**What goes wrong:** Request log shows 2,005ms response time for a request with 2,000ms delay + 5ms actual processing
**Why it happens:** The `startTime` is captured at the beginning of `handleReceivedData`, and `responseTimeMs` is calculated after the delay
**How to avoid:** This is actually CORRECT behavior per success criterion 5 ("Server waits specified delay before sending response (verified in request log timing)"). The log should show the total time including delay. The delay IS the response time from the client's perspective.
**Warning signs:** None -- this is the desired behavior

## Code Examples

### Example 1: Built-In Template Definitions (8 Required Templates)

```swift
// BuiltInTemplates.swift
enum BuiltInTemplates {
    struct Template: Sendable, Identifiable {
        let id: String  // unique identifier
        let name: String
        let statusCode: Int
        let responseBody: String
        let responseHeaders: [String: String]
        let icon: String
    }

    static let all: [Template] = [
        Template(
            id: "success",
            name: "Success",
            statusCode: 200,
            responseBody: """
            {
              "success" : true,
              "message" : "OK"
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "checkmark.circle"
        ),
        Template(
            id: "user-object",
            name: "User Object",
            statusCode: 200,
            responseBody: """
            {
              "id" : 1,
              "name" : "Jane Doe",
              "email" : "jane@example.com",
              "role" : "admin"
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "person.circle"
        ),
        Template(
            id: "user-list",
            name: "User List",
            statusCode: 200,
            responseBody: """
            {
              "data" : [
                {
                  "id" : 1,
                  "name" : "Jane Doe",
                  "email" : "jane@example.com"
                },
                {
                  "id" : 2,
                  "name" : "John Smith",
                  "email" : "john@example.com"
                }
              ],
              "total" : 2
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "person.2.circle"
        ),
        Template(
            id: "not-found",
            name: "Not Found",
            statusCode: 404,
            responseBody: """
            {
              "error" : "Not Found",
              "message" : "The requested resource was not found"
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "questionmark.circle"
        ),
        Template(
            id: "unauthorized",
            name: "Unauthorized",
            statusCode: 401,
            responseBody: """
            {
              "error" : "Unauthorized",
              "message" : "Authentication required"
            }
            """,
            responseHeaders: ["Content-Type": "application/json", "WWW-Authenticate": "Bearer"],
            icon: "lock.circle"
        ),
        Template(
            id: "validation-error",
            name: "Validation Error",
            statusCode: 422,
            responseBody: """
            {
              "error" : "Validation Error",
              "errors" : [
                {
                  "field" : "email",
                  "message" : "Invalid email format"
                },
                {
                  "field" : "name",
                  "message" : "Name is required"
                }
              ]
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "exclamationmark.triangle"
        ),
        Template(
            id: "server-error",
            name: "Server Error",
            statusCode: 500,
            responseBody: """
            {
              "error" : "Internal Server Error",
              "message" : "An unexpected error occurred"
            }
            """,
            responseHeaders: ["Content-Type": "application/json"],
            icon: "xmark.octagon"
        ),
        Template(
            id: "rate-limited",
            name: "Rate Limited",
            statusCode: 429,
            responseBody: """
            {
              "error" : "Too Many Requests",
              "message" : "Rate limit exceeded. Try again later.",
              "retryAfter" : 60
            }
            """,
            responseHeaders: ["Content-Type": "application/json", "Retry-After": "60"],
            icon: "gauge.with.needle"
        )
    ]
}
```

### Example 2: MockEndpoint Delay Field Addition

```swift
// In MockEndpoint.swift -- add new field
@Model
final class MockEndpoint {
    // ... existing fields ...
    var responseDelayMs: Int  // NEW: 0 = no delay, max 10000

    init(
        path: String,
        httpMethod: String = "GET",
        responseStatusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = ["Content-Type": "application/json"],
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        responseDelayMs: Int = 0  // NEW: default 0
    ) {
        // ... existing init + self.responseDelayMs = responseDelayMs
    }
}
```

### Example 3: EndpointSnapshot Delay Field

```swift
struct EndpointSnapshot: Sendable {
    let path: String
    let method: String
    let statusCode: Int
    let responseBody: String
    let responseHeaders: [String: String]
    let isEnabled: Bool
    let responseDelayMs: Int  // NEW
}
```

### Example 4: Server Engine Delay Implementation

```swift
// In MockServerEngine.handleReceivedData, after building responseData:
case .matched(let path, _, let statusCode, let body, let headers, let delayMs):
    // ... existing response building ...

    // Apply delay before sending
    if delayMs > 0 {
        try? await Task.sleep(for: .milliseconds(delayMs))
    }

// NOTE: handleReceivedData must become async (it already runs inside Task)
```

### Example 5: Delay UI in EndpointEditorView

```swift
// New section in EndpointEditorView Form
Section {
    VStack(alignment: .leading, spacing: MockPadMetrics.paddingSmall) {
        HStack {
            Text("> RESPONSE DELAY_")
                .blueprintLabelStyle()
            Spacer()
            Text("\(endpoint.responseDelayMs)ms")
                .font(MockPadTypography.monoSmall)
                .foregroundColor(MockPadColors.textAccent)
        }

        Slider(
            value: Binding(
                get: { Double(endpoint.responseDelayMs) },
                set: { endpoint.responseDelayMs = Int($0) }
            ),
            in: 0...10000,
            step: 100
        )
        .tint(MockPadColors.accent)
    }
    // PRO gate overlay if !proManager.isPro
}
.listRowBackground(MockPadColors.panel)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Thread.sleep / usleep | Task.sleep(for:) | Swift 5.7+ (2022) | Non-blocking, cancellable, actor-safe |
| GCD dispatch_after | Task.sleep in structured concurrency | Swift 5.5+ (2021) | Works naturally inside actors |
| Core Data for templates | SwiftData @Model | iOS 17+ (2023) | Declarative, less boilerplate |

**Deprecated/outdated:**
- `Thread.sleep`: Blocks the cooperative thread pool in actor context -- must not be used
- `usleep`: Same blocking issue, plus non-cancellable

## Open Questions

1. **Template Picker UI Placement**
   - What we know: Templates must be accessible from the EndpointEditorView
   - What's unclear: Should templates be a section in the Form, a toolbar button opening a sheet, or a context menu?
   - Recommendation: A dedicated "Templates" section in the Form with a list of built-in templates + custom templates below the path/method/status sections. Most discoverable approach. Alternatively, a toolbar button that opens a sheet -- less cluttered Form but less discoverable.

2. **Custom Template Name Input**
   - What we know: User saves current endpoint config as a custom template (PRO)
   - What's unclear: How does the user name the template? Required field? Auto-generated from path?
   - Recommendation: Show a sheet with a text field for the template name, pre-filled with the endpoint path. User can edit before saving.

3. **Custom Template Deletion**
   - What we know: Requirements don't explicitly mention deleting custom templates
   - What's unclear: Should we support it in v1?
   - Recommendation: Yes, add swipe-to-delete on custom templates in the picker. Minimal effort, prevents permanent accumulation.

4. **Delay Slider Step Size**
   - What we know: Range is 0-10,000ms
   - What's unclear: What step increments are most useful?
   - Recommendation: 100ms steps for the slider (giving 100 discrete positions) with a text field for exact values. Common presets: 0, 100, 250, 500, 1000, 2000, 5000, 10000.

## Sources

### Primary (HIGH confidence)
- **Codebase inspection** - MockEndpoint.swift, EndpointSnapshot.swift, MockServerEngine.swift, EndpointStore.swift, EndpointEditorView.swift, ProManager.swift, StatusCodePickerView.swift, ResponseBodyEditorView.swift, ResponseHeadersEditorView.swift (all read and analyzed)
- **Apple Swift Concurrency** - Task.sleep(for:) is non-blocking inside actors, actors are reentrant at suspension points (verified from Swift language documentation)
- **SwiftData** - Lightweight migration automatically handles new fields with default values (established pattern from existing codebase: MockEndpoint already uses this)

### Secondary (MEDIUM confidence)
- **Actor reentrancy behavior** - Multiple connections can be processed while one sleeps. Verified from Swift concurrency design documents and consistent with the existing Task-bridging pattern in MockServerEngine.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, all Foundation/SwiftUI/SwiftData
- Architecture: HIGH - Direct extension of existing patterns (new SwiftData model, new EndpointSnapshot field, actor Task.sleep)
- Pitfalls: HIGH - Identified from direct codebase analysis (ModelContainer registration, lightweight migration, actor reentrancy, slider precision)

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (stable -- no external dependencies that could change)
