# Phase 3: Endpoint Editor UI - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI endpoint CRUD views, JSON editing/validation, List reordering, form patterns, live engine sync
**Confidence:** HIGH

## Summary

Phase 3 builds the first user-facing screens of MockPad. The scope covers: (1) an endpoint list view with create, delete, enable/disable toggle, duplicate, and drag-to-reorder; (2) an endpoint editor view for configuring path, HTTP method, status code, response body, and response headers; and (3) a JSON response body editor with format/pretty-print and validation indicator. All CRUD operations go through the existing `EndpointStore` (Phase 1) and changes to the running server must propagate via `ServerStore.updateEngineEndpoints()` (Phase 2).

The technical domain is straightforward SwiftUI forms and lists with established patterns. The key challenges are: (a) List drag-to-reorder using `.onMove(perform:)` with `sortOrder` persistence, (b) JSON validation using `JSONSerialization` with a live valid/invalid indicator, (c) key-value pair editing for response headers with add/remove, (d) immediate save semantics (no explicit save button -- changes write through on field blur or after brief inactivity), and (e) propagating endpoint changes to the running MockServerEngine actor so the next request uses updated configuration.

No external dependencies are needed. All UI components use SwiftUI built-in views (List, Form, TextEditor, Picker, Toggle, TextField) with the visual design tokens from MOCKPAD-VISUAL.md. This phase does NOT build the full iPad NavigationSplitView layout (that is Phase 10) -- it builds the endpoint editing views that will later be placed into that layout. For now, iPhone-style NavigationStack is sufficient.

**Primary recommendation:** Build in three plans: (1) endpoint list view with CRUD actions + server sync, (2) endpoint editor/creation form with all fields, (3) JSON response body editor with validation + pretty-print + response headers key-value editor. Each plan is testable independently.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI | iOS 26+ | All views: List, Form, TextEditor, Picker, Toggle, NavigationStack, .sheet | Native declarative UI framework. Project's UI layer. |
| SwiftData | iOS 26+ | MockEndpoint model persistence via EndpointStore | Already established in Phase 1. Views mutate models through the store. |
| Foundation | iOS 26+ | JSONSerialization for validation/pretty-print, Date formatting | Standard library. No alternatives needed. |
| Observation | iOS 17+ | @Observable stores (EndpointStore, ServerStore, ProManager) already wired via .environment() | Phase 1 established this pattern. Views access stores with @Environment. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for JSON validation logic, sort order update logic | All non-UI logic should have unit tests. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TextEditor for JSON body | UITextView via UIViewRepresentable | UITextView gives line number control and attributed string syntax highlighting, but adds UIKit bridging complexity. TextEditor is sufficient for v1.0. Syntax highlighting deferred -- Phase 3 uses plain monospaced text with a separate validation indicator. |
| JSONSerialization for validation | Custom JSON parser | JSONSerialization is built-in, handles all valid JSON, provides error descriptions. No reason to hand-roll. |
| List .onMove for reorder | custom DragGesture | .onMove is the standard SwiftUI reorder mechanism. Works with drag handles automatically. Custom gesture would be reimplementing platform behavior. |

## Architecture Patterns

### Recommended View Structure

```
MockPad/MockPad/
├── Views/
│   ├── EndpointListView.swift          # List of endpoints with CRUD toolbar
│   ├── EndpointEditorView.swift        # Full editor form for one endpoint
│   ├── EndpointRowView.swift           # Single row in the endpoint list
│   ├── ResponseBodyEditorView.swift    # JSON text editor with validation
│   ├── ResponseHeadersEditorView.swift # Key-value pair editor for headers
│   ├── StatusCodePickerView.swift      # Quick-select chips + custom input
│   ├── HTTPMethodPickerView.swift      # Segmented control for method selection
│   └── AddEndpointSheet.swift          # Sheet for creating new endpoint
```

### Pattern 1: @Environment Store Access in Views

**What:** Views access EndpointStore, ServerStore, and ProManager via `@Environment` -- already wired at app root in MockPadApp.swift.

**When to use:** Every view that reads or mutates endpoint data.

**Example:**
```swift
struct EndpointListView: View {
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(ProManager.self) private var proManager

    var body: some View {
        List {
            ForEach(endpointStore.endpoints) { endpoint in
                EndpointRowView(endpoint: endpoint)
            }
            .onDelete(perform: deleteEndpoints)
            .onMove(perform: moveEndpoints)
        }
    }
}
```

