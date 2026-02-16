---
phase: 02-server-engine-core
plan: 03
subsystem: api
tags: [server-lifecycle, port-fallback, scene-phase, auto-start, auto-stop, swiftdata-logging, cross-actor]

# Dependency graph
requires:
  - phase: 02-server-engine-core
    plan: 02
    provides: MockServerEngine actor, EndpointSnapshot DTO, RequestLogData DTO, onRequestLogged callback
  - phase: 01-foundation
    plan: 02
    provides: EndpointStore.addLogEntry, ServerStore settings, MockEndpoint model
provides:
  - ServerStore.startServer: Engine lifecycle with port fallback (configured port through +10)
  - ServerStore.stopServer: Clean engine shutdown with state reset
  - ServerStore.updateEngineEndpoints: Live endpoint update propagation to running engine
  - EndpointStore.endpointSnapshots: Sendable conversion from SwiftData MockEndpoint to EndpointSnapshot
  - ContentView scenePhase lifecycle: Auto-stop on background, auto-restart on foreground
affects: [03-endpoint-editor-ui, 04-request-log-viewer]

# Tech tracking
tech-stack:
  added: [Network]
  patterns: [port-fallback-loop, scene-phase-lifecycle, cross-actor-callback-setup, weak-capture-task-hop]

key-files:
  created: []
  modified:
    - MockPad/MockPad/App/ServerStore.swift
    - MockPad/MockPad/App/EndpointStore.swift
    - MockPad/MockPad/ContentView.swift
    - MockPad/MockPad/Services/MockServerEngine.swift

key-decisions:
  - "Port fallback tries configured port then +1 through +10 before reporting error"
  - "Engine created fresh for each port attempt (NWListener cannot restart after cancel)"
  - "50ms sleep after start() gives NWListener time to transition to .ready state before isListening check"
  - "setOnRequestLogged setter method added to engine actor for cross-actor callback assignment"
  - "scenePhase .active only auto-starts if autoStart enabled AND server not already running"

patterns-established:
  - "Port fallback loop: iterate basePort...basePort+10 with fresh engine per attempt, stop on first success"
  - "Cross-actor callback: await engine.setOnRequestLogged with [weak endpointStore] + Task { @MainActor in } hop"
  - "scenePhase lifecycle: .background stops server, .active restarts if autoStart enabled"

# Metrics
duration: 2min
completed: 2026-02-16
---

# Phase 2 Plan 3: Server Store Integration Summary

**ServerStore engine lifecycle with port fallback, request log persistence via cross-actor callback, and scenePhase auto-stop/restart for background transitions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-16T22:06:11Z
- **Completed:** 2026-02-16T22:08:05Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- ServerStore bridges MockServerEngine to MainActor UI with startServer/stopServer/updateEngineEndpoints methods and port fallback from configured port through +10
- Request log callback persists engine-side log data to SwiftData via cross-actor Task hop to MainActor, using weak captures to prevent retain cycles
- ContentView observes scenePhase for automatic server lifecycle: stops on background, restarts on foreground return if autoStart enabled
- EndpointStore provides endpointSnapshots computed property converting SwiftData MockEndpoint models to Sendable EndpointSnapshot structs for engine consumption

## Task Commits

Each task was committed atomically:

1. **Task 1: Add endpoint snapshot helper to EndpointStore and wire ServerStore to engine** - `752b996` (feat)
2. **Task 2: Add scenePhase lifecycle and minor app wiring** - `bde07dd` (feat)

## Files Created/Modified
- `MockPad/MockPad/App/ServerStore.swift` - Added engine property, startServer with port fallback, stopServer, updateEngineEndpoints, actualPort tracking, serverURL using actual port
- `MockPad/MockPad/App/EndpointStore.swift` - Added endpointSnapshots computed property for Sendable conversion of MockEndpoint array
- `MockPad/MockPad/ContentView.swift` - Added scenePhase observer with auto-stop on background and auto-restart on foreground
- `MockPad/MockPad/Services/MockServerEngine.swift` - Added setOnRequestLogged setter for cross-actor callback assignment

## Decisions Made
- Port fallback tries configured port then +1 through +10 (11 total attempts) before reporting error message
- Engine is created fresh for each port attempt because NWListener cannot be restarted after cancellation (SR-13918)
- 50ms sleep after start() gives NWListener stateUpdateHandler time to fire and set isListening to true
- Added setOnRequestLogged method to MockServerEngine actor to enable callback setup from MainActor via await (direct property access would violate actor isolation)
- scenePhase .active case checks both autoStart AND !isRunning to prevent double-start

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added setOnRequestLogged setter method to MockServerEngine**
- **Found during:** Task 1 (ServerStore engine wiring)
- **Issue:** Plan assigned onRequestLogged directly on engine actor, but cross-actor property assignment requires actor isolation. Direct assignment from MainActor would cause a concurrency violation.
- **Fix:** Added `func setOnRequestLogged(_ callback:)` method on MockServerEngine actor, called via `await newEngine.setOnRequestLogged { ... }` from ServerStore
- **Files modified:** MockPad/MockPad/Services/MockServerEngine.swift
- **Verification:** Method signature matches actor isolation requirements; await call compiles correctly
- **Committed in:** 752b996 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential fix for Swift concurrency correctness. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete server engine integration from NWListener through ServerStore to SwiftData is operational
- All Phase 2 requirements (SRVR-01 through SRVR-12) are implemented at the engine and store layers
- Phase 3 (Endpoint Editor UI) can add one-tap start/stop button calling serverStore.startServer/stopServer
- Phase 4 (Request Log Viewer) can query RequestLog SwiftData model populated by engine callbacks
- updateEngineEndpoints ready for Phase 3 to call when user edits endpoints while server is running

## Self-Check: PASSED

All 4 modified files verified present on disk. All 2 task commits verified in git log. All key methods (startServer, stopServer, updateEngineEndpoints, endpointSnapshots, scenePhase) verified in source.

---
*Phase: 02-server-engine-core*
*Completed: 2026-02-16*
