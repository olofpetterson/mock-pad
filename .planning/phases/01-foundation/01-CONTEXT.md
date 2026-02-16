# Phase 1: Foundation - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

SwiftData models and stores that provide persistence and state management for all app features. This phase defines MockEndpoint, RequestLog, EndpointStore, ServerStore, and ProManager. No UI screens — only the data layer that every subsequent phase builds on.

</domain>

<decisions>
## Implementation Decisions

### Endpoint model fields
- Response body stored as String (JSON text) — supports JSON, plain text, HTML. No binary response support needed
- HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS (extended set)
- Default new endpoint: status 200, body `{}` (empty JSON object)
- Explicit `sortOrder` Int field for manual drag-to-reorder (supports ENDP-09 in Phase 3)

### Request log model
- Store full request + response bodies, capped at 64KB. Truncate larger bodies with "[truncated]" indicator
- Log entries persist across app launches (SwiftData model stored to disk)
- Query parameters stored as separate structured field ([String: String]) alongside the path
- Auto-prune to 1,000 entries handled by the store (not the model) — store checks count after each insert, deletes oldest

### Server configuration defaults
- Default port: 8080
- CORS: on by default
- Auto-start (restart on foreground): on by default
- Server configuration stored in UserDefaults (not SwiftData) — simple key-value for settings

### PRO limit enforcement
- 3-endpoint limit counts ALL endpoints (enabled + disabled). "You have 3 slots total"
- Offline PRO verification: trust cached purchase state, keep working, re-verify on next launch with network
- PRO purchase state stored in Keychain (survives reinstall, harder to tamper)
- Import at limit: blocked. Can't import if it would exceed 3 total endpoints

### Claude's Discretion
- SwiftData model relationships and cascade rules
- Store method signatures and error handling patterns
- Exact Keychain wrapper implementation for ProManager
- Whether to use @Observable or ObservableObject for stores

</decisions>

<specifics>
## Specific Ideas

- UserDefaults for server config matches the pattern used in DeltaPad and other apps in the ecosystem
- Keychain for PRO state (not UserDefaults) — consistent with security best practices for purchase verification
- sortOrder field future-proofs the model for Phase 3 drag-to-reorder without retrofitting

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-16*