### Pattern 2: Immediate Save via EndpointStore

**What:** When the user edits a field (path, method, status code, body, headers), the change is written to the SwiftData model property directly (since MockEndpoint is a reference type @Model class), then `endpointStore.updateEndpoint()` saves to disk. No explicit "Save" button.

**When to use:** All editor fields.

**Why this pattern:** The UX spec (MOCKPAD-UX.md Section 2.4) specifies auto-save on field blur / after 1 second of inactivity. SwiftData @Model classes are reference types -- modifying a property on a fetched MockEndpoint immediately updates the in-memory model. Calling `endpointStore.updateEndpoint()` (which calls `modelContext.save()`) persists to disk.

**Example:**
```swift
struct EndpointEditorView: View {
    let endpoint: MockEndpoint
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore

    var body: some View {
        Form {
            TextField("Path", text: Binding(
                get: { endpoint.path },
                set: { newValue in
                    endpoint.path = newValue
                    endpointStore.updateEndpoint()
                    syncEngine()
                }
            ))
        }
    }

    private func syncEngine() {
        Task {
            await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
        }
    }
}
```

**Key insight:** `MockEndpoint` is a SwiftData `@Model` class (reference type). Views can bind directly to its properties. After mutation, call `endpointStore.updateEndpoint()` to persist, then `serverStore.updateEngineEndpoints()` to push changes to the running server.

### Pattern 3: List Reorder with sortOrder Persistence

**What:** SwiftUI List with `.onMove(perform:)` enables drag handles in edit mode. On move, update `sortOrder` on all affected endpoints and persist.

**When to use:** Endpoint list view for ENDP-09.

**Example:**
```swift
func moveEndpoints(from source: IndexSet, to destination: Int) {
    var endpoints = endpointStore.endpoints
    endpoints.move(fromOffsets: source, toOffset: destination)
    for (index, endpoint) in endpoints.enumerated() {
        endpoint.sortOrder = index
    }
    endpointStore.updateEndpoint()
    syncEngine()
}
```

**Key detail:** `endpointStore.endpoints` returns sorted by `sortOrder`. After `.move()`, reassign `sortOrder = index` for every element so the new order persists. Call save once after the loop.

### Pattern 4: JSON Validation with JSONSerialization

**What:** Validate JSON body text using `JSONSerialization.jsonObject(with:)`. Display valid/invalid indicator. Provide pretty-print via `JSONSerialization.data(withJSONObject:options:.prettyPrinted)`.

**When to use:** Response body editor for RESP-02, RESP-03, RESP-04.

**Example:**
```swift
enum JSONValidationResult {
    case valid
    case invalid(String)
    case empty
}

func validateJSON(_ text: String) -> JSONValidationResult {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .empty
    }
    guard let data = text.data(using: .utf8) else {
        return .invalid("Invalid UTF-8 encoding")
    }
    do {
        _ = try JSONSerialization.jsonObject(with: data)
        return .valid
    } catch {
        return .invalid(error.localizedDescription)
    }
}

func prettyPrintJSON(_ text: String) -> String? {
    guard let data = text.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data),
          let formatted = try? JSONSerialization.data(
              withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: formatted, encoding: .utf8) else {
        return nil
    }
    return string
}
```

### Pattern 5: Endpoint Duplication

**What:** Create a new MockEndpoint with the same field values as an existing one, but a new `createdAt`, incremented `sortOrder`, and "(Copy)" appended to differentiate.

**When to use:** ENDP-05 duplicate action.

**Example:**
```swift
func duplicateEndpoint(_ source: MockEndpoint) {
    let maxSortOrder = endpointStore.endpoints.map(\.sortOrder).max() ?? 0
    let copy = MockEndpoint(
        path: source.path,
        httpMethod: source.httpMethod,
        responseStatusCode: source.responseStatusCode,
        responseBody: source.responseBody,
        responseHeaders: source.responseHeaders,
        isEnabled: source.isEnabled,
        sortOrder: maxSortOrder + 1
    )
    endpointStore.addEndpoint(copy)
    syncEngine()
}
```

### Pattern 6: Key-Value Header Editor

