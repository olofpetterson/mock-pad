# Codebase Structure

**Analysis Date:** 2026-02-16

## Directory Layout

```
workspace/
├── MockPad/                         # Xcode project root
│   ├── MockPad.xcodeproj/           # Xcode project definition
│   │   ├── project.pbxproj          # Build config, targets, settings
│   │   └── project.xcworkspace/     # Workspace metadata
│   ├── MockPad/                     # Main app target sources
│   │   ├── MockPadApp.swift         # @main entry point
│   │   ├── ContentView.swift        # Root SwiftUI view
│   │   ├── Item.swift               # SwiftData model
│   │   └── Assets.xcassets/         # App icons, accent color
│   ├── MockPadTests/                # Unit test target
│   │   └── MockPadTests.swift       # Swift Testing suite (stub)
│   └── MockPadUITests/              # UI test target
│       ├── MockPadUITests.swift     # XCTest UI tests
│       └── MockPadUITestsLaunchTests.swift  # Launch performance test
├── .planning/                       # GSD workflow planning docs
│   └── codebase/                    # Codebase analysis documents
├── Dockerfile                       # Claude sandbox container definition
├── docker-compose.yml               # Dev sandbox orchestration
├── sandbox.sh                       # Sandbox entry script
├── README.md                        # Project README (minimal)
└── .gitignore                       # Git ignore rules
```

## Directory Purposes

**`MockPad/MockPad/` (main app target):**
- Purpose: All production Swift source files for the iOS app
- Contains: App entry point, SwiftUI views, SwiftData models
- Key files: `MockPadApp.swift`, `ContentView.swift`, `Item.swift`
- Note: Uses `PBXFileSystemSynchronizedRootGroup` — new files added here are auto-detected by Xcode, no `project.pbxproj` edits needed

**`MockPad/MockPadTests/`:**
- Purpose: Unit test target using Swift Testing framework
- Contains: `@testable import MockPad` struct-based test suites
- Key files: `MockPadTests.swift`
- Note: Does NOT have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — use `@MainActor` explicitly on test structs if needed

**`MockPad/MockPadUITests/`:**
- Purpose: UI test target using XCTest (XCUITest)
- Contains: `XCTestCase` subclasses, launch tests
- Key files: `MockPadUITests.swift`, `MockPadUITestsLaunchTests.swift`
- Note: Uses XCTest (not Swift Testing) for UI tests

**`MockPad/MockPad/Assets.xcassets/`:**
- Purpose: Asset catalog for images, icons, colors
- Contains: `AppIcon.appiconset/`, `AccentColor.colorset/`
- Generated: No — hand-managed

**`.planning/`:**
- Purpose: GSD workflow planning, codebase analysis
- Contains: Phase plans, milestone archives, codebase docs
- Committed: Yes

## Key File Locations

**Entry Points:**
- `MockPad/MockPad/MockPadApp.swift`: `@main` struct, `ModelContainer` setup, `WindowGroup` scene

**Data Models:**
- `MockPad/MockPad/Item.swift`: `@Model` SwiftData entity

**Root View:**
- `MockPad/MockPad/ContentView.swift`: Primary SwiftUI view

**Xcode Project:**
- `MockPad/MockPad.xcodeproj/project.pbxproj`: Build settings, targets, deployment config

**Tests:**
- `MockPad/MockPadTests/MockPadTests.swift`: Unit tests (Swift Testing)
- `MockPad/MockPadUITests/MockPadUITests.swift`: UI tests (XCTest)

## Naming Conventions

**Files:**
- PascalCase for all Swift source files matching their primary type: `ContentView.swift`, `MockPadApp.swift`, `Item.swift`
- Test files mirror target name: `MockPadTests.swift`, `MockPadUITests.swift`

**Directories:**
- App sources directory matches product name: `MockPad/`
- Test target directories match target names: `MockPadTests/`, `MockPadUITests/`

**Swift Types:**
- Structs/Classes/Enums: PascalCase
- Functions/properties: camelCase
- `@main` struct suffix `App`: `MockPadApp`
- Views suffix `View`: `ContentView`

## Where to Add New Code

**New SwiftUI View:**
- Implementation: `MockPad/MockPad/` (e.g., `MockPad/MockPad/DetailView.swift`)
- Auto-detected by Xcode (PBXFileSystemSynchronizedRootGroup)

**New SwiftData Model:**
- Implementation: `MockPad/MockPad/` (e.g., `MockPad/MockPad/Project.swift`)
- Register in schema in `MockPad/MockPad/MockPadApp.swift` by adding to the `Schema([...])` array

**New Service/Logic:**
- Implementation: `MockPad/MockPad/` — create subdirectories as feature areas grow (e.g., `MockPad/MockPad/Services/`)

**New Unit Test:**
- Location: `MockPad/MockPadTests/MockPadTests.swift` or new file in `MockPad/MockPadTests/`
- Pattern: `import Testing`, `@testable import MockPad`, struct-based suite, `@Test func`, `#expect()`

**New UI Test:**
- Location: `MockPad/MockPadUITests/`
- Pattern: `import XCTest`, `final class ... : XCTestCase`

## Special Directories

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents (ARCHITECTURE.md, STRUCTURE.md, etc.)
- Generated: By `/gsd:map-codebase` command
- Committed: Yes

**`MockPad/MockPad/Assets.xcassets/`:**
- Purpose: Asset catalog (icons, colors, images)
- Generated: No
- Committed: Yes

## Build Configuration Notes

- `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (iOS 26.2+)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on main app target
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` on main app target
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — affects import visibility in tests
- `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`
- Bundle ID: `com.olof.petterson.MockPad`
- Three targets: `MockPad` (app), `MockPadTests` (unit), `MockPadUITests` (UI)

---

*Structure analysis: 2026-02-16*
