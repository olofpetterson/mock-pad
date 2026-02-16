# Technology Stack

**Analysis Date:** 2026-02-16

## Languages

**Primary:**
- Swift 5.0 - All application and test source code

**Secondary:**
- Not applicable

## Runtime

**Environment:**
- iOS 26.2+ (IPHONEOS_DEPLOYMENT_TARGET = 26.2)
- Supports iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2")

**Package Manager:**
- Swift Package Manager (built into Xcode)
- No external Swift packages added yet (packageProductDependencies is empty in all targets)

## Frameworks

**Core:**
- SwiftUI - UI layer, declarative views (`MockPad/MockPad/ContentView.swift`, `MockPad/MockPad/MockPadApp.swift`)
- SwiftData - Persistence layer, model definitions (`MockPad/MockPad/Item.swift`, `MockPad/MockPad/MockPadApp.swift`)
- Foundation - Base types (used in model layer)

**Testing:**
- Swift Testing (`import Testing`) - Unit test framework (`MockPad/MockPadTests/MockPadTests.swift`)
- XCTest - UI test framework (`MockPad/MockPadUITests/MockPadUITests.swift`, `MockPad/MockPadUITests/MockPadUITestsLaunchTests.swift`)

**Build/Dev:**
- Xcode 26.3 (LastUpgradeCheck = 2630, CreatedOnToolsVersion = 26.3)
- Docker / Node.js 20 - Development sandbox environment (`Dockerfile`, `docker-compose.yml`)

## Key Dependencies

**Critical:**
- SwiftData - Provides `@Model`, `ModelContainer`, `ModelConfiguration`, `@Query`, `@Environment(\.modelContext)` — the entire persistence stack
- SwiftUI - Provides all UI primitives (`NavigationSplitView`, `List`, `View`, `@main`, `Scene`)

**Infrastructure:**
- @anthropic-ai/claude-code (npm, global install) - Claude Code agent tooling, installed in Docker sandbox (`Dockerfile`)

## Configuration

**Build Settings (main app target):**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` - All declarations default to MainActor isolation
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` - Approachable concurrency enabled
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` - Explicit member import visibility
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` - Uses .xcstrings format
- `STRING_CATALOG_GENERATE_SYMBOLS = YES` - Generates typed string symbols
- `ENABLE_PREVIEWS = YES` - SwiftUI Previews enabled

**Build Settings (test targets):**
- Unit test (MockPadTests): No `SWIFT_DEFAULT_ACTOR_ISOLATION` override — does NOT inherit MainActor default
- UI test (MockPadUITests): No `SWIFT_DEFAULT_ACTOR_ISOLATION` override

**Build:**
- `MockPad/MockPad.xcodeproj/project.pbxproj` - Xcode project config
- `PBXFileSystemSynchronizedRootGroup` used for all three targets — new files are auto-detected, no pbxproj edits needed
- Two configurations: Debug (DWARF, `-Onone`) and Release (`dwarf-with-dsym`, whole-module optimization)

**Environment:**
- `ANTHROPIC_API_KEY` - Passed via Docker Compose environment (`docker-compose.yml`)
- `~/.claude` - Claude credentials volume-mounted into sandbox

## Platform Requirements

**Development:**
- macOS with Xcode 26.3+ for building iOS app
- Docker Desktop for running Claude Code sandbox (`sandbox.sh`)
- Node.js 20 inside Docker container

**Production:**
- iOS 26.2+ on iPhone or iPad
- App Store distribution (bundle ID: `com.olof.petterson.MockPad`, development team: `DL3WW5LA6T`)
- Code signing: Automatic

---

*Stack analysis: 2026-02-16*