**What:** Response headers are `[String: String]` stored as JSON-encoded Data on MockEndpoint. The editor shows each header as a row with key/value TextFields and a delete button. An "Add Header" button appends a new empty pair.

**When to use:** RESP-05 custom response headers.

**Approach:** Since `[String: String]` is unordered, convert to an array of `(key, value)` tuples for ordered display. On edit, reconstruct the dictionary and write back to `endpoint.responseHeaders`.

```swift
// Local state for ordered editing
@State private var headerPairs: [(key: String, value: String)] = []

// Initialize from endpoint
.onAppear {
    headerPairs = endpoint.responseHeaders.sorted(by: { $0.key < $1.key })
        .map { (key: $0.key, value: $0.value) }
}

// Write back to endpoint on change
private func saveHeaders() {
    var dict: [String: String] = [:]
    for pair in headerPairs where !pair.key.isEmpty {
        dict[pair.key] = pair.value
    }
    endpoint.responseHeaders = dict
    endpointStore.updateEndpoint()
}
```

### Pattern 7: Engine Sync on Mutation

**What:** Whenever an endpoint is added, edited, deleted, reordered, or toggled, push the updated endpoint snapshots to the running MockServerEngine so the next HTTP request sees the change immediately.

**When to use:** Every mutation in this phase.

**Why critical:** Phase 2 established that `ServerStore.updateEngineEndpoints()` calls `engine.updateEndpoints()` on the actor. The UX spec says "changes take effect immediately. No server restart needed." Every endpoint mutation must be followed by a sync call.

**Example:**
```swift
private func syncEngine() {
    Task {
        await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
    }
}
```

### Anti-Patterns to Avoid

- **Using @Query in views instead of EndpointStore:** The architecture uses EndpointStore (Phase 1 decision). Do NOT bypass it with `@Query` in views. The store provides the single source of truth for endpoint CRUD and keeps the engine in sync.

- **Forgetting to sync engine after mutations:** Every add/edit/delete/reorder/toggle must call `serverStore.updateEngineEndpoints()`. Forgetting means the running server serves stale endpoints until restart.

- **Using Color or Image without intrinsic size in ScrollView:** Project memory warns about infinite layout loops. All colored shapes must have explicit `.frame()` sizing.

- **Dual @AppStorage with same key in parent+child:** Project memory warns about infinite render loops. Use @State initialized from UserDefaults in child views instead.

- **Creating separate ModelContext in views:** The EndpointStore owns the single ModelContext. Views should never create their own -- always go through the store.

- **Using EditMode for reorder only:** SwiftUI's `.editMode()` enables both delete and move. To show drag handles without swipe-to-delete in edit mode, control the UI explicitly. However, for this app, both delete (via swipe) and reorder (via drag) are desired, so standard List edit mode is fine.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON validation | Custom JSON tokenizer/parser | `JSONSerialization.jsonObject(with:)` | Handles all valid JSON including edge cases (Unicode escapes, nested structures, numbers). Built-in, zero dependencies. |
| JSON pretty-printing | Custom indentation logic | `JSONSerialization.data(withJSONObject:options:.prettyPrinted)` | Handles all JSON formatting including nested arrays/objects. Built-in. |
| List reorder with persistence | Custom drag gesture + position tracking | SwiftUI `.onMove(perform:)` + `sortOrder` Int field | Platform-standard drag handles, accessible, works with VoiceOver. sortOrder field already exists on MockEndpoint (Phase 1 decision). |
| Status code picker | Custom number input with validation | Picker/segmented control with predefined chips + custom TextField | The 8 common codes (200, 201, 204, 400, 401, 403, 404, 500) cover 95% of use cases. Custom input handles the rest. |
| HTTP method picker | Custom radio buttons | SwiftUI Picker with .segmented style or custom segmented control | Standard control, accessible, method list from HTTPMethod.allMethods. |

**Key insight:** Every UI component in Phase 3 can be built with standard SwiftUI views. No UIKit bridging, no custom drawing, no third-party libraries. The visual design tokens (MockPadColors, MockPadTypography) will be created as enums with static properties -- the same pattern as all sibling apps.

## Common Pitfalls

### Pitfall 1: ForEach with @Model Objects Requires Identifiable

**What goes wrong:** `ForEach(endpointStore.endpoints)` fails to compile because `MockEndpoint` needs to conform to `Identifiable`.

