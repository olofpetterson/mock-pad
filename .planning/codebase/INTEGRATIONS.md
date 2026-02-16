# External Integrations

**Analysis Date:** 2026-02-16

## APIs & External Services

**AI Tooling (development only):**
- Anthropic Claude Code - AI coding agent used during development, not part of the app itself
  - SDK/Client: `@anthropic-ai/claude-code` (npm, global)
  - Auth: `ANTHROPIC_API_KEY` environment variable OR `~/.claude` credentials directory

**App has no external API integrations at this time.** The codebase is a freshly scaffolded iOS app with only SwiftData persistence.

## Data Storage

**Databases:**
- SwiftData (on-device SQLite) - Primary persistence
  - Connection: Local device storage, no connection string
  - Client: SwiftData `ModelContainer` / `ModelContext`
  - Schema: Single `Item` model with `timestamp: Date` field (`MockPad/MockPad/Item.swift`)
  - Configuration: `isStoredInMemoryOnly: false` (persists to disk) in `MockPad/MockPad/MockPadApp.swift`

**File Storage:**
- Local filesystem only (iOS app sandbox)

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- None — no authentication in the app

## Monitoring & Observability

**Error Tracking:**
- None

**Logs:**
- None (no logging framework configured)

## CI/CD & Deployment

**Hosting:**
- iOS App Store (target: `com.olof.petterson.MockPad`)
- Development sandbox: Docker container running Claude Code (`docker-compose.yml`)

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- `ANTHROPIC_API_KEY` - Only for running the Claude Code development sandbox, not for the iOS app itself

**Secrets location:**
- `~/.claude` - Claude credentials volume-mounted from host into Docker container

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-02-16*
