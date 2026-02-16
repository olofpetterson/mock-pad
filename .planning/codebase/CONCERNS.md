# Codebase Concerns

**Analysis Date:** 2026-02-16

## Tech Debt

**Xcode Template Scaffold - No App Logic:**
- Issue: The entire app is an unmodified Xcode template. `ContentView.swift` and `Item.swift` contain only auto-generated boilerplate with no actual MockPad functionality.
- Files: `MockPad/MockPad/ContentView.swift`, `MockPad/MockPad/Item.swift`, `MockPad/MockPad/MockPadApp.swift`
- Impact: There is no real application to build on. All feature work starts from scratch on top of this scaffold.
- Fix approach: Replace template files with actual feature code as development phases proceed.

**fatalError in Production Code Path:**
- Issue: `MockPadApp.swift` uses `fatalError("Could not create ModelContainer: \(error)")` inside the `sharedModelContainer` property initializer. This will crash the app at launch if the SwiftData store cannot be created (e.g., after a schema migration failure or corrupt store).
- Files: `MockPad/MockPad/MockPadApp.swift` line 22
- Impact: Users with a corrupt or incompatible store will see an immediate crash on every launch with no recovery path.
- Fix approach: Replace `fatalError` with graceful error handling — either attempt store deletion/recreation for development, or show a recovery UI in production. Consider a migration plan before adding new `@Model` types.

**Item Model Has No Domain Meaning:**
- Issue: `Item.swift` defines a model with only a `timestamp: Date` field. It is the Xcode template placeholder and has no relationship to any planned MockPad domain objects (mock servers, endpoints, requests, responses, etc.).
- Files: `MockPad/MockPad/Item.swift`
- Impact: Any feature work that adds real models will need to delete or replace `Item`. If `Item` is committed to a device first, a SwiftData migration is required.
- Fix approach: Delete `Item.swift` before adding real `@Model` types, or ensure it is replaced in the first feature phase before any device runs.

**Test Target Missing `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`:**
- Issue: The main app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (confirmed in `project.pbxproj` lines 417, 449). The `MockPadTests` target does NOT include this setting (lines 457-478). This is a known pattern mismatch from prior projects.
- Files: `MockPad/MockPad.xcodeproj/project.pbxproj` (MockPadTests build config, lines 457-500)
- Impact: Test code calling `@MainActor`-isolated types will require explicit `@MainActor` annotations on test structs or `await MainActor.run {}` wrappers. Forgetting this causes compiler errors that are surprising if the developer expects parity with app target isolation.
- Fix approach: Add `@MainActor` to test structs as needed, or explicitly add `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` to test target build settings if that pattern is preferred.

## Known Bugs

**No Known Bugs (Pre-Development State):**
- The codebase is an unmodified Xcode scaffold with no feature code. No bugs exist yet beyond the `fatalError` concern noted above.

## Security Considerations

**ANTHROPIC_API_KEY Passed via Environment in docker-compose:**
- Risk: The `docker-compose.yml` passes `ANTHROPIC_API_KEY` as an environment variable to the container. If `docker inspect` is run or compose logs are exposed, the key value could be leaked.
- Files: `docker-compose.yml` line 8
- Current mitigation: The key is sourced from the host environment (`${ANTHROPIC_API_KEY:-}`) rather than hardcoded.
- Recommendations: Confirm the key is never committed to `.env` files. Ensure `.env` and any file containing the key is in `.gitignore`.

**`~/.claude` Host Directory Mounted into Container:**
- Risk: `docker-compose.yml` mounts `~/.claude` from the host directly into the container. This gives the containerized Claude Code process access to all local Claude credentials and configuration on the host.
- Files: `docker-compose.yml` line 6
- Current mitigation: The container runs as a non-root `claudeuser`.
- Recommendations: Understand that any code executed inside the container with `--dangerously-skip-permissions` has full read access to the mounted `~/.claude` directory including session tokens.

