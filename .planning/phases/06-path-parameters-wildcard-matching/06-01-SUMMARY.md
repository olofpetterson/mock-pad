---
phase: 06-path-parameters-wildcard-matching
plan: 01
subsystem: api
tags: [path-matching, url-routing, path-parameters, wildcards, token-substitution, tdd, nonisolated, caseless-enum]

# Dependency graph
requires:
  - phase: 02-server-engine-core
    provides: EndpointMatcher with exact path matching, MatchResult enum, EndpointData tuple typealias
provides:
  - EndpointMatcher.matchPath: segment-based path matching with :param extraction and * wildcards
  - EndpointMatcher.specificity: priority scoring (exact > parameterized > wildcard)
  - MatchResult.matched with pathParams dictionary (7th associated value)
  - PathParamReplacer: {token} substitution in response bodies
  - 31 unit tests (25 EndpointMatcher + 6 PathParamReplacer)
affects: [06-path-parameters-wildcard-matching]

# Tech tracking
tech-stack:
  added: []
  patterns: [segment-based-path-matching, specificity-priority-sorting, token-substitution]

key-files:
  created:
    - MockPad/MockPad/Services/PathParamReplacer.swift
    - MockPad/MockPadTests/PathParamReplacerTests.swift
  modified:
    - MockPad/MockPad/Services/EndpointMatcher.swift
    - MockPad/MockPad/Services/MockServerEngine.swift
    - MockPad/MockPadTests/EndpointMatcherTests.swift

key-decisions:
  - "matchPath uses .split(separator: '/') to normalize leading/trailing slashes consistently"
  - "Wildcard * only valid at end of pattern (no mid-path wildcards)"
  - "Specificity scoring: 0=exact, 1=parameterized, 2=wildcard; stable sort preserves array order within same score"
  - "PathParamReplacer uses simple string replacement loop (no escaping, no JSON awareness)"
  - "MockServerEngine applies token substitution after match, before response build"

patterns-established:
  - "Segment-based path matching: split by '/' then compare segment-by-segment with :param capture and * wildcard"
  - "Priority-based route selection: collect all matches, sort by specificity, first method match wins"
  - "Token substitution: {key} literal replacement in response body with extracted path parameter values"

# Metrics
duration: 2min
completed: 2026-02-17
---

# Phase 6 Plan 1: Path Parameter Matching Summary

**Segment-based path matching with :param extraction, * wildcards, priority-based selection, and {token} response body substitution**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T06:45:42Z
- **Completed:** 2026-02-17T06:48:28Z
- **Tasks:** 2 (TDD RED + GREEN)
- **Files created:** 2
- **Files modified:** 3

## Accomplishments
- EndpointMatcher upgraded from exact-path-only to full routing engine with parameterized paths (/api/users/:id) and wildcards (/api/*)
- Priority-based selection ensures exact > parameterized > wildcard ordering, with first-match-wins within same specificity
- PathParamReplacer service enables {token} substitution in response bodies using extracted path parameter values
- MockServerEngine integration applies token substitution automatically for matched endpoints
- 31 unit tests cover all matching scenarios: exact, parameterized, wildcard, priority, edge cases, and token substitution

## Task Commits

Each task was committed atomically:

1. **Task 1: RED - Write failing tests** - `9877bc4` (test)
2. **Task 2: GREEN - Implement production code** - `91412c9` (feat)

## Files Created/Modified
- `MockPad/MockPad/Services/EndpointMatcher.swift` - Enhanced with matchPath, specificity, pathParams in MatchResult, priority-based match()
- `MockPad/MockPad/Services/PathParamReplacer.swift` - New caseless enum service for {token} substitution in response bodies
- `MockPad/MockPad/Services/MockServerEngine.swift` - Updated .matched destructuring to extract pathParams and apply token substitution
- `MockPad/MockPadTests/EndpointMatcherTests.swift` - 25 tests (9 updated for new arity + 16 new for params/wildcards/priority)
- `MockPad/MockPadTests/PathParamReplacerTests.swift` - 6 tests for token substitution scenarios

## Decisions Made
- matchPath uses .split(separator: "/") to normalize leading/trailing slashes (avoids empty segments from .components(separatedBy:))
- Wildcard * only valid at end of pattern -- no mid-path wildcards (matches MOCKPAD-TECHNICAL.md spec)
- Specificity scoring (0=exact, 1=parameterized, 2=wildcard) with stable sort preserving array order for first-match-wins within same tier
- PathParamReplacer uses simple replacingOccurrences loop -- no JSON awareness, no escaping (matches RESP-09 spec for simple template substitution)
- MockServerEngine applies PathParamReplacer.replace() after matching but before response building, passing resolvedBody to HTTPResponseBuilder

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated MockServerEngine .matched destructuring for new MatchResult arity**
- **Found during:** Task 2 (GREEN - implementation)
- **Issue:** MockServerEngine line 274 destructured MatchResult.matched with 6 values; adding pathParams as 7th would cause compile error
- **Fix:** Updated destructuring to include pathParams, applied PathParamReplacer.replace() to response body before building response
- **Files modified:** MockPad/MockPad/Services/MockServerEngine.swift
- **Verification:** Destructuring matches new 7-value MatchResult.matched signature
- **Committed in:** 91412c9 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential for compilation. The MockServerEngine update was noted in the research as an integration point. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- EndpointMatcher now supports exact, parameterized, and wildcard path matching with priority ordering
- MatchResult carries pathParams dictionary for downstream use (request log display, etc.)
- PathParamReplacer is available for any context needing token substitution
- Plan 06-02 can integrate any remaining pipeline updates (EndpointSnapshot threading, UI for path params display)

## Self-Check: PASSED

All 5 files verified present on disk. All 2 task commits verified in git log.

---
*Phase: 06-path-parameters-wildcard-matching*
*Completed: 2026-02-17*
