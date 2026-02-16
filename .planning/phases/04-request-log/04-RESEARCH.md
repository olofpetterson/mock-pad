# Phase 4: Request Log - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI real-time log view, SwiftData querying/filtering, cURL generation, filter chips, search, clipboard interaction
**Confidence:** HIGH

## Summary

Phase 4 builds the Request Log UI -- the views that let users observe incoming HTTP requests in real time, inspect full request/response details, filter by method/status, search by path, clear the log, and copy requests as cURL commands. The data layer (RequestLog SwiftData model, EndpointStore.addLogEntry/pruneOldEntries, RequestLogData Sendable DTO, MockServerEngine.onRequestLogged callback) is already fully built in Phases 1-2. This phase is purely UI: views that read from SwiftData and present the logged data.

The core challenge is real-time updates. When the server receives a request, the MockServerEngine actor fires `onRequestLogged`, which hops to MainActor via `Task { @MainActor in }` in ServerStore, creates a RequestLog SwiftData object via `EndpointStore.addLogEntry()`, and saves. The UI needs to reactively reflect these new entries. SwiftData's `@Query` macro provides automatic reactivity -- when new RequestLog objects are inserted, any view using `@Query` with a `FetchDescriptor<RequestLog>` will automatically re-render. This is the standard SwiftUI + SwiftData live-update pattern.

Key architectural decisions: (1) the RequestLog model is already persisted in SwiftData (not in-memory as the UX spec suggested -- the Phase 1 decision locks SwiftData persistence), (2) the auto-prune to 1,000 entries is already implemented in EndpointStore, (3) the model currently lacks `responseHeadersData` and `matchedEndpointPath` fields needed for RLOG-04, which requires adding these fields. The cURL generation (RLOG-09) is a pure function that reads from RequestLog fields and builds a string -- straightforward to implement as a static method on a caseless enum service.

**Primary recommendation:** Build in three plans: (1) RequestLogListView with real-time display using @Query, filter chips for method/status, search bar, and clear button; (2) RequestDetailView for full request/response inspection with collapsible sections; (3) CurlGenerator service + copy-to-clipboard integration + model migration to add response headers and matched endpoint fields.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI | iOS 26+ | RequestLogListView, RequestDetailView, filter chips, search bar | Native declarative UI framework. Project's UI layer. |
| SwiftData | iOS 26+ | @Query for live RequestLog fetching, FetchDescriptor for filtering/sorting | Already established. RequestLog model exists. @Query provides automatic reactivity. |
| Foundation | iOS 26+ | DateFormatter for timestamps, UIPasteboard for clipboard, URLComponents for cURL building | Standard library. |
| Observation | iOS 17+ | @Observable on EndpointStore for log count, clearLog operations | Already established in Phase 1. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for CurlGenerator, filter predicate logic | All non-UI logic should have unit tests. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @Query for live updates | Polling EndpointStore on a timer | @Query is reactive and automatic. Polling wastes CPU and introduces latency. Use @Query. |
| SwiftData persistence for logs | In-memory array on EndpointStore | UX spec Section 6.2 suggested in-memory, but Phase 1 already committed to SwiftData with RequestLog @Model. Changing would require ripping out existing model, tests, and EndpointStore methods. Keep SwiftData. |
| Static filter predicates | SwiftData #Predicate macro | #Predicate with compound conditions works for method + status filtering. Standard SwiftData approach. |
| Caseless enum for CurlGenerator | Extension on RequestLog | Caseless enum matches project convention (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher). Keep consistent. |

## Architecture Patterns

### Recommended View Structure

