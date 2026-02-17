---
phase: 05-response-templates-delay
plan: 01
subsystem: models
tags: [swiftdata, response-templates, delay, dto]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: MockEndpoint @Model, EndpointSnapshot DTO, EndpointStore, ModelContainer setup
provides:
  - ResponseTemplate @Model for custom response templates
  - responseDelayMs field in MockEndpoint -> EndpointSnapshot data pipeline
  - 8 built-in response templates as static data (BuiltInTemplates)
affects: [05-02-PLAN (template picker UI), 05-03-PLAN (server engine delay)]

# Tech tracking
tech-stack:
  added: []
  patterns: [caseless enum as template namespace, Sendable/Identifiable inner struct for static data]

key-files:
  created:
    - MockPad/MockPad/Models/ResponseTemplate.swift
    - MockPad/MockPad/Services/BuiltInTemplates.swift
  modified:
    - MockPad/MockPad/Models/MockEndpoint.swift
    - MockPad/MockPad/Services/EndpointSnapshot.swift
    - MockPad/MockPad/App/EndpointStore.swift
    - MockPad/MockPad/MockPadApp.swift

key-decisions:
  - "responseDelayMs default 0 ensures lightweight migration safety for existing MockEndpoint records"
  - "BuiltInTemplates uses caseless enum pattern (matches HTTPMethod, EndpointMatcher convention)"
  - "JSON bodies in templates use sorted keys with 2-space indentation matching JSONSerialization convention"

patterns-established:
  - "Inner Sendable/Identifiable struct inside caseless enum for typed static template collections"
  - "Named static properties composed into static let all array for both direct and iterable access"

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 5 Plan 1: Response Templates and Delay Data Layer Summary

**ResponseTemplate SwiftData model, responseDelayMs data pipeline field, and 8 built-in response templates as static BuiltInTemplates definitions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T05:49:28Z
- **Completed:** 2026-02-17T05:51:13Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added responseDelayMs Int field (default 0) to MockEndpoint with lightweight migration safety, carried through EndpointSnapshot DTO and EndpointStore mapping
- Created ResponseTemplate @Model with name, statusCode, responseBody, responseHeadersData, createdAt fields and computed responseHeaders accessor
- Defined 8 built-in response templates (Success, User Object, User List, Not Found, Unauthorized, Validation Error, Server Error, Rate Limited) with sorted-key JSON bodies, SF Symbol icons, and appropriate headers
- Registered ResponseTemplate.self in ModelContainer

## Task Commits

Each task was committed atomically:

1. **Task 1: Add responseDelayMs to data pipeline and ResponseTemplate model** - `680268f` (feat)
2. **Task 2: Create BuiltInTemplates with 8 template definitions** - `6d44c79` (feat)

## Files Created/Modified
- `MockPad/MockPad/Models/MockEndpoint.swift` - Added responseDelayMs stored property with default 0 and init parameter
- `MockPad/MockPad/Models/ResponseTemplate.swift` - New SwiftData @Model for custom response templates
- `MockPad/MockPad/Services/EndpointSnapshot.swift` - Added responseDelayMs field to Sendable DTO
- `MockPad/MockPad/App/EndpointStore.swift` - Maps responseDelayMs through endpointSnapshots computed property
- `MockPad/MockPad/MockPadApp.swift` - Registers ResponseTemplate.self in ModelContainer
- `MockPad/MockPad/Services/BuiltInTemplates.swift` - Caseless enum with 8 static template definitions

## Decisions Made
- responseDelayMs default 0 ensures lightweight migration safety for existing MockEndpoint records
- BuiltInTemplates uses caseless enum pattern (matches HTTPMethod, EndpointMatcher convention in codebase)
- JSON bodies in templates use sorted keys with space-colon-space separator matching JSONSerialization .sortedKeys convention

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ResponseTemplate model ready for template picker UI (Plan 05-02)
- BuiltInTemplates.all provides iterable template list for picker
- responseDelayMs pipeline ready for server engine delay implementation (Plan 05-03)

## Self-Check: PASSED

All 7 files verified present. Both task commits (680268f, 6d44c79) confirmed in git log.

---
*Plan: 05-01*
*Completed: 2026-02-17*