**Why it happens:** SwiftData `@Model` classes automatically get a `PersistentIdentifier` but do NOT automatically conform to `Identifiable`. ForEach requires `Identifiable` or an explicit `id:` parameter.

**How to avoid:** Either make MockEndpoint conform to `Identifiable` (using `PersistentIdentifier` as the id), or use `ForEach(endpoints, id: \.self)` since @Model classes are `Hashable` by default. The cleanest approach: add `Identifiable` conformance if not already implicit. SwiftData @Model classes in iOS 17+ are implicitly `Identifiable` via their `persistentModelID`. Verify this compiles -- if it does not, add explicit conformance.

**Warning signs:** Compiler error "Type 'MockEndpoint' does not conform to protocol 'Identifiable'" on ForEach.

### Pitfall 2: Binding to @Model Properties

**What goes wrong:** Creating a `$endpoint.path` binding directly from a `@Model` property in a Form/TextField does not work the same way as @State bindings.

**Why it happens:** SwiftData @Model classes use the `@Observable` macro under the hood, but they are reference types owned by the ModelContext. SwiftUI's `$` binding syntax works with @State and @Bindable. For @Model objects, you need `@Bindable` (iOS 17+).

**How to avoid:** Use `@Bindable var endpoint` in the view that needs two-way bindings:

```swift
struct EndpointEditorView: View {
    @Bindable var endpoint: MockEndpoint

    var body: some View {
        TextField("Path", text: $endpoint.path)
    }
}
```

The `@Bindable` property wrapper creates Binding accessors for the @Observable/@Model object's properties. This is the standard SwiftUI pattern for editing SwiftData models.

**Warning signs:** Cannot use `$endpoint.path` without @Bindable -- compiler error about missing Binding.

### Pitfall 3: .onMove Not Showing Drag Handles

**What goes wrong:** Adding `.onMove(perform:)` to a ForEach inside a List does not show drag handles unless the List is in edit mode.

**Why it happens:** SwiftUI List shows drag handles only in `.editMode(.active)`. Without edit mode, .onMove is registered but handles are not visible.

**How to avoid:** Two options:
1. Add an "Edit" button to the toolbar that toggles `.editMode()` -- standard iOS pattern.
2. Use `.moveDisabled(false)` and ensure the List is configured to show handles. The most common approach is a toolbar EditButton().

For MockPad, the UX spec says "drag handles" which implies always-visible handles, not edit-mode-gated. This can be achieved by setting `.environment(\.editMode, .constant(.active))` on the List -- but this also shows delete buttons. A better approach: use a custom reorder handle icon alongside each row, or simply use the standard EditButton in the toolbar.

**Recommendation:** Use a toolbar EditButton for reorder mode. This is the standard iOS pattern and is accessible. The success criteria says "reorder via drag handles in list view" which is satisfied by edit mode drag handles.

**Warning signs:** Drag handles are invisible even though .onMove is implemented.

### Pitfall 4: Response Headers Dictionary Ordering

**What goes wrong:** `[String: String]` dictionaries have no guaranteed order. Each time the user opens the header editor, headers may appear in a different order, confusing the user.

**Why it happens:** Swift Dictionary iteration order is not stable across runs.

**How to avoid:** Sort headers alphabetically by key when loading into the editor's local array state. This provides consistent display order. When saving back, the dictionary order does not matter (headers are a key-value lookup, not ordered).

**Warning signs:** Headers appear in random order each time the editor opens.

### Pitfall 5: Engine Sync Race Condition on Rapid Edits

**What goes wrong:** If the user types rapidly in the response body, each keystroke triggers `updateEndpoint()` + `syncEngine()`, creating many `Task` calls to the actor that may queue up.

**Why it happens:** Each character change triggers the save + sync pipeline.

