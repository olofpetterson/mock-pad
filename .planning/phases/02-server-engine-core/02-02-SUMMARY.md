---
phase: 02-server-engine-core
plan: 02
subsystem: api
tags: [nwlistener, tcp-server, actor, sendable-dto, cors, connection-management, http-lifecycle]

# Dependency graph
requires:
  - phase: 02-server-engine-core
    plan: 01
    provides: HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher pure services
  - phase: 01-foundation
    provides: HTTPMethod constants, MockEndpoint model structure
provides:
  - MockServerEngine: actor wrapping NWListener with complete HTTP request/response cycle
  - EndpointSnapshot: Sendable DTO for passing endpoint config from MainActor to engine actor
  - RequestLogData: Sendable DTO for passing log data from engine actor to MainActor
  - MockServerError: error enum for server failure cases
affects: [02-server-engine-core, 03-server-store-integration]

# Tech tracking
tech-stack:
  added: [Network]
  patterns: [actor-with-nwlistener, weak-self-task-bridging, objectidentifier-dictionary-key, sendable-dto-cross-actor, close-after-response-http10]

key-files:
  created:
    - MockPad/MockPad/Services/MockServerEngine.swift
    - MockPad/MockPad/Services/EndpointSnapshot.swift
    - MockPad/MockPad/Services/RequestLogData.swift
    - MockPad/MockPad/Services/MockServerError.swift
  modified: []

key-decisions:
  - "EndpointSnapshot struct carries endpoint config across actor boundary instead of passing MainActor-bound MockEndpoint"
  - "MockServerEngine uses ObjectIdentifier as dictionary key for NWConnection tracking (NWConnection is not Hashable)"
  - "All NWListener/NWConnection callbacks use [weak self] + Task bridging to prevent retain cycles and concurrency violations"
  - "503 Service Unavailable returned when connection limit (50) exceeded, not silently dropped"
  - "HTTP/1.0 close-after-response pattern: connection cancelled after every response send"

patterns-established:
  - "Actor-to-callback bridging: NWListener DispatchQueue callbacks wrapped in Task { [weak self] in await self?.method() }"
  - "Sendable DTO pattern: EndpointSnapshot and RequestLogData carry data across actor boundaries safely"
  - "Connection lifecycle: ObjectIdentifier(connection) as key, stateUpdateHandler for cleanup, cancel after send"
  - "Error response consistency: all error responses (400, 404, 405, 503) include CORS headers and JSON body"

# Metrics
duration: 2min
completed: 2026-02-16
---

# Phase 2 Plan 2: MockServerEngine Summary

**MockServerEngine actor wrapping NWListener with TCP connection management, HTTP request/response cycle via three pure services, CORS support, 50-connection limit, and Sendable DTO cross-actor communication**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-16T22:01:10Z
- **Completed:** 2026-02-16T22:03:22Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments
- MockServerEngine actor manages NWListener lifecycle with proper create-new-on-each-start pattern (SR-13918 compliance)
- Engine wires three pure HTTP services (parser, matcher, builder) for complete request/response cycle: receive -> parse -> match -> build -> send -> close
- Three Sendable DTOs enable safe cross-actor communication: EndpointSnapshot (MainActor->engine), RequestLogData (engine->MainActor), MockServerError (error reporting)
- Error responses cover all cases: 400 (malformed/empty), 404 (not found with JSON path), 405 (method not allowed with Allow header), 503 (connection limit exceeded)
- CORS headers included on all responses (matched, error, preflight) when enabled; OPTIONS preflight returns 204 with Access-Control-Max-Age

## Task Commits

Each task was committed atomically:

1. **Task 1: Create supporting Sendable DTOs and error types** - `2a903e9` (feat)
2. **Task 2: Build MockServerEngine actor** - `72aa45d` (feat)

## Files Created/Modified
- `MockPad/MockPad/Services/MockServerEngine.swift` - Actor wrapping NWListener with HTTP request/response cycle, connection management, and Sendable callback logging
- `MockPad/MockPad/Services/EndpointSnapshot.swift` - Sendable DTO carrying endpoint config from MainActor to engine actor
- `MockPad/MockPad/Services/RequestLogData.swift` - Sendable DTO carrying log data from engine actor to MainActor for SwiftData persistence
- `MockPad/MockPad/Services/MockServerError.swift` - Error enum with invalidPort, portInUse, listenerFailed, alreadyRunning, tooManyConnections cases

## Decisions Made
- EndpointSnapshot struct carries endpoint config across actor boundary instead of passing MainActor-bound MockEndpoint (SwiftData @Model cannot cross actor boundaries)
- MockServerEngine uses ObjectIdentifier as dictionary key for NWConnection tracking since NWConnection is not Hashable
- All NWListener/NWConnection callbacks use [weak self] + Task bridging to prevent retain cycles and Swift 6 concurrency violations
- 503 Service Unavailable returned when connection limit exceeded rather than silently dropping the connection
- HTTP/1.0 close-after-response pattern: connection cancelled immediately after response send completion

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MockServerEngine actor is ready for ServerStore integration (Plan 03) to bridge engine to MainActor UI
- EndpointSnapshot struct established for ServerStore to convert MockEndpoint -> EndpointSnapshot before passing to engine
- RequestLogData struct established for engine -> EndpointStore.addLogEntry() logging flow
- onRequestLogged callback ready for ServerStore to wire up for request log persistence
- updateEndpoints() method ready for live endpoint updates while server is running

## Self-Check: PASSED

All 4 created files verified present on disk. All 2 task commits verified in git log.

---
*Phase: 02-server-engine-core*
*Completed: 2026-02-16*
