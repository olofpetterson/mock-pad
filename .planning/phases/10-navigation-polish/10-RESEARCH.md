# Phase 10: Navigation Polish - Research

**Researched:** 2026-02-17
**Domain:** SwiftUI adaptive navigation (NavigationSplitView, TabView, empty states, settings)
**Confidence:** HIGH

## Summary

Phase 10 transforms MockPad's current single-NavigationStack iPhone-only layout into an adaptive navigation system: NavigationSplitView with 3 columns on iPad, TabView with 3 tabs on iPhone. This also introduces a Settings screen, an empty-state quick-start flow, and a persistent server status bar on iPhone.

The current app has a simple NavigationStack in ContentView wrapping EndpointListView, with a toolbar button linking to RequestLogListView. All views (EndpointListView, EndpointEditorView, RequestLogListView, RequestDetailView) already exist and are fully functional. The challenge is reorganizing these into the correct adaptive navigation container without breaking existing view logic, environment injection, or sheet presentations.

**Primary recommendation:** Use `@Environment(\.horizontalSizeClass)` to conditionally render NavigationSplitView (regular) vs TabView (compact) at the ContentView level. Existing views need minimal changes -- primarily removing hardcoded NavigationStack wrappers where they conflict and extracting the server status bar into a reusable component.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI NavigationSplitView | iOS 16+ (available, app targets iOS 26.2) | 3-column iPad layout | Apple's official multi-column navigation for iPadOS |
| SwiftUI TabView | iOS 13+ | iPhone tab-based navigation | Standard iOS pattern for parallel content areas |
| @Environment(\.horizontalSizeClass) | iOS 14+ | Detect compact vs regular width | Standard SwiftUI idiom for adaptive layouts |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UserDefaults | Foundation | ServerConfiguration persistence (port, CORS, autoStart) | Already in use -- Settings view reads/writes these |
| @Query (SwiftData) | iOS 17+ | Endpoint count for empty state detection | Already in use throughout views |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| horizontalSizeClass conditional | Two separate Window scenes | Overkill, harder state sharing |
| TabView for iPhone | Single NavigationStack with toolbar tabs | Non-standard, harder to add badge later |
| NavigationSplitView 3-column | UISplitViewController wrapped | Unnecessary -- SwiftUI native works at iOS 26.2 |

## Architecture Patterns

### Recommended Project Structure
```
MockPad/MockPad/
├── MockPadApp.swift           # (existing) Entry point
├── ContentView.swift          # MAJOR REFACTOR: adaptive nav container
├── Views/
│   ├── ServerStatusBarView.swift    # NEW: reusable server status bar
│   ├── SettingsView.swift           # NEW: settings screen
│   ├── EmptyStateView.swift         # NEW: empty state with "Create Sample API"
│   ├── SidebarView.swift            # NEW: iPad sidebar (server + endpoints)
│   ├── EndpointListView.swift       # MINOR EDITS: remove NavigationStack conflicts
│   ├── EndpointEditorView.swift     # UNCHANGED
│   ├── RequestLogListView.swift     # MINOR EDITS: remove NavigationStack conflicts
│   ├── RequestDetailView.swift      # UNCHANGED
│   └── ... (existing views unchanged)
├── Services/
│   ├── SampleEndpointGenerator.swift  # NEW: creates 4 CRUD sample endpoints
│   └── ... (existing services unchanged)
```

### Pattern 1: Adaptive Navigation with horizontalSizeClass
**What:** Conditionally render NavigationSplitView on iPad vs TabView on iPhone based on horizontal size class.
**When to use:** App root view when supporting both iPad and iPhone layouts.
**Current ContentView code:**
```swift
// Current: Simple NavigationStack
struct ContentView: View {
    var body: some View {
        NavigationStack {
            EndpointListView()
                .toolbar { ... }
        }
    }
}
```
**Target pattern:**
```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedEndpoint: $selectedEndpoint)
        } content: {
            // Editor or Log depending on selection
        } detail: {
            // Request inspector
        }
    }

    private var iPhoneLayout: some View {
        TabView {
            // Tab 1: Endpoints
            // Tab 2: Log
            // Tab 3: Settings
        }
    }
}
```
**Confidence:** HIGH -- This is the standard Apple pattern for adaptive layouts.