**`--dangerously-skip-permissions` Flag in Dockerfile CMD:**
- Risk: The container CMD launches Claude Code with `--dangerously-skip-permissions` (Dockerfile line 16). This disables Claude Code's normal permission checks, allowing unrestricted file system access within the container.
- Files: `Dockerfile` line 16
- Current mitigation: The container is isolated from the host except for the two mounted volumes (workspace and `~/.claude`).
- Recommendations: Accept this risk deliberately (it is intentional for a dev sandbox) but ensure the workspace volume does not contain secrets that should not be accessible to the agent.

**Developer Team ID Committed in pbxproj:**
- Risk: `DEVELOPMENT_TEAM = DL3WW5LA6T` is hardcoded in `project.pbxproj`. This is the Apple Developer Team ID.
- Files: `MockPad/MockPad.xcodeproj/project.pbxproj` lines 307, 372 (project-level), 400, 431, 463, 486, 506, 527
- Current mitigation: Team IDs are not secret credentials; they are visible in App Store metadata. Low risk.
- Recommendations: No action required. Standard Xcode behavior.

## Performance Bottlenecks

**No Performance Concerns (Pre-Development State):**
- No feature code exists to evaluate. Performance assessment is deferred to feature implementation phases.

## Fragile Areas

**SwiftData Store Initialization with fatalError:**
- Files: `MockPad/MockPad/MockPadApp.swift`
- Why fragile: A single `fatalError` in the computed property means any store initialization failure (schema mismatch after model changes during development, file system permission issue, simulator state corruption) causes an unrecoverable crash. During active development when models change frequently this is a real risk.
- Safe modification: Keep `fatalError` only in debug builds. For release builds, add a fallback to an in-memory store or show an error UI.
- Test coverage: None — `MockPadTests` has an empty `example()` test.

**Empty Test Suite:**
- Files: `MockPad/MockPadTests/MockPadTests.swift`
- Why fragile: The only unit test is an empty async stub. No behavior is verified. Any regression introduced during feature development will go undetected.
- Safe modification: Add `@testable import MockPad` tests for each new model and service added.
- Test coverage: 0 meaningful assertions across all tests.

## Scaling Limits

**SwiftData Single-Store Architecture:**
- Current capacity: Single SQLite store managed by SwiftData for all models.
- Limit: Suitable for the app's expected data volume. No scaling concerns for a dev-tool iOS app.
- Scaling path: Not applicable.

## Dependencies at Risk

**No External Dependencies:**
- The project uses no Swift Package Manager dependencies. Only Apple frameworks (SwiftUI, SwiftData, Foundation) are used.
- Risk: None from third-party packages.

## Missing Critical Features

**No App Features Implemented:**
- Problem: The entire application layer (mock server definitions, endpoint configuration, request/response matching, in-app proxy, etc.) is absent. The project is a blank scaffold.
- Blocks: Nothing can be built or tested until feature phases replace the template code.

**No Localization Setup:**
- Problem: The project has `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and `SWIFT_EMIT_LOC_STRINGS = YES` in build settings, but no `.xcstrings` catalog file exists yet.
- Files: Build settings in `MockPad/MockPad.xcodeproj/project.pbxproj`
- Blocks: Any user-visible strings added without localization now will need retroactive cataloging later.

## Test Coverage Gaps

**Unit Test Target - Empty:**
- What's not tested: All future feature code until tests are added.
- Files: `MockPad/MockPadTests/MockPadTests.swift`
- Risk: Any logic introduced is completely uncovered.
- Priority: High - establish testing patterns in the first feature phase.

**UI Test Target - Only Template Stubs:**
- What's not tested: All UI interactions.
- Files: `MockPad/MockPadUITests/MockPadUITests.swift`, `MockPad/MockPadUITests/MockPadUITestsLaunchTests.swift`
- Risk: `testExample()` launches the app but asserts nothing. `testLaunchPerformance()` measures launch time but provides no baseline.
- Priority: Medium - add meaningful UI tests once core screens are built.

---

*Concerns audit: 2026-02-16*