```
MockPad/MockPad/
├── Views/
│   ├── RequestLogListView.swift        # Main log list with @Query, filters, search, clear
│   ├── RequestLogRowView.swift         # Single log row: timestamp, method badge, path, status, time
│   ├── RequestDetailView.swift         # Full request/response detail (push navigation)
│   ├── LogFilterChipsView.swift        # Horizontal scroll of method + status filter chips
│   └── ... (existing views)
│
├── Services/
│   ├── CurlGenerator.swift             # NEW: caseless enum, static func to generate cURL string
│   └── ... (existing services)
│
└── App/
    ├── EndpointStore.swift             # MODIFY: add clearLog(), fetchLogs(filter) methods
    └── ... (existing stores)
```

### Pattern 1: @Query for Real-Time Log Display

**What:** Use SwiftData's `@Query` macro in RequestLogListView to automatically react to new RequestLog insertions. The server engine fires the callback, EndpointStore inserts the log, SwiftData notifies the view, and the list updates.

**When to use:** The main log list view.

**Why this pattern:** @Query provides automatic reactivity -- when EndpointStore.addLogEntry() inserts a new RequestLog and calls modelContext.save(), any view using @Query with RequestLog will re-render. No manual notification, no Combine publishers, no polling.

**Example:**
```swift
struct RequestLogListView: View {
    @Query(sort: \RequestLog.timestamp, order: .reverse)
    private var logs: [RequestLog]

    var body: some View {
        List(filteredLogs) { log in
            NavigationLink {
                RequestDetailView(log: log)
            } label: {
                RequestLogRowView(log: log)
            }
        }
    }

    private var filteredLogs: [RequestLog] {
        logs.filter { log in
            matchesMethodFilter(log) && matchesStatusFilter(log) && matchesSearch(log)
        }
    }
}
```

**Important detail:** @Query fetches ALL RequestLog entries (up to the 1,000 limit enforced by auto-prune). Client-side filtering in the computed property is acceptable for 1,000 entries. SwiftData #Predicate server-side filtering is an optimization that can be added if performance warrants, but for 1,000 rows of simple data, in-memory filtering is negligible.

### Pattern 2: Filter Chips as Toggle State

**What:** Method filter chips (GET, POST, PUT, DELETE) and status filter chips (2xx, 4xx, 5xx) are @State Sets that toggle on tap. Active chips apply as AND filters. If no chips are active, all entries are shown (no filter = show all).

**When to use:** RLOG-05 (method filter) and RLOG-06 (status filter).

**Example:**
```swift
@State private var activeMethodFilters: Set<String> = []
@State private var activeStatusFilters: Set<String> = [] // "2xx", "4xx", "5xx"
@State private var searchText: String = ""

private var filteredLogs: [RequestLog] {
    logs.filter { log in
        let methodMatch = activeMethodFilters.isEmpty || activeMethodFilters.contains(log.method)
        let statusMatch = activeStatusFilters.isEmpty || activeStatusFilters.contains(statusCategory(log.responseStatusCode))
        let searchMatch = searchText.isEmpty || log.path.localizedCaseInsensitiveContains(searchText)
        return methodMatch && statusMatch && searchMatch
    }
}

private func statusCategory(_ code: Int) -> String {
    switch code {
    case 200..<300: return "2xx"
    case 400..<500: return "4xx"
    case 500..<600: return "5xx"
    default: return "other"
    }
}
```

**UX from MOCKPAD-UX.md Section 2.7:** Filter chips are toggle pills. Tapping a chip toggles its active state. Active chips have accent background. Inactive chips have panel2 background. Multiple chips can be active (AND logic). A search text field filters by path substring.

### Pattern 3: CurlGenerator as Pure Caseless Enum

**What:** A stateless service that takes RequestLog data and produces a cURL command string. Follows the project convention of pure caseless enums with nonisolated static methods.

**When to use:** RLOG-09 (copy logged request as cURL command).