### Pattern 2: NavigationSplitView Column Layout (iPad)
**What:** 3-column split view with sidebar (server + endpoints), content (editor/log), detail (request inspector).
**Architecture decisions:**
- Sidebar contains ServerStatusBarView + EndpointListView (without its own NavigationStack)
- Content column shows EndpointEditorView when an endpoint is selected, or a placeholder
- Detail column shows RequestDetailView when a log entry is selected, or RequestLogListView as default
- `@State private var selectedEndpoint: MockEndpoint?` drives sidebar-to-content selection
- `@State private var columnVisibility: NavigationSplitViewVisibility = .all` for 3-column control

**Key constraint from UX spec (Section 1.2):**
> "This layout means a developer can edit a mock endpoint in the center while watching requests hit it in real-time on the right."

The UX spec says: sidebar = endpoints, content = editor/log, detail = request log. The requirements say: detail = request inspector. The implementation should use: sidebar = server + endpoints, content = endpoint editor, detail = request log list. When a log entry is tapped in the detail column, it pushes to RequestDetailView within that same column via NavigationStack.

### Pattern 3: TabView with Persistent Server Status Bar (iPhone)
**What:** 3-tab layout (Endpoints, Log, Settings) with a server status bar visible across all tabs.
**Architecture decisions:**
- Each tab wraps its content in a NavigationStack
- ServerStatusBarView placed above TabView or at top of each tab's NavigationStack
- Tab badge on Log tab shows unseen request count (future enhancement, not in NAVI-02 requirements)

**Key constraint from requirements (NAVI-02):**
> "iPhone uses TabView with 3 tabs (Endpoints, Log, Settings) and persistent server status bar"

The UX spec suggests 2 tabs, but requirements explicitly say 3 tabs with a Settings tab. **Requirements override** the UX spec.

### Pattern 4: Empty State with Sample API Generation (NAVI-03)
**What:** When no endpoints exist, show a "Create Sample API" button that generates 4 CRUD endpoints and auto-starts the server.
**Architecture decisions:**
- Empty state rendered conditionally when `endpointStore.endpointCount == 0`
- Sample endpoints: GET /api/users, GET /api/users/:id, POST /api/users, DELETE /api/users/:id
- SampleEndpointGenerator is a caseless enum (matches BuiltInTemplates, CurlGenerator convention)
- After creating endpoints, auto-start server via `serverStore.startServer(endpointStore:)`
- Empty state is shown in the EndpointListView content area (both iPad sidebar and iPhone Endpoints tab)

### Pattern 5: Settings Screen (NAVI-04)
**What:** Settings screen with server config, feature toggles, and ecosystem links.
**Architecture decisions:**
- SettingsView uses Form with grouped sections (standard iOS settings pattern)
- Port config: TextField with number keyboard for UInt16 input, validated 1024-65535
- Localhost-only toggle: new ServerConfiguration/ServerStore property `localhostOnly: Bool`
- CORS toggle, auto-start toggle: already exist in ServerStore/ServerConfiguration
- Clear log: calls `endpointStore.clearLog()`
- Import/Export: reuses existing fileImporter/fileExporter from EndpointListView (or duplicates the buttons)
- About section: app version from Bundle.main, copyright
- Ecosystem links: ProbePad, DeltaPad, GuardPad, BeaconPad -- open App Store via URL scheme
- On iPhone: Settings is Tab 3
- On iPad: Settings is accessible via toolbar gear icon (sheet presentation)

