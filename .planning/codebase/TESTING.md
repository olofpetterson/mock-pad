# Testing Patterns

**Analysis Date:** 2026-02-16

## Test Framework

**Unit Test Runner:**
- Swift Testing (Apple's native framework, Xcode 26)
- Import: `import Testing`
- Config: No separate config file — Xcode target `MockPadTests`

**UI Test Runner:**
- XCTest (XCTestCase-based)
- Import: `import XCTest`
- Config: No separate config file — Xcode target `MockPadUITests`

**Assertion Library:**
- Unit tests: `#expect()` macro (Swift Testing)
- UI tests: `XCTAssert` family (XCTest)

**Run Commands:**
```bash
# Run via Xcode: Cmd+U
# Run from CLI:
xcodebuild test -project MockPad/MockPad.xcodeproj -scheme MockPad -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Test File Organization

**Location:**
- Unit tests: `MockPad/MockPadTests/` — separate directory from app source
- UI tests: `MockPad/MockPadUITests/` — separate directory from app source

**Naming:**
- Unit test file: `MockPadTests.swift` (matches target name)
- UI test files: `MockPadUITests.swift`, `MockPadUITestsLaunchTests.swift`

**Structure:**
```
MockPad/
├── MockPad/                    # App source
│   ├── MockPadApp.swift
│   ├── ContentView.swift
│   └── Item.swift
├── MockPadTests/               # Unit tests (Swift Testing)
│   └── MockPadTests.swift
└── MockPadUITests/             # UI tests (XCTest)
    ├── MockPadUITests.swift
    └── MockPadUITestsLaunchTests.swift
```

## Test Structure

**Unit Test Suite (Swift Testing):**
```swift
import Testing
@testable import MockPad

struct MockPadTests {

    @Test func example() async throws {
        // #expect(...) assertions here
    }

}
```

- Struct-based test suites (NOT class-based)
- `@testable import MockPad` for internal access
- `@Test` attribute on each test function
- Functions are `async throws` by default

**UI Test Suite (XCTest):**
```swift
import XCTest

final class MockPadUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws { }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
```

- Class-based (inherits `XCTestCase`)
- `@MainActor` on test methods that interact with UI
- `continueAfterFailure = false` in `setUpWithError` (stop on first failure)

**Launch Tests Pattern:**
```swift
final class MockPadUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true  // runs for all device configs
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- Screenshot attached with `.keepAlways` for visual verification

## Build Settings for Tests

**Unit test target (`MockPadTests`):**
- Does NOT have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Has `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Has `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — explicit `import Foundation` required when using Foundation types

**App target (affects unit tests via `@testable import`):**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — types from app are implicitly `@MainActor`
- Unit tests accessing `@MainActor` types may need `await` or `@MainActor` annotation

## Mocking

**Framework:** None yet (project is a scaffold)

**Expected patterns (based on project memory):**
- Protocol-based mock injection for services
- `@unchecked Sendable` on mock classes with mutable state
- `MockURLProtocol` for HTTP request interception if networking is added

## Fixtures and Factories

**Test Data:** None yet

**SwiftData in tests:**
- Use in-memory `ModelContainer` for unit tests:
```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Item.self, configurations: [config])
```

## Coverage

**Requirements:** None enforced (no coverage thresholds configured)

**View Coverage:**
```bash
xcodebuild test -project MockPad/MockPad.xcodeproj -scheme MockPad \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES
```

## Test Types

**Unit Tests (`MockPadTests` target):**
- Framework: Swift Testing
- Scope: Logic, models, services
- Pattern: Struct-based, `@Test` functions, `#expect()` assertions

**UI Tests (`MockPadUITests` target):**
- Framework: XCTest / XCUITest
- Scope: App launch, user interactions, screenshots
- Pattern: Class-based `XCTestCase`, `XCUIApplication().launch()`

**E2E Tests:**
- Not used beyond XCUITest

## Common Patterns

**Async Testing (Swift Testing):**
```swift
@Test func asyncExample() async throws {
    let result = await someAsyncOperation()
    #expect(result == expectedValue)
}
```

**Error Testing (Swift Testing):**
```swift
@Test func errorExample() throws {
    #expect(throws: SomeError.self) {
        try throwingFunction()
    }
}
```

**SwiftData Model Testing:**
```swift
@Test func modelExample() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Item.self, configurations: [config])
    let context = ModelContext(container)

    let item = Item(timestamp: Date())
    context.insert(item)

    let items = try context.fetch(FetchDescriptor<Item>())
    #expect(items.count == 1)
}
```

---

*Testing analysis: 2026-02-16*