**Example:**
```swift
enum CurlGenerator {
    nonisolated static func generate(
        method: String,
        path: String,
        headers: [String: String],
        body: String?,
        baseURL: String = "http://localhost:8080"
    ) -> String {
        var parts = ["curl"]

        // Method (only if not GET)
        if method.uppercased() != "GET" {
            parts.append("-X \(method.uppercased())")
        }

        // URL
        parts.append("'\(baseURL)\(path)'")

        // Headers
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            parts.append("-H '\(key): \(value)'")
        }

        // Body
        if let body, !body.isEmpty {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escaped)'")
        }

        return parts.joined(separator: " \\\n  ")
    }
}
```

### Pattern 4: Clear Log via EndpointStore

**What:** Add a `clearLog()` method to EndpointStore that deletes all RequestLog entries from SwiftData. The button in the UI calls this method. @Query automatically reflects the empty state.

**When to use:** RLOG-08 (clear entire request log).

**Example:**
```swift
// In EndpointStore
func clearLog() {
    let descriptor = FetchDescriptor<RequestLog>()
    guard let allLogs = try? modelContext.fetch(descriptor) else { return }
    for log in allLogs {
        modelContext.delete(log)
    }
    try? modelContext.save()
}
```

### Pattern 5: RequestDetailView with Collapsible Sections

**What:** Push navigation detail view showing full request info (method, path, timestamp, query params, headers, body) and response info (status, matched endpoint, response headers, response body, timing). Each section uses a DisclosureGroup or custom collapsible.

**When to use:** RLOG-03 (request details) and RLOG-04 (response details).

**UX from MOCKPAD-UX.md Section 2.7:** The detail view shows REQUEST section (method, path, time) + REQUEST HEADERS (collapsible) + REQUEST BODY (collapsible) + RESPONSE SENT section (status, time, matched endpoint, headers, body). "Jump to Endpoint" button navigates to the matched endpoint's editor.

### Pattern 6: Copy to Clipboard with UIPasteboard

**What:** UIPasteboard.general.string to copy the cURL command. A brief "Copied" feedback (toast or button state change) confirms the action.

**When to use:** RLOG-09.

**Example:**
```swift
Button {
    let curl = CurlGenerator.generate(
        method: log.method,
        path: log.path,
        headers: log.requestHeaders,
        body: log.requestBody
    )
    UIPasteboard.general.string = curl
    showCopiedFeedback = true
} label: {
    Label("Copy as cURL", systemImage: "doc.on.doc")
}
```

### Anti-Patterns to Avoid

- **Using a timer to poll for new logs:** @Query handles reactivity automatically. Polling is unnecessary and wastes resources.

- **Building the filter with SwiftData #Predicate for every chip change:** For 1,000 entries, client-side filtering in a computed property is fast and simpler than constructing dynamic predicates. Use simple array filtering.

- **Forgetting to sort by timestamp descending:** Log entries must appear newest-first per UX spec. @Query(sort: \RequestLog.timestamp, order: .reverse) handles this.

- **Blocking the main thread in clearLog():** Deleting 1,000 SwiftData objects should be fast (simple in-memory + SQLite deletes), but wrap in a try? modelContext.save() without holding UI. The @Query will reactively update.

- **Using Color or Image without intrinsic size in ScrollView:** Project memory warns about infinite layout loops. All colored elements in the filter chips and log rows must have explicit sizes.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time list updates | Manual notification/observation system | SwiftData @Query macro | Automatic reactivity. When addLogEntry() saves, @Query re-fetches. Zero custom code. |
| cURL escaping | Manual string escaping with edge cases | Shell-standard single-quote escaping with `'\\''` for embedded quotes | cURL uses single-quote escaping convention. Simple replacement covers 99% of cases. |
| Timestamp formatting | Manual string construction | Date.FormatStyle or DateFormatter | Built-in, locale-aware (but we want fixed HH:mm:ss.SSS format for technical log). |
| Clipboard access | Custom clipboard service | UIPasteboard.general.string | One line. Built-in. |
| Horizontal scroll for filter chips | Custom horizontal scroll | ScrollView(.horizontal) with HStack | Standard SwiftUI pattern. |