### Anti-Patterns to Avoid
- **Nested NavigationStacks inside NavigationSplitView:** NavigationSplitView provides its own navigation context for each column. Wrapping sidebar or content in another NavigationStack causes double navigation bars and broken push navigation. Each column in NavigationSplitView already has NavigationStack behavior.
- **Dual @AppStorage for same key in parent+child:** Causes infinite render loop. The current app avoids @AppStorage entirely (uses ServerStore with didSet write-through), so this should remain the approach for any new settings.
- **Color/Image without intrinsic size in ScrollView:** Already documented in MEMORY.md. Empty state must use VStack+Spacer, not ScrollView with Color backgrounds.
- **Putting NavigationSplitView inside TabView:** On iPad, the app should NOT use TabView. The UX spec is clear: iPad = NavigationSplitView, iPhone = TabView. Never both simultaneously.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Adaptive layout detection | Custom UIKit size class monitoring | `@Environment(\.horizontalSizeClass)` | SwiftUI native, reactive, correct |
| 3-column navigation | Custom view switching with manual state | `NavigationSplitView(columnVisibility:)` | Apple handles column sizing, gestures, collapse |
| Tab bar | Custom bottom bar | `TabView` with `.tabItem` | Standard iOS behavior, VoiceOver support built-in |
| App Store links | Custom URL construction | `SKStoreProductViewController` or `URL(string: "itms-apps://...")` | Handles edge cases, App Review safe |

**Key insight:** NavigationSplitView handles all the complex column visibility, resizing, and collapse behavior automatically. The UX spec's width breakpoint table (full/2/3/1/2/1/3 screen) is handled by the system -- do not try to manually control column widths.

## Common Pitfalls

### Pitfall 1: NavigationSplitView Selection Binding with @Model Objects
**What goes wrong:** Using `@State private var selectedEndpoint: MockEndpoint?` as the NavigationSplitView selection binding can cause issues because SwiftData @Model objects are not `Hashable` by default in the way NavigationLink's `value:` parameter expects.
**Why it happens:** NavigationSplitView's `List(selection:)` requires the selection type to conform to `Hashable`. SwiftData @Model classes get `Hashable` via their `PersistentIdentifier`, but the selection binding must match the type used in `NavigationLink(value:)`.
**How to avoid:** Use `PersistentIdentifier` as the selection type: `@State private var selectedEndpointID: MockEndpoint.ID?`. Then look up the actual MockEndpoint from the EndpointStore when needed for the content column.
**Warning signs:** Navigation links don't highlight, selection doesn't persist across column visibility changes.

### Pitfall 2: Environment Objects Not Available in All Tab Views
**What goes wrong:** If environment objects (.environment(endpointStore), .environment(serverStore)) are injected at the TabView level, they flow into all tabs correctly. But if injected only on specific views, tabs that navigate to shared views (like ProPaywallView) may crash.
**Why it happens:** Each Tab's NavigationStack is a separate view hierarchy. Environment must be injected at the root.
**How to avoid:** Keep environment injection at the WindowGroup level in MockPadApp (already done correctly). All tab content and push destinations inherit from there.
**Warning signs:** "No @Observable object of type X found" crashes when navigating within a tab.

### Pitfall 3: scenePhase Lifecycle Conflicts with Adaptive Navigation
**What goes wrong:** The current ContentView handles scenePhase for auto-start/stop. If the adaptive layout splits ContentView into iPad vs iPhone branches, both branches need scenePhase handling, or it needs to stay at the ContentView root level above the conditional.
**Why it happens:** scenePhase onChange is view-level, not app-level.
**How to avoid:** Keep `.onChange(of: scenePhase)` and `.task { proManager... }` at the ContentView root level, ABOVE the iPad/iPhone conditional. This ensures lifecycle behavior is consistent regardless of layout.
**Warning signs:** Server doesn't auto-start on iPad, or doesn't auto-stop on background.