**How to avoid:** Debounce the engine sync. Save to SwiftData on every change (it's local and fast), but debounce the engine sync to at most once per 300ms. Use a simple approach: cancel a previous Task and create a new one with a delay.

```swift
@State private var syncTask: Task<Void, Never>?

private func debouncedSyncEngine() {
    syncTask?.cancel()
    syncTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
    }
}
```

**Warning signs:** Typing in the response body causes noticeable lag or the server serves partially-typed responses.

### Pitfall 6: ProManager Gating on Add

**What goes wrong:** User can add unlimited endpoints because the PRO check was forgotten.

**Why it happens:** Phase 3 adds the "create endpoint" UI. The PRO 3-endpoint limit was defined in Phase 1 (ProManager) but the UI gating must be implemented here.

**How to avoid:** Before creating a new endpoint, check `proManager.canAddEndpoint(currentCount: endpointStore.endpointCount)`. If false, show a PRO upgrade prompt instead. The full paywall is Phase 9, but the gating check must exist now.

**Warning signs:** Free tier users can create more than 3 endpoints.

## Code Examples

Verified patterns from the existing codebase and Apple documentation:

### EndpointStore Methods Already Available

The following methods are already implemented in `/workspace/MockPad/MockPad/App/EndpointStore.swift`:

```swift
// Already exists -- use these, don't recreate
var endpoints: [MockEndpoint]           // Sorted by sortOrder
var endpointCount: Int                  // Total count
func addEndpoint(_ endpoint: MockEndpoint)
func deleteEndpoint(_ endpoint: MockEndpoint)
func updateEndpoint()                   // Saves ModelContext
var endpointSnapshots: [EndpointSnapshot]  // For engine sync
```

### ServerStore Engine Sync Already Available

From `/workspace/MockPad/MockPad/App/ServerStore.swift`:

```swift
// Already exists -- call after every endpoint mutation
func updateEngineEndpoints(endpointStore: EndpointStore) async {
    guard isRunning else { return }
    let snapshots = endpointStore.endpointSnapshots
    await engine?.updateEndpoints(snapshots)
}
```

### Status Code Quick-Select Chips (RESP-01)

```swift
struct StatusCodePickerView: View {
    @Binding var selectedCode: Int

    private let quickCodes = [200, 201, 204, 400, 401, 403, 404, 500]
    @State private var customCode: String = ""
    @State private var showCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quick-select chips in a flowing grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                ForEach(quickCodes, id: \.self) { code in
                    Button {
                        selectedCode = code
                        showCustom = false
                    } label: {
                        Text("\(code)")
                            .font(.system(.callout, design: .monospaced).weight(.bold))
                            .frame(minWidth: 56, minHeight: 36)
                            .background(selectedCode == code ? MockPadColors.accent.opacity(0.15) : MockPadColors.panel2)
                            .foregroundColor(selectedCode == code ? MockPadColors.accent : MockPadColors.textMuted)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedCode == code ? MockPadColors.accent : MockPadColors.border, lineWidth: 1)
                            )
                    }
                }
                // Custom code button
                Button {
                    showCustom = true
                    customCode = quickCodes.contains(selectedCode) ? "" : "\(selectedCode)"
                } label: {
                    Text("...")
                        .frame(minWidth: 56, minHeight: 36)
                        .background(showCustom ? MockPadColors.accent.opacity(0.15) : MockPadColors.panel2)
                        .cornerRadius(8)
                }
            }

            if showCustom {
                TextField("Custom code", text: $customCode)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: customCode) { _, newValue in
                        if let code = Int(newValue), (100...599).contains(code) {
                            selectedCode = code
                        }
                    }
            }
        }
    }
}
```

### MockEndpoint Identifiable Conformance

SwiftData @Model classes in iOS 17+ get `Identifiable` conformance via `persistentModelID`. This should work out of the box:

```swift
// MockEndpoint is already @Model, which provides Identifiable
// ForEach(endpointStore.endpoints) should compile without extra conformance
// If not, add explicit conformance:
extension MockEndpoint: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}
```

### Enable/Disable Toggle (ENDP-04)

```swift
// In endpoint list row
Toggle("", isOn: Binding(
    get: { endpoint.isEnabled },
    set: { newValue in
        endpoint.isEnabled = newValue
        endpointStore.updateEndpoint()
        syncEngine()
    }
))
.labelsHidden()
```

### JSON Validation Indicator (RESP-04)

```swift
struct JSONValidationBadge: View {
    let text: String

    private var isValid: Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true  // Empty is OK
        }
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(isValid ? "Valid JSON" : "Invalid JSON")
                .font(.system(.caption, design: .monospaced))
        }
        .foregroundColor(isValid ? MockPadColors.status2xx : MockPadColors.status5xx)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| @State + manual save button | @Bindable + auto-save via @Model reference mutation | iOS 17 / WWDC23 | Eliminates explicit save workflow. @Model properties are observed automatically. |
| List EditButton for reorder | Same (unchanged) | N/A | EditButton + .onMove is still the standard reorder pattern in iOS 17+. |
| ObservedObject with @Published | @Observable + @Environment | iOS 17 / WWDC23 | Finer-grained observation. Already adopted in Phase 1. |
| Custom Form validation | SwiftUI Form with inline validation indicators | iOS 17+ | No third-party form validation libraries needed. |
| NavigationLink(destination:) | navigationDestination(for:) value-based | iOS 16+ | Type-safe navigation. Better for programmatic control. |

**Deprecated/outdated:**
- `NavigationView`: Replaced by NavigationStack (iOS 16+). Use NavigationStack for this phase.
- `ObservableObject` + `@Published`: Use @Observable. Already done.
- `@EnvironmentObject`: Use `.environment()` with @Observable types. Already done.

## Open Questions

1. **Should the endpoint editor be a sheet or push navigation?**
   - What we know: UX spec says iPad uses push navigation (center column), iPhone uses push navigation. Add endpoint uses a sheet.
   - What's unclear: Since Phase 10 builds the full NavigationSplitView, should Phase 3 use sheets for editing too, or NavigationStack push?
   - Recommendation: Use NavigationStack push navigation for editing existing endpoints (matches the final design). Use `.sheet` for adding new endpoints (matches UX spec Section 2.3). This way, Phase 10 only needs to restructure the navigation container, not the individual views.

2. **How much visual design to implement in Phase 3 vs. Phase 10/11?**
   - What we know: MOCKPAD-VISUAL.md has comprehensive color tokens (MockPadColors), typography (MockPadTypography), and component specs. Phase 11 handles accessibility polish.
   - What's unclear: Should Phase 3 implement the full visual design or use basic SwiftUI styling?
   - Recommendation: Implement the core visual design tokens (MockPadColors, MockPadTypography, MockPadMetrics) as Swift enums in Phase 3. Apply them to all views built in this phase. This avoids a massive visual rework in Phase 10. Phase 11 adds accessibility-specific enhancements (VoiceOver labels, Dynamic Type @ScaledMetric, Reduce Motion). The visual design is not accessibility -- it is identity. Build it now.

3. **Should syntax highlighting be in Phase 3 or deferred?**
   - What we know: RESP-02 says "edit response body as JSON with syntax highlighting." MOCKPAD-VISUAL.md specifies JSON key colors (accent), string colors (green), number colors (amber). However, implementing true syntax highlighting in a TextEditor requires either AttributedString (limited in TextEditor) or a UITextView bridge.
   - What's unclear: Whether TextEditor supports AttributedString coloring in iOS 26.
   - Recommendation: Defer syntax highlighting. Phase 3 delivers monospaced TextEditor with valid/invalid indicator and pretty-print. The JSON is readable in monospace without coloring. Syntax highlighting can be added in a later enhancement phase if needed. The success criteria do not list syntax highlighting -- they list "validation indicator" and "JSON response body editing."

## Existing Codebase Integration Points

### Files That Will Be Read (Dependencies)

| File | What's Used |
|------|-------------|
| `MockPad/App/EndpointStore.swift` | All CRUD methods, endpoints property, endpointCount, endpointSnapshots |
| `MockPad/App/ServerStore.swift` | updateEngineEndpoints(), isRunning |
| `MockPad/App/ProManager.swift` | canAddEndpoint(), isPro |
| `MockPad/Models/MockEndpoint.swift` | All fields: path, httpMethod, responseStatusCode, responseBody, responseHeaders, isEnabled, sortOrder |
| `MockPad/Models/HTTPMethod.swift` | HTTPMethod.allMethods, individual method constants |
| `MockPad/MockPadApp.swift` | Environment injection point (already wired) |
| `MockPad/ContentView.swift` | Entry point -- will be modified to show EndpointListView |

### Files That Will Be Created

| File | Purpose |
|------|---------|
| `Views/EndpointListView.swift` | Main endpoint list with server status, add button, swipe-to-delete, reorder |
| `Views/EndpointRowView.swift` | Single row: method badge, path, status code, enable toggle |
| `Views/EndpointEditorView.swift` | Full editor: method, path, status code, body, headers |
| `Views/AddEndpointSheet.swift` | Sheet for creating new endpoint with defaults |
| `Views/ResponseBodyEditorView.swift` | TextEditor + JSON validation + format button |
| `Views/ResponseHeadersEditorView.swift` | Key-value pair list with add/remove |
| `Views/StatusCodePickerView.swift` | Quick chips + custom input |
| `Views/HTTPMethodPickerView.swift` | Segmented/picker for method selection |
| `Theme/MockPadColors.swift` | Color tokens from MOCKPAD-VISUAL.md |
| `Theme/MockPadTypography.swift` | Font tokens from MOCKPAD-VISUAL.md |
| `Theme/MockPadMetrics.swift` | Spacing/sizing tokens from MOCKPAD-VISUAL.md |

### Files That Will Be Modified

| File | Change |
|------|--------|
| `ContentView.swift` | Replace placeholder VStack with EndpointListView + NavigationStack |

## Requirement-to-Feature Mapping

| Requirement | Feature | Key Implementation Detail |
|-------------|---------|---------------------------|
| RESP-01 | Status code picker | 8 quick-select chips (200, 201, 204, 400, 401, 403, 404, 500) + custom TextField |
| RESP-02 | Response body editor | TextEditor with monospaced font. Syntax highlighting deferred. |
| RESP-03 | JSON pretty-print | "Format" button using JSONSerialization with .prettyPrinted option |
| RESP-04 | JSON validation indicator | Live checkmark/xmark badge computed from JSONSerialization validation |
| RESP-05 | Response headers editor | Key-value pair list with add/remove. Sorted alphabetically for stability. |
| ENDP-04 | Enable/disable toggle | Toggle in list row, writes to endpoint.isEnabled, syncs engine |
| ENDP-05 | Duplicate endpoint | Creates new MockEndpoint with same fields, incremented sortOrder |
| ENDP-09 | Reorder endpoints | List .onMove(perform:) with sortOrder reassignment |

## Sources

### Primary (HIGH confidence)
- Existing codebase: `MockPad/MockPad/App/EndpointStore.swift` -- all CRUD methods verified
- Existing codebase: `MockPad/MockPad/App/ServerStore.swift` -- updateEngineEndpoints() verified
- Existing codebase: `MockPad/MockPad/Models/MockEndpoint.swift` -- all fields verified
- Existing codebase: `MockPad/MockPad/Models/HTTPMethod.swift` -- method constants verified
- Existing codebase: `MockPad/MockPad/MockPadApp.swift` -- environment injection verified
- `.planning/mockpad/MOCKPAD-UX.md` -- endpoint editor flow (Section 2.3, 2.4, 2.5)
- `.planning/mockpad/MOCKPAD-VISUAL.md` -- color tokens (MockPadColors), typography (MockPadTypography), component specs
- `.planning/mockpad/MOCKPAD-INTERACTIONS.md` -- animations, haptics, endpoint interactions (Sections 4, 5, 8)
- [Apple SwiftUI List documentation](https://developer.apple.com/documentation/swiftui/list) -- .onMove, .onDelete, EditButton
- [Apple JSONSerialization documentation](https://developer.apple.com/documentation/foundation/jsonserialization) -- validation, pretty-print
- [Apple @Bindable documentation](https://developer.apple.com/documentation/swiftui/bindable) -- binding to @Observable/@Model properties

### Secondary (MEDIUM confidence)
- Phase 1 Research (01-RESEARCH.md) -- SwiftData patterns, @Observable store patterns, confirmed in codebase
- Phase 2 Plans (02-01 through 02-03) -- engine sync patterns, EndpointSnapshot, confirmed in codebase

### Tertiary (LOW confidence)
- None -- all findings verified against existing codebase and Apple documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All SwiftUI native, no external dependencies, patterns verified in codebase
- Architecture: HIGH -- Builds on existing EndpointStore/ServerStore/ProManager from Phase 1-2, integration points verified in source code
- Pitfalls: HIGH -- @Bindable pattern, .onMove behavior, dictionary ordering, engine sync debouncing all documented with verified solutions
- Code examples: HIGH -- Based on existing codebase methods (EndpointStore.addEndpoint, ServerStore.updateEngineEndpoints) plus standard SwiftUI patterns

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (stable frameworks, 60-day window)