**Key insight:** Phase 4 is almost entirely SwiftUI view code consuming already-built data layer components. The only new service is CurlGenerator (~30 lines). The data model needs minor additions (response headers, matched endpoint path fields) but the core persistence + auto-prune infrastructure is complete.

## Common Pitfalls

### Pitfall 1: RequestLog Model Missing Fields for RLOG-04

**What goes wrong:** The current RequestLog model lacks `responseHeadersData` and `matchedEndpointPath` fields. RLOG-04 requires showing "matched endpoint" and "response headers" in the detail view. Without these fields, the detail view cannot display this information.

**Why it happens:** The Phase 1 model was designed for the minimal log use case. The full detail view requirements (RLOG-04) need additional data.

**How to avoid:** Add `responseHeadersData: Data?` (with computed `responseHeaders: [String: String]` accessor, same pattern as requestHeadersData) and `matchedEndpointPath: String?` to RequestLog. Update RequestLogData DTO to carry these fields. Update MockServerEngine.handleReceivedData to populate them from the match result. SwiftData lightweight migration handles new optional fields automatically (no explicit migration needed).

**Warning signs:** Detail view shows "No matched endpoint" for all entries, or response headers section is always empty.

### Pitfall 2: @Query Re-Fetching Entire Dataset on Every Insert

**What goes wrong:** Every time a new log entry is inserted (potentially many per second under load), @Query re-fetches the entire dataset and SwiftUI diffs the list.

**Why it happens:** @Query is reactive -- any change to the model triggers a re-fetch. With rapid inserts (e.g., 10 requests/second), this means 10 full re-fetches per second.

**How to avoid:** For MockPad's use case (mock server, typically < 10 req/sec, max 1,000 entries), this is fine. SwiftData's fetch is fast for 1,000 rows. SwiftUI's List diff is efficient for appending new items. If performance becomes an issue (very unlikely), add a limit to @Query: `@Query(sort: \RequestLog.timestamp, order: .reverse, limit: 100)` to only show the most recent 100. But start without the limit -- premature optimization is unnecessary here.

**Warning signs:** Visible lag or stuttering when receiving many requests rapidly. Profile with Instruments if suspected.

### Pitfall 3: Scroll Position Reset on New Entries

**What goes wrong:** User scrolls up to inspect an older log entry. New entry arrives, @Query triggers re-render, and the list jumps back to the top.

**Why it happens:** SwiftUI List preserves scroll position when items are appended, but only if the item identity is stable. If the list is re-sorted or filtered differently, scroll position may reset.