### Pitfall 4: Sheet Presentations from NavigationSplitView Sidebar
**What goes wrong:** Sheets attached to views inside NavigationSplitView sidebar may present incorrectly (too narrow, behind columns, or duplicated).
**Why it happens:** NavigationSplitView's column layout affects sheet presentation context.
**How to avoid:** Attach sheets to the NavigationSplitView itself or to the outermost container, not to individual column content views. For AddEndpointSheet, attach it at the ContentView level.
**Warning signs:** Sheets appear in wrong column, sheets appear too narrow on iPad.

### Pitfall 5: EndpointListView Toolbar Conflicts
**What goes wrong:** EndpointListView currently sets `.navigationTitle("Endpoints")` and `.toolbar { ... }`. When embedded in NavigationSplitView sidebar, the toolbar items may conflict with the NavigationSplitView's own toolbar management.
**Why it happens:** NavigationSplitView manages toolbar placement across columns.
**How to avoid:** On iPad, the sidebar's toolbar items should be minimal (+ button, overflow menu). The full toolbar from EndpointListView may need to be conditionally simplified when in sidebar mode, or the toolbar items may need to be lifted to the NavigationSplitView level.
**Warning signs:** Duplicate toolbar items, missing toolbar items, toolbar items in wrong column.

### Pitfall 6: Localhost-Only Toggle Requires NWListener Parameter Change
**What goes wrong:** Adding a "localhost-only" toggle (NAVI-04) requires changing the NWListener's network parameters. If localhost-only is true, the listener should bind to `NWEndpoint.hostPort(host: .ipv4(.loopback), port: ...)` instead of a generic port.
**Why it happens:** By default, NWListener may listen on all interfaces (0.0.0.0), making the server accessible from other devices on the same network.
**How to avoid:** The `localhostOnly` flag should be passed to MockServerEngine.start() and used to configure the NWListener parameters. This is a small engine change.
**Warning signs:** Server accessible from other devices when localhost-only is enabled.

## Code Examples

### Existing ContentView (Current State)
```swift
// Source: /workspace/MockPad/MockPad/ContentView.swift
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager

    var body: some View {
        NavigationStack {
            EndpointListView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            RequestLogListView()
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { ... }
        .task { ... }
    }
}
```

### Target: Adaptive Navigation Container
```swift
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Same lifecycle logic as before
        }
        .task {
            await proManager.loadProduct()
            await proManager.checkEntitlements()
        }
    }
}
```

### NavigationSplitView 3-Column (iPad)
```swift
// Source: Apple NavigationSplitView documentation + MOCKPAD-UX.md Section 1.2
private var iPadLayout: some View {
    @State var selectedEndpointID: PersistentIdentifier?
    @State var columnVisibility: NavigationSplitViewVisibility = .all

    NavigationSplitView(columnVisibility: $columnVisibility) {
        // Sidebar: Server status + Endpoint list
        SidebarView(selectedEndpointID: $selectedEndpointID)
    } content: {
        // Content: Endpoint editor or placeholder
        if let id = selectedEndpointID,
           let endpoint = endpointStore.endpoint(withID: id) {
            EndpointEditorView(endpoint: endpoint)
        } else {
            ContentUnavailableView("Select an Endpoint",
                systemImage: "curlybraces",
                description: Text("Choose an endpoint to edit"))
        }
    } detail: {
        // Detail: Request log with push to detail
        NavigationStack {
            RequestLogListView()
        }
    }
}
```

### TabView with Status Bar (iPhone)
```swift
// Source: NAVI-02 requirements
private var iPhoneLayout: some View {
    VStack(spacing: 0) {
        ServerStatusBarView()
        TabView {
            NavigationStack {
                EndpointListView()
            }
            .tabItem { Label("Endpoints", systemImage: "list.bullet") }

            NavigationStack {
                RequestLogListView()
            }
            .tabItem { Label("Log", systemImage: "scroll") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
```

