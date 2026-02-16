# Architecture

**Analysis Date:** 2026-02-16

## Pattern Overview

**Overall:** SwiftUI + SwiftData MVVM scaffold (Xcode default template, pre-feature development)

**Key Characteristics:**
- Single-target iOS app with SwiftData persistence
- SwiftUI declarative UI bound directly to SwiftData model context via `@Query`
- `@main` app entry point configures `ModelContainer` and injects it into the view hierarchy
- No separate ViewModel layer yet — views read/write model context directly
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` enforced at build settings level

## Layers

**App Entry Point:**
- Purpose: Bootstrap SwiftData ModelContainer and mount root view
- Location: `MockPad/MockPad/MockPadApp.swift`
- Contains: `@main` struct, `ModelContainer` initialization
- Depends on: `Item` model, `ContentView`
- Used by: iOS runtime

**View Layer:**
- Purpose: Render UI and handle user interactions
- Location: `MockPad/MockPad/ContentView.swift`
- Contains: SwiftUI views, toolbar actions, list with NavigationSplitView
- Depends on: SwiftData `@Environment(\.modelContext)`, `@Query` macro
- Used by: `MockPadApp` via `WindowGroup`

**Model Layer:**
- Purpose: Persistent data model
- Location: `MockPad/MockPad/Item.swift`
- Contains: `@Model final class Item` with `timestamp: Date` property
- Depends on: SwiftData framework
- Used by: `ContentView` (via `@Query`), `MockPadApp` (registered in schema)

## Data Flow

**Add Item:**
1. User taps "+" toolbar button in `ContentView`
2. `addItem()` creates `Item(timestamp: Date())`
3. `modelContext.insert(newItem)` persists to SwiftData store
4. `@Query var items` automatically refreshes — list updates via SwiftUI binding

**Delete Item:**
1. User swipes-to-delete or uses Edit mode in list
2. `deleteItems(offsets:)` called with `IndexSet`
3. `modelContext.delete(items[index])` removes from SwiftData store
4. `@Query` refreshes list automatically

**State Management:**
- No separate state store — all state lives in SwiftData model context
- `@Query` provides reactive binding from persistence to UI
- `@Environment(\.modelContext)` provides write access to context

## Key Abstractions

**Item:**
- Purpose: Core persistent data entity
- Examples: `MockPad/MockPad/Item.swift`
- Pattern: `@Model final class` — SwiftData macro-driven persistence

**ModelContainer:**
- Purpose: Configured in-app database container
- Examples: `MockPad/MockPad/MockPadApp.swift` (lines 13-24)
- Pattern: Lazy `var` initialized via closure, injected via `.modelContainer()` scene modifier

## Entry Points

**App Entry:**
- Location: `MockPad/MockPad/MockPadApp.swift`
- Triggers: iOS app launch
- Responsibilities: Initialize SwiftData schema and `ModelContainer`, mount `ContentView` in `WindowGroup`

**Root View:**
- Location: `MockPad/MockPad/ContentView.swift`
- Triggers: Mounted by `MockPadApp.body`
- Responsibilities: Display list of `Item` objects, support add/delete

## Error Handling

**Strategy:** Fatal crash on ModelContainer initialization failure

**Patterns:**
- `fatalError("Could not create ModelContainer: \(error)")` in `MockPadApp.swift` — unrecoverable startup failure crashes immediately
- No user-facing error handling implemented yet

## Cross-Cutting Concerns

**Logging:** None — no logging framework or `os.log` usage
**Validation:** None — model accepts any `Date` timestamp without validation
**Authentication:** Not applicable — local-only app, no user authentication

---

*Architecture analysis: 2026-02-16*