**How to avoid:** Use stable identity for list items (RequestLog's SwiftData persistentModelID). Sort by timestamp descending (newest first). New entries appear at the top of the list. When the user has scrolled down, the new entry appears above the visible area and does NOT disrupt scroll position. This is the default SwiftUI List behavior when items are prepended. The UX spec mentions a "New requests" pill for when the user has scrolled -- this is a nice-to-have polish item, not a blocker.

**Warning signs:** List jumps to top when user is reading an older entry.

### Pitfall 4: cURL Generation Edge Cases

**What goes wrong:** The generated cURL command fails when pasted into a terminal due to special characters in headers, body, or path.

**Why it happens:** HTTP request data can contain single quotes, double quotes, newlines, and other shell-special characters. Naive string concatenation produces invalid cURL commands.

**How to avoid:** Use single-quote wrapping for all values (cURL convention). Escape embedded single quotes with the `'\''` pattern (end single-quote, add escaped literal single-quote, start new single-quote). This handles 99% of cases. For the URL, use percent-encoding for any non-URL-safe characters. For the body, the single-quote escaping handles JSON content safely.

**Warning signs:** Pasting the cURL command into Terminal produces "unexpected token" or "unterminated string" errors.

### Pitfall 5: Empty State Confusion

**What goes wrong:** User sees an empty log list and does not know why -- is the server stopped? Are there no requests? Are filters hiding entries?

**Why it happens:** Multiple reasons for an empty list (server not running, no requests received, filters too restrictive) all look the same.

**How to avoid:** Show contextual empty states:
1. Server not running: "Start the server to begin logging requests."
2. Server running, no requests: "No requests yet. Send requests to see them logged."
3. Filters active, no matches: "No requests match your filters." with a "Clear Filters" button.

Use ServerStore.isRunning and the filter state to determine which message to show.

**Warning signs:** Users report "the log doesn't work" when actually filters are hiding all entries.

### Pitfall 6: NavigationLink to RequestDetailView with @Model

**What goes wrong:** `NavigationLink(value: log)` requires RequestLog to be Hashable. SwiftData @Model classes are Hashable by default (via persistentModelID), but the navigation destination needs careful setup.

**Why it happens:** The existing pattern uses `NavigationLink { destination } label: { content }` which works without Hashable. The alternative `navigationDestination(for:)` pattern requires Hashable conformance.

**How to avoid:** Use the same pattern as EndpointListView: `NavigationLink { RequestDetailView(log: log) } label: { RequestLogRowView(log: log) }`. This is the established project pattern (Phase 3 Plan 03-02 decision). No Hashable conformance needed.

**Warning signs:** Compiler error about Hashable on NavigationLink.

## Code Examples

Verified patterns from the existing codebase:

### Existing RequestLog Model (Already Built)

From `/workspace/MockPad/MockPad/Models/RequestLog.swift`:

```swift
@Model
final class RequestLog {
    var timestamp: Date
    var method: String
    var path: String
    var queryParametersData: Data?
    var requestHeadersData: Data?
    var requestBody: String?
    var responseStatusCode: Int
    var responseBody: String?
    var responseTimeMs: Double

    // Computed accessors for queryParameters and requestHeaders
    // Body truncation at 64KB
    // init with all fields
}
```

**Fields needed for RLOG-04 (not yet present):**
- `responseHeadersData: Data?` (with computed `responseHeaders: [String: String]` accessor)
- `matchedEndpointPath: String?` (the path pattern of the matched endpoint, e.g., "/api/users/:id")

### Existing EndpointStore Log Methods (Already Built)

From `/workspace/MockPad/MockPad/App/EndpointStore.swift`:

```swift
func addLogEntry(_ log: RequestLog) {
    modelContext.insert(log)
    try? modelContext.save()
    pruneOldEntries()
}

private func pruneOldEntries() {
    // Keeps max 1,000 entries, deletes oldest
}
```

**Method needed for RLOG-08 (not yet present):**
```swift
func clearLog() {
    let descriptor = FetchDescriptor<RequestLog>()
    guard let allLogs = try? modelContext.fetch(descriptor) else { return }
    for log in allLogs {
        modelContext.delete(log)
    }
    try? modelContext.save()
}
```

### Existing Theme Tokens for Log (Already Built)

From MockPadTypography:
```swift
static let logTimestamp = Font.system(.caption2, design: .monospaced)
static let logEntry = Font.system(.caption, design: .monospaced).weight(.medium)
```

From MockPadMetrics:
```swift
static let logRowHeight: CGFloat = 44
static let logTimestampWidth: CGFloat = 80
static let logMethodWidth: CGFloat = 56
static let logMaxVisible: Int = 50
```

From MockPadColors:
```swift
static func methodColor(for method: String) -> Color { ... }
static func statusCodeColor(code: Int) -> Color { ... }
```

### Existing ServerStore Log Callback (Already Built)

From `/workspace/MockPad/MockPad/App/ServerStore.swift`:

```swift
await newEngine.setOnRequestLogged { [weak endpointStore] logData in
    Task { @MainActor in
        guard let endpointStore else { return }
        let log = RequestLog(
            timestamp: logData.timestamp,
            method: logData.method,
            path: logData.path,
            queryParameters: logData.queryParameters,
            requestHeaders: logData.requestHeaders,
            requestBody: logData.requestBody,
            responseStatusCode: logData.responseStatusCode,
            responseBody: logData.responseBody,
            responseTimeMs: logData.responseTimeMs
        )
        endpointStore.addLogEntry(log)
    }
}
```

**Needs update:** Pass `responseHeaders` and `matchedEndpointPath` from RequestLogData to RequestLog.

### RequestLogRowView Visual Spec

From MOCKPAD-VISUAL.md Section 4.3:

```swift
struct RequestLogRowView: View {
    let log: RequestLog

    var body: some View {
        HStack(spacing: 8) {
            // Timestamp: "14:30:22"
            Text(log.timestamp, format: .dateTime.hour().minute().second())
                .font(MockPadTypography.logTimestamp)
                .foregroundColor(MockPadColors.textMuted)
                .frame(width: MockPadMetrics.logTimestampWidth, alignment: .leading)

            // Method badge
            Text(log.method)
                .methodBadgeStyle(color: MockPadColors.methodColor(for: log.method))
                .frame(width: MockPadMetrics.logMethodWidth)

            // Path
            Text(log.path)
                .font(MockPadTypography.logEntry)
                .foregroundColor(MockPadColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Status code
            Text("\(log.responseStatusCode)")
                .font(MockPadTypography.statusCode)
                .foregroundColor(MockPadColors.statusCodeColor(code: log.responseStatusCode))

            // Response time
            Text(String(format: "%.0fms", log.responseTimeMs))
                .font(MockPadTypography.badge)
                .foregroundColor(MockPadColors.textMuted)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: MockPadMetrics.logRowHeight)
    }
}
```

### Filter Chips Visual Pattern

From MOCKPAD-UX.md Section 2.7:

```swift
struct FilterChip: View {
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(MockPadTypography.badge)
                .foregroundColor(isActive ? MockPadColors.background : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? color : MockPadColors.panel2)
                .cornerRadius(MockPadMetrics.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                        .stroke(isActive ? color : MockPadColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

### CurlGenerator Unit Test Pattern

```swift
import Testing
import Foundation
@testable import MockPad

struct CurlGeneratorTests {
    @Test func simpleGET() {
        let curl = CurlGenerator.generate(
            method: "GET",
            path: "/api/users",
            headers: ["Accept": "application/json"],
            body: nil,
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("curl"))
        #expect(curl.contains("'http://localhost:8080/api/users'"))
        #expect(curl.contains("-H 'Accept: application/json'"))
        #expect(!curl.contains("-X"))  // GET is default, no -X needed
    }

    @Test func postWithBody() {
        let curl = CurlGenerator.generate(
            method: "POST",
            path: "/api/users",
            headers: ["Content-Type": "application/json"],
            body: "{\"name\":\"Alice\"}",
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("-X POST"))
        #expect(curl.contains("-d"))
        #expect(curl.contains("Alice"))
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NotificationCenter for data updates | SwiftData @Query reactive macro | iOS 17 / WWDC23 | Zero manual observation code. @Query auto-refreshes on model changes. |
| UITableView with manual reload | SwiftUI List with identity-based diffing | iOS 13+ / refined iOS 17+ | Automatic efficient updates. No reloadData(). |
| NSPredicate for filtering | SwiftData #Predicate macro (or client-side filtering) | iOS 17 / WWDC23 | Type-safe predicates. For small datasets, client-side filtering is simpler. |
| UIPasteboard via UIKit bridging | UIPasteboard.general.string (works directly in SwiftUI) | Always available | One line clipboard access. |

**Deprecated/outdated:**
- `NSFetchedResultsController`: SwiftData's @Query replaces this entirely. Do not use Core Data patterns.
- `@FetchRequest` (Core Data): Use `@Query` (SwiftData). Already established in project.

## Existing Data Layer Analysis

### What Is Already Built (Phase 1-2)

| Component | File | Status | Phase 4 Use |
|-----------|------|--------|-------------|
| RequestLog @Model | `Models/RequestLog.swift` | Complete | Read by @Query in views |
| RequestLogData Sendable DTO | `Services/RequestLogData.swift` | Complete | Carries data across actor boundary |
| EndpointStore.addLogEntry() | `App/EndpointStore.swift` | Complete | Inserts logs (triggered by server) |
| EndpointStore.pruneOldEntries() | `App/EndpointStore.swift` | Complete | Auto-prunes to 1,000 (RLOG-10 done) |
| MockServerEngine.onRequestLogged | `Services/MockServerEngine.swift` | Complete | Fires callback on each request |
| ServerStore log callback wiring | `App/ServerStore.swift` | Complete | Bridges engine -> EndpointStore |
| RequestLog unit tests | `MockPadTests/RequestLogTests.swift` | Complete | 7 tests covering model, truncation |
| EndpointStore log tests | `MockPadTests/EndpointStoreTests.swift` | Complete | Tests for addLogEntry, autopruneKeepsLatest1000 |
| Theme tokens for log | `Theme/MockPadTypography.swift`, `MockPadMetrics.swift` | Complete | logTimestamp, logEntry, logRowHeight, logTimestampWidth, logMethodWidth |
| Color helpers | `Theme/MockPadColors.swift` | Complete | methodColor(for:), statusCodeColor(code:) |

### What Needs to Be Added

| Component | Change | Requirement |
|-----------|--------|-------------|
| RequestLog.responseHeadersData | New optional Data? field + computed accessor | RLOG-04 (response headers in detail) |
| RequestLog.matchedEndpointPath | New optional String? field | RLOG-04 (matched endpoint in detail) |
| RequestLogData.responseHeaders | New `[String: String]` field | Carries response headers across actor boundary |
| RequestLogData.matchedEndpointPath | New `String?` field | Carries matched endpoint info across actor boundary |
| MockServerEngine response header capture | Capture actual response headers sent | RLOG-04 |
| MockServerEngine matched path capture | Extract matched path from MatchResult | RLOG-04 |
| ServerStore callback update | Pass new fields from RequestLogData to RequestLog | RLOG-04 |
| EndpointStore.clearLog() | New method to delete all RequestLog entries | RLOG-08 |
| CurlGenerator | New caseless enum service | RLOG-09 |
| RequestLogListView | New view: @Query + filter chips + search + clear | RLOG-01, RLOG-02, RLOG-05, RLOG-06, RLOG-07, RLOG-08 |
| RequestLogRowView | New view: single log row | RLOG-02 |
| RequestDetailView | New view: full request/response inspection | RLOG-03, RLOG-04 |
| LogFilterChipsView | New view: method + status filter chips | RLOG-05, RLOG-06 |
| CurlGeneratorTests | Unit tests for cURL generation | RLOG-09 |

### Navigation Integration

Phase 4 needs to integrate the RequestLogListView into the app's navigation. Currently, ContentView wraps EndpointListView in a NavigationStack. For Phase 4 (pre-Phase 10 navigation polish), the request log can be accessed via a tab or a toolbar button. The UX spec says iPhone uses TabView with Endpoints + Log tabs, but the full TabView layout is Phase 10.

**Recommended approach for Phase 4:** Add a toolbar button on EndpointListView that navigates to RequestLogListView via NavigationLink. This is minimal, functional, and does not conflict with Phase 10's TabView restructuring. Alternatively, add a simple tab structure now if it does not complicate Phase 10.

## Open Questions

1. **Should the request log navigation be a toolbar button (push) or a simple tab structure?**
   - What we know: Phase 10 builds the full iPhone TabView + iPad NavigationSplitView. Phase 4 needs to make the log accessible now.
   - What's unclear: Whether building a temporary navigation mechanism conflicts with Phase 10's restructuring.
   - Recommendation: Use a toolbar button on the EndpointListView that pushes to RequestLogListView. This is minimal and can be easily replaced in Phase 10 without affecting the log views themselves. The log views (RequestLogListView, RequestDetailView) will be reused as-is in Phase 10.

2. **Should filter state persist across sessions?**
   - What we know: UX spec Section 6.1 says "Log filter state: Yes (session)" -- meaning persist within a session but not across app launches.
   - What's unclear: Whether @State is sufficient or if we need something more.
   - Recommendation: Use @State on RequestLogListView. Filter state resets when the view is recreated (which happens on tab switch or navigation pop). This matches "session" persistence naturally. No UserDefaults needed.

3. **How to handle the response headers data for the engine-built headers (CORS, Content-Length, etc.)?**
   - What we know: HTTPResponseBuilder adds headers like Server, Date, Content-Length, Connection, and CORS headers. The current RequestLogData does not carry response headers.
   - What's unclear: Whether to capture the full set of response headers (including auto-generated ones) or just the user-configured headers from the matched endpoint.
   - Recommendation: Capture the full response headers as sent to the client. Build a `[String: String]` dictionary from the HTTPResponseBuilder output by parsing the actual response, OR more practically, construct the response headers dictionary in MockServerEngine.handleReceivedData before building the response and pass it to RequestLogData. The latter avoids re-parsing.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `MockPad/MockPad/Models/RequestLog.swift` -- all model fields verified
- Existing codebase: `MockPad/MockPad/App/EndpointStore.swift` -- addLogEntry, pruneOldEntries verified
- Existing codebase: `MockPad/MockPad/Services/MockServerEngine.swift` -- onRequestLogged callback verified
- Existing codebase: `MockPad/MockPad/Services/RequestLogData.swift` -- Sendable DTO fields verified
- Existing codebase: `MockPad/MockPad/App/ServerStore.swift` -- log callback wiring verified
- Existing codebase: `MockPad/MockPad/Theme/` -- all theme tokens for log UI verified
- `.planning/mockpad/MOCKPAD-UX.md` -- Section 2.7 (Request Log / Inspector Flow), Section 1.3-1.4 (iPhone navigation)
- `.planning/mockpad/MOCKPAD-VISUAL.md` -- Section 4.3 (RequestLogRow), Section 4.9 (RequestLogPanel)
- `.planning/REQUIREMENTS.md` -- RLOG-01 through RLOG-10 verified
- `.planning/ROADMAP.md` -- Phase 4 description, success criteria, dependencies verified
- Phase 1 Research (01-RESEARCH.md) -- SwiftData patterns, @Observable store patterns
- Phase 2 Research (02-RESEARCH.md) -- Actor patterns, Sendable DTOs, callback wiring
- Phase 3 Research (03-RESEARCH.md) -- SwiftUI view patterns, theme tokens, engine sync

### Secondary (MEDIUM confidence)
- SwiftData @Query documentation -- reactive model observation verified in existing EndpointStore tests
- UIPasteboard documentation -- clipboard access API confirmed

### Tertiary (LOW confidence)
- None -- all findings verified against existing codebase and Apple documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All SwiftUI + SwiftData native, zero external dependencies, patterns verified in existing codebase (Phase 1-3 established all conventions)
- Architecture: HIGH -- Builds on existing RequestLog model, EndpointStore methods, ServerStore callback wiring, and theme tokens. All integration points verified in source code.
- Pitfalls: HIGH -- Model field gaps identified by comparing RequestLog fields against RLOG-04 requirements. @Query reactivity confirmed by SwiftData's standard behavior (already used implicitly in existing store patterns). Scroll position and cURL escaping documented from known SwiftUI/shell behavior.
- Code examples: HIGH -- Based on existing codebase patterns (EndpointRowView for row layout, EndpointListView for list patterns, existing theme tokens)

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (stable frameworks, 60-day window)