### Sample API Generator
```swift
// Follows caseless enum pattern (BuiltInTemplates, CurlGenerator convention)
enum SampleEndpointGenerator {
    static func createSampleEndpoints() -> [MockEndpoint] {
        [
            MockEndpoint(
                path: "/api/users",
                httpMethod: "GET",
                responseStatusCode: 200,
                responseBody: """
                {
                  "data" : [
                    { "email" : "alice@example.com", "id" : 1, "name" : "Alice" },
                    { "email" : "bob@example.com", "id" : 2, "name" : "Bob" }
                  ],
                  "total" : 2
                }
                """,
                sortOrder: 0
            ),
            MockEndpoint(
                path: "/api/users/:id",
                httpMethod: "GET",
                responseStatusCode: 200,
                responseBody: """
                {
                  "email" : "alice@example.com",
                  "id" : 1,
                  "name" : "Alice"
                }
                """,
                sortOrder: 1
            ),
            MockEndpoint(
                path: "/api/users",
                httpMethod: "POST",
                responseStatusCode: 201,
                responseBody: """
                {
                  "id" : 3,
                  "message" : "User created"
                }
                """,
                sortOrder: 2
            ),
            MockEndpoint(
                path: "/api/users/:id",
                httpMethod: "DELETE",
                responseStatusCode: 204,
                responseBody: "",
                sortOrder: 3
            ),
        ]
    }
}
```

### ServerStatusBarView (Reusable)
```swift
struct ServerStatusBarView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore

    var body: some View {
        HStack {
            Circle()
                .fill(serverStore.isRunning ? MockPadColors.serverRunning : MockPadColors.serverStopped)
                .frame(width: MockPadMetrics.serverDotSize, height: MockPadMetrics.serverDotSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(serverStore.isRunning ? "SERVER: RUNNING" : "SERVER: STOPPED")
                    .font(MockPadTypography.serverStatus)
                    .foregroundColor(serverStore.isRunning ? MockPadColors.serverRunning : MockPadColors.textMuted)

                Text(serverStore.serverURL)
                    .font(MockPadTypography.logTimestamp)
                    .foregroundColor(MockPadColors.textMuted)
            }

            Spacer()

            Button {
                Task {
                    if serverStore.isRunning {
                        await serverStore.stopServer()
                    } else {
                        await serverStore.startServer(endpointStore: endpointStore)
                    }
                }
            } label: {
                Text(serverStore.isRunning ? "STOP" : "START")
                    .font(MockPadTypography.badge)
                    .foregroundColor(serverStore.isRunning ? MockPadColors.serverStopped : MockPadColors.serverRunning)
            }
        }
        .padding(.horizontal, MockPadMetrics.panelPadding)
        .frame(height: MockPadMetrics.serverStatusBarHeight)
        .background(MockPadColors.panel)
    }
}
```

