# Coding Conventions

**Analysis Date:** 2026-02-16

## Naming Patterns

**Files:**
- PascalCase matching the primary type defined within: `ContentView.swift`, `MockPadApp.swift`, `Item.swift`
- App entry point named `[AppName]App.swift`

**Types (classes, structs, enums):**
- PascalCase: `MockPadApp`, `ContentView`, `Item`
- SwiftUI Views use `View` suffix: `ContentView`
- App entry point uses `App` suffix: `MockPadApp`

**Functions/Methods:**
- camelCase: `addItem()`, `deleteItems(offsets:)`
- Private helpers marked `private`

**Variables/Properties:**
- camelCase: `modelContext`, `sharedModelContainer`, `newItem`
- SwiftUI property wrappers use standard names: `items`, `modelContext`

**Constants:**
- Not yet established (project is a scaffold)

## Code Style

**Formatting:**
- No `.editorconfig`, `.swiftformat`, or `.prettierrc` detected
- Xcode default formatting implied (4-space indentation observed)

**Linting:**
- No SwiftLint config detected
- Xcode static analyzer warnings enabled via build settings (`CLANG_ANALYZER_NONNULL = YES`, etc.)

## Swift Build Settings

**Concurrency:**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types in the main app target are implicitly `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — enables approachable concurrency diagnostics
- Test target does NOT have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Member Import Visibility:**
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — explicit import required for members; use explicit `import Foundation` in test files when needed

**Swift Version:** 5.0

**iOS Deployment Target:** iOS 26.2 (Xcode 26)

## Import Organization

**Order (observed):**
1. Framework imports (`import SwiftUI`, `import SwiftData`, `import Foundation`)
2. No third-party imports (zero external dependencies)

**Pattern:**
- Only import what is needed per file
- `@testable import MockPad` in unit test files

## SwiftData Model Pattern

**Model declaration:**
```swift
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
```

- Use `@Model` macro on `final class`
- Stored properties are `var` (SwiftData requirement)
- Memberwise initializer provided explicitly

## SwiftUI View Pattern

**Structure:**
```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        // view hierarchy
    }

    private func addItem() { ... }
    private func deleteItems(offsets: IndexSet) { ... }
}
```

- Views are `struct` conforming to `View`
- `@Environment` and `@Query` declared as `private`
- Mutation helpers extracted as `private func`
- `withAnimation` wraps SwiftData mutations

## App Entry Point Pattern

```swift
@main
struct MockPadApp: App {
    var sharedModelContainer: ModelContainer = {
        // setup
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- `ModelContainer` setup via immediately-invoked closure on a `var` property
- Fatal error on container creation failure (acceptable for critical setup)
- `.modelContainer()` injected at scene level

## Error Handling

**Strategy:** Minimal — project is a new scaffold

**Patterns observed:**
- `fatalError` used for non-recoverable setup failures (ModelContainer creation): `MockPadApp.swift`
- `do/catch` wrapping `try` for throwing initializers
- No custom error types yet

## Comments

**When to Comment:**
- No inline comments in source files beyond Xcode file header template
- File header template: `//`, `//  FileName.swift`, `//  AppName`, `//`, `//  Created by Name on YYYY-MM-DD.`, `//`

**JSDoc/TSDoc:**
- Not applicable (Swift project)

## Module Design

**Exports:** Single module `MockPad`; all types are internal by default
**No barrel files** — not applicable in Swift (no re-export pattern needed)

## Previews

- `#Preview` macro used on all SwiftUI views
- In-memory `ModelContainer` provided in previews:

```swift
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
```

---

*Convention analysis: 2026-02-16*
