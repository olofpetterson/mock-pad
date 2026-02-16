# Requirements: MockPad

**Defined:** 2026-02-16
**Core Value:** Developers can start a local mock HTTP server in one tap and test their client app against it immediately

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Server Engine

- [ ] **SRVR-01**: User can start a local HTTP server on localhost with one tap
- [ ] **SRVR-02**: User can stop the server and see clear running/stopped status
- [ ] **SRVR-03**: User can see and copy the server URL (e.g., http://localhost:8080)
- [ ] **SRVR-04**: Server auto-stops when app enters background (iOS foreground constraint)
- [ ] **SRVR-05**: Server auto-restarts when app returns to foreground (if auto-start enabled)
- [ ] **SRVR-06**: Server falls back to next available port if configured port is in use (8081-8090)
- [ ] **SRVR-07**: Server responds with CORS headers by default (configurable toggle)
- [ ] **SRVR-08**: Server handles OPTIONS preflight requests automatically with 204
- [ ] **SRVR-09**: Server returns 404 JSON error for unmatched paths
- [ ] **SRVR-10**: Server returns 405 with Allow header for unmatched methods on matched paths
- [ ] **SRVR-11**: Server returns 400 for malformed HTTP requests
- [ ] **SRVR-12**: Server enforces 50 concurrent connection limit and 64KB request size limit

### Endpoint Management

- [ ] **ENDP-01**: User can create a mock endpoint with path, HTTP method, status code, response body, and response headers
- [ ] **ENDP-02**: User can edit an existing endpoint's configuration
- [ ] **ENDP-03**: User can delete an endpoint
- [ ] **ENDP-04**: User can enable/disable individual endpoints without deleting
- [ ] **ENDP-05**: User can duplicate an endpoint (creates copy with same fields)
- [ ] **ENDP-06**: User can define path parameters using `:param` syntax (e.g., /api/users/:id)
- [ ] **ENDP-07**: Server extracts path parameter values and makes them available for response templating
- [ ] **ENDP-08**: User can define wildcard paths using `*` (e.g., /api/* matches any sub-path)
- [ ] **ENDP-09**: User can reorder endpoints via drag handles
- [ ] **ENDP-10**: User can organize endpoints into named collections (PRO)
- [ ] **ENDP-11**: Endpoint list shows method badge (colored), path, status code, and enabled state

### Response Configuration

- [ ] **RESP-01**: User can set response status code via quick-select chips (200, 201, 204, 400, 401, 403, 404, 500) or custom input
- [ ] **RESP-02**: User can edit response body as JSON with syntax highlighting
- [ ] **RESP-03**: User can format/pretty-print JSON in the response editor
- [ ] **RESP-04**: User can see JSON validation indicator (valid/invalid)
- [ ] **RESP-05**: User can add custom response headers as key-value pairs
- [ ] **RESP-06**: User can set response delay 0-10,000ms per endpoint (PRO)
- [ ] **RESP-07**: User can select from 8 built-in response templates (Success, User Object, User List, Not Found, Unauthorized, Validation Error, Server Error, Rate Limited)
- [ ] **RESP-08**: User can save custom response templates from endpoint configuration (PRO)
- [ ] **RESP-09**: Path parameter tokens ({id}, {userId}) in response body are auto-replaced with actual values

### Request Log

- [ ] **RLOG-01**: User can see incoming requests in real time as they arrive (live streaming)
- [ ] **RLOG-02**: Each log entry shows timestamp, HTTP method badge, path, response status code, and response time
- [ ] **RLOG-03**: User can tap a log entry to see full request details (headers, body, query parameters)
- [ ] **RLOG-04**: User can see response details (matched endpoint, response headers, body, timing)
- [ ] **RLOG-05**: User can filter log by HTTP method (GET/POST/PUT/DELETE)
- [ ] **RLOG-06**: User can filter log by response status category (2xx/4xx/5xx)
- [ ] **RLOG-07**: User can search log entries by path substring
- [ ] **RLOG-08**: User can clear the request log
- [ ] **RLOG-09**: User can copy a logged request as cURL command
- [ ] **RLOG-10**: Log auto-prunes to 1,000 entries maximum

### Import & Export

- [ ] **IMPT-01**: User can import an OpenAPI 3.x spec from JSON file (PRO)
- [ ] **IMPT-02**: User can import an OpenAPI 3.x spec from YAML file via Yams parser (PRO)
- [ ] **IMPT-03**: User can preview discovered endpoints before importing (select/deselect individual endpoints)
- [ ] **IMPT-04**: Imported endpoints generate mock response bodies from schema examples or type-based generation
- [ ] **IMPT-05**: OpenAPI path parameters ({id}) are converted to MockPad format (:id)
- [ ] **IMPT-06**: User sees clear warnings for unsupported OpenAPI features (allOf/oneOf, webhooks, etc.)
- [ ] **EXPT-01**: User can export an endpoint collection as JSON file (PRO)
- [ ] **EXPT-02**: User can import endpoint collections from MockPad JSON files
- [ ] **EXPT-03**: User can share exported files via iOS share sheet (AirDrop, Files, Messages, etc.)
- [ ] **EXPT-04**: Import handles duplicate endpoints (skip, replace, or import as new)

### PRO & Monetization

- [ ] **PRO-01**: Free tier allows 3 endpoints; adding more triggers PRO paywall
- [ ] **PRO-02**: PRO unlocks unlimited endpoints, OpenAPI import, custom templates, collections, response delay, export/share
- [ ] **PRO-03**: Paywall shows feature list, $5.99 one-time purchase price, "No subscription" messaging
- [ ] **PRO-04**: User can restore previous purchase
- [ ] **PRO-05**: StoreKit 2 integration for purchase flow

### Navigation & UI

- [ ] **NAVI-01**: iPad uses NavigationSplitView with 3 columns (sidebar: server + endpoints, content: editor/log, detail: request inspector)
- [ ] **NAVI-02**: iPhone uses TabView with 3 tabs (Endpoints, Log, Settings) and persistent server status bar
- [ ] **NAVI-03**: Empty state shows "Create Sample API" button that generates 4 sample CRUD endpoints and auto-starts server
- [ ] **NAVI-04**: Settings screen includes: port config, localhost-only toggle, CORS toggle, auto-start toggle, clear log, import/export, about, ecosystem links

### Accessibility

- [ ] **ACCS-01**: All badges, toggles, and interactive elements have VoiceOver labels
- [ ] **ACCS-02**: All text scales with Dynamic Type
- [ ] **ACCS-03**: Animations respect Reduce Motion preference
- [ ] **ACCS-04**: Method badges use distinct colors with different luminance for color blindness
- [ ] **ACCS-05**: All tap targets meet 44pt minimum

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Mocking

- **ADVN-01**: Dynamic response templating (Handlebars-style variable substitution)
- **ADVN-02**: Stateful mock scenarios (state machine for multi-step flows)
- **ADVN-03**: Record & playback (proxy to real API, capture responses)
- **ADVN-04**: Request body matching (route based on POST body content)

### Protocol Support

- **PROT-01**: HTTPS/TLS support with certificate management
- **PROT-02**: WebSocket mocking
- **PROT-03**: GraphQL-aware mocking (schema-based query matching)

### Ecosystem

- **ECOS-01**: Bonjour/mDNS service advertisement for local network discovery
- **ECOS-02**: ProbePad collection import (auto-generate endpoints from ProbePad requests)
- **ECOS-03**: Localization (Japanese, German, Chinese Simplified, Korean)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Background server operation | NWListener is foreground-only by iOS design — fundamental platform constraint |
| Cloud sync / accounts | Requires backend infrastructure, conflicts with local-only value proposition |
| CI/CD headless mode | MockPad is a GUI development tool, not CI infrastructure |
| HTTP/1.1 keep-alive | Close-after-response is sufficient for mock testing, avoids connection pool complexity |
| Request validation against schema | Mock servers should be permissive, not strict validators |
| DevToolsKit shared package | Building standalone for v1, no cross-app dependency |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SRVR-01 | — | Pending |
| SRVR-02 | — | Pending |
| SRVR-03 | — | Pending |
| SRVR-04 | — | Pending |
| SRVR-05 | — | Pending |
| SRVR-06 | — | Pending |
| SRVR-07 | — | Pending |
| SRVR-08 | — | Pending |
| SRVR-09 | — | Pending |
| SRVR-10 | — | Pending |
| SRVR-11 | — | Pending |
| SRVR-12 | — | Pending |
| ENDP-01 | — | Pending |
| ENDP-02 | — | Pending |
| ENDP-03 | — | Pending |
| ENDP-04 | — | Pending |
| ENDP-05 | — | Pending |
| ENDP-06 | — | Pending |
| ENDP-07 | — | Pending |
| ENDP-08 | — | Pending |
| ENDP-09 | — | Pending |
| ENDP-10 | — | Pending |
| ENDP-11 | — | Pending |
| RESP-01 | — | Pending |
| RESP-02 | — | Pending |
| RESP-03 | — | Pending |
| RESP-04 | — | Pending |
| RESP-05 | — | Pending |
| RESP-06 | — | Pending |
| RESP-07 | — | Pending |
| RESP-08 | — | Pending |
| RESP-09 | — | Pending |
| RLOG-01 | — | Pending |
| RLOG-02 | — | Pending |
| RLOG-03 | — | Pending |
| RLOG-04 | — | Pending |
| RLOG-05 | — | Pending |
| RLOG-06 | — | Pending |
| RLOG-07 | — | Pending |
| RLOG-08 | — | Pending |
| RLOG-09 | — | Pending |
| RLOG-10 | — | Pending |
| IMPT-01 | — | Pending |
| IMPT-02 | — | Pending |
| IMPT-03 | — | Pending |
| IMPT-04 | — | Pending |
| IMPT-05 | — | Pending |
| IMPT-06 | — | Pending |
| EXPT-01 | — | Pending |
| EXPT-02 | — | Pending |
| EXPT-03 | — | Pending |
| EXPT-04 | — | Pending |
| PRO-01 | — | Pending |
| PRO-02 | — | Pending |
| PRO-03 | — | Pending |
| PRO-04 | — | Pending |
| PRO-05 | — | Pending |
| NAVI-01 | — | Pending |
| NAVI-02 | — | Pending |
| NAVI-03 | — | Pending |
| NAVI-04 | — | Pending |
| ACCS-01 | — | Pending |
| ACCS-02 | — | Pending |
| ACCS-03 | — | Pending |
| ACCS-04 | — | Pending |
| ACCS-05 | — | Pending |

**Coverage:**
- v1 requirements: 56 total
- Mapped to phases: 0
- Unmapped: 56

---
*Requirements defined: 2026-02-16*
*Last updated: 2026-02-16 after initial definition*