### SettingsView
```swift
struct SettingsView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager

    var body: some View {
        Form {
            // Server section
            Section {
                // Port config (TextField, number keyboard)
                // Localhost-only toggle
                // CORS toggle
                // Auto-start toggle
            } header: {
                Text("> SERVER_").blueprintLabelStyle()
            }

            // Data section
            Section {
                // Clear log button
                // Import / Export buttons
            } header: {
                Text("> DATA_").blueprintLabelStyle()
            }

            // About section
            Section {
                // Version, build
            } header: {
                Text("> ABOUT_").blueprintLabelStyle()
            }

            // Ecosystem section
            Section {
                // ProbePad, DeltaPad, GuardPad links
            } header: {
                Text("> MORE APPS_").blueprintLabelStyle()
            }
        }
        .scrollContentBackground(.hidden)
        .background(MockPadColors.background)
        .navigationTitle("Settings")
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NavigationView with columns | NavigationSplitView | iOS 16 (2022) | NavigationSplitView is the correct API for multi-column |
| UITabBarController wrapping | SwiftUI TabView | iOS 13+ (2019) | Fully native SwiftUI tab bar |
| Manual size class detection | @Environment(\.horizontalSizeClass) | iOS 14+ (2020) | Reactive, automatic |
| Custom empty states | ContentUnavailableView | iOS 17 (2023) | System-standard empty state (optional -- custom is fine for branded look) |

**Deprecated/outdated:**
- NavigationView: Deprecated since iOS 16. Use NavigationStack (single column) or NavigationSplitView (multi-column).
- UISplitViewController wrapping: Unnecessary since NavigationSplitView provides equivalent native SwiftUI API.

## Open Questions

1. **Localhost-only toggle implementation depth**
   - What we know: NAVI-04 requires a "localhost-only toggle" in Settings. ServerConfiguration currently has port, corsEnabled, autoStart.
   - What's unclear: Does localhost-only mean bind to loopback only (127.0.0.1) vs all interfaces (0.0.0.0)? This requires a MockServerEngine change to pass the bind address to NWListener.
   - Recommendation: Add `localhostOnly` Bool to ServerConfiguration/ServerStore. Pass it to MockServerEngine.start(). When true, use `NWEndpoint.hostPort(host: .ipv4(.loopback), port: ...)` instead of just the port. Default: true (matches design doc's security-conscious default). This is a small scope addition.

2. **EndpointStore.endpoint(withID:) lookup for NavigationSplitView**
   - What we know: NavigationSplitView selection works best with Hashable IDs. Currently EndpointStore fetches all endpoints, no single-ID lookup.
   - What's unclear: Whether PersistentIdentifier-based selection is the best approach, or whether the existing endpoints array index is sufficient.
   - Recommendation: Add `func endpoint(withID id: PersistentIdentifier) -> MockEndpoint?` to EndpointStore using a FetchDescriptor with predicate. This keeps selection stable across data changes.

3. **Import/Export in Settings vs EndpointListView**
   - What we know: Import/Export UI already exists in EndpointListView's toolbar menu. NAVI-04 says Settings includes "import/export."
   - What's unclear: Should Settings duplicate the import/export buttons, or should it link/navigate to the existing flow?
   - Recommendation: Settings should have simple "Import Endpoints" and "Export Endpoints" buttons that trigger the same fileImporter/fileExporter flows. Reuse the logic, but the UI buttons live in Settings as well for discoverability.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: All 20+ Swift source files read directly from /workspace/MockPad/
- Design specifications: MOCKPAD-UX.md (Sections 1.2, 1.3, 1.4, 2.1, 4, 7, 11)
- Design specifications: MOCKPAD-DESIGN.md (Sections 1, 5)
- Design specifications: MOCKPAD-INTERACTIONS.md (Sections 2, 14)
- Requirements: NAVI-01, NAVI-02, NAVI-03, NAVI-04 from REQUIREMENTS.md
- Prior phase decisions: STATE.md accumulated decisions (24 plans completed)

### Secondary (MEDIUM confidence)
- NavigationSplitView API: Based on Apple's SwiftUI documentation and established patterns in iOS 16+
- TabView API: Standard SwiftUI since iOS 13, well-documented
- horizontalSizeClass: Standard SwiftUI environment value since iOS 14

### Tertiary (LOW confidence)
- NWListener localhost binding via NWEndpoint.hostPort: Needs verification during implementation that `.ipv4(.loopback)` correctly restricts to 127.0.0.1 only

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using only built-in SwiftUI APIs (NavigationSplitView, TabView, horizontalSizeClass)
- Architecture: HIGH - All existing views read, navigation reorganization is well-understood
- Pitfalls: HIGH - NavigationSplitView selection, environment propagation, and nested NavigationStack issues are well-documented patterns
- Empty state / Sample API: HIGH - Straightforward data creation following established BuiltInTemplates pattern
- Settings view: HIGH - Standard Form-based settings, all configuration properties already exist in ServerStore/ServerConfiguration
- Localhost-only toggle: MEDIUM - Requires small MockServerEngine modification, NWEndpoint binding needs verification

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable APIs, no fast-moving dependencies)
