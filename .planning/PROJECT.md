# MockPad

## What This Is

A native iOS/iPadOS app that runs a local HTTP mock server on-device using Apple's Network framework (`NWListener`). Developers define API endpoints with paths, methods, and JSON responses, tap "Start Server," and get a real HTTP server on localhost. iPad-first design — Split View keeps the server running alongside client apps for live testing.

## Core Value

Developers can start a local mock HTTP server in one tap and test their client app against it immediately — no Docker, no terminal, no backend dependency.

## Requirements

### Validated

- Xcode project scaffold with SwiftUI + SwiftData — existing

### Active

- [ ] NWListener-based local HTTP server with start/stop, port config, CORS, foreground lifecycle
- [ ] Endpoint editor: define mock endpoints with path, method, status code, JSON body, headers, delay
- [ ] Path parameter matching (`:id`), wildcard matching (`*`), method-aware routing (404/405)
- [ ] Response templates: 8 built-in templates + custom templates (PRO)
- [ ] Live request log with real-time streaming, filtering, detail inspection, copy-as-cURL
- [ ] OpenAPI 3.x import: parse JSON/YAML specs, preview endpoints, generate mock responses from schemas (PRO)
- [ ] Export/import endpoint collections as JSON, share via iOS share sheet (PRO)
- [ ] Endpoint collections: organize endpoints into named groups (PRO)
- [ ] iPad NavigationSplitView (3-column) + iPhone TabView with persistent server status
- [ ] PRO paywall: StoreKit 2, $5.99 one-time, free tier = 3 endpoints
- [ ] Settings: port, localhost-only, CORS toggle, auto-start, about, ecosystem links
- [ ] JSON syntax highlighting in response editor
- [ ] Response delay simulation 0-10,000ms (PRO)
- [ ] Empty state with "Create Sample API" quick-start (4 sample endpoints)

### Out of Scope

- HTTPS/TLS support — adds certificate management complexity, defer to v2
- Background server operation — NWListener is foreground-only by iOS design
- HTTP/1.1 keep-alive — close-after-response is sufficient for mock testing
- Real-time WebSocket mocking — HTTP-only for v1
- Cloud sync / account system — local-only app
- DevToolsKit shared package — building standalone, no cross-app dependency
- Localization — English only for v1
- WidgetKit — no widget use case for mock servers

## Context

MockPad is the 5th app in the Pad ecosystem (ProbePad, DeltaPad, GuardPad, BeaconPad). ProbePad sends requests to APIs; MockPad creates the APIs to send requests to. Complementary halves of the same developer workflow.

The PRD is comprehensive and lives at `.planning/mockpad/` with 8 documents covering brand vision, design, UX, interactions, tools/features, technical architecture, and visual design. These are the authoritative reference for implementation details.

Key technical insight: `NWListener` only works while the app is foregrounded. iPad Split View is the primary use case — MockPad on one side, Safari/ProbePad on the other. iPhone support is secondary (server stops when backgrounded).

Existing codebase is a default Xcode template — SwiftUI + SwiftData with placeholder `Item` model. All app code will be built from scratch.

## Constraints

- **Platform**: iOS 26.2+, iPhone and iPad (iPad-first design)
- **Zero dependencies**: No external Swift packages — all functionality built with Apple frameworks
- **Frameworks**: SwiftUI, Network (NWListener), SwiftData, Foundation, StoreKit 2, UniformTypeIdentifiers
- **Build settings**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `PBXFileSystemSynchronizedRootGroup`
- **Accent color**: #7B68EE (Medium Slate Blue) — blueprint/CAD aesthetic
- **Free tier limit**: 3 endpoints
- **PRO price**: $5.99 one-time purchase
- **Brand voice**: Engineering instrument panel — data, not cheerleading. No emojis, no exclamation marks.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Standalone (no DevToolsKit) | Build self-contained, no cross-app package dependency | — Pending |
| 3-endpoint free limit | Covers basic use case (auth + data + error), natural upgrade trigger | — Pending |
| Full PRD scope for v1 | All 6 features including OpenAPI import and export | — Pending |
| HTTP/1.0-style (close after response) | Simplifies connection management, sufficient for mock testing | — Pending |
| Actor for MockServerEngine | Thread-safe NWListener + connection management from multiple queues | — Pending |
| SwiftData for endpoints + logs | Consistent with ecosystem pattern, persistent across sessions | — Pending |
| Minimal YAML parser | Best-effort for OpenAPI YAML; JSON fully supported, YAML is fallback | — Pending |

---
*Last updated: 2026-02-16 after initialization*
