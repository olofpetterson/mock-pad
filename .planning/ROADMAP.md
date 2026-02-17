# Roadmap: MockPad

## Overview

MockPad delivers a native iOS local HTTP mock server through 11 phases. We begin with data models and stores, build the NWListener-based HTTP engine core, wire up endpoint editor UI, add request logging, enhance with response templates and path parameters, enable data portability, integrate OpenAPI import, monetize with StoreKit 2, polish navigation and accessibility. Each phase delivers observable user value, with phases 1-4 establishing the core loop (create endpoint, start server, send request, see log) and phases 5-11 adding competitive features.

## Phases

- [ ] **Phase 1: Foundation** - SwiftData models, stores, project structure
- [x] **Phase 2: Server Engine Core** - NWListener, HTTP parsing, basic routing
- [x] **Phase 3: Endpoint Editor UI** - Create/edit/delete endpoints with response config
- [x] **Phase 4: Request Log** - Live streaming, filtering, detail inspection
- [x] **Phase 5: Response Templates + Delay** - Built-in templates, custom templates, delay simulation
- [x] **Phase 6: Path Parameters + Wildcard Matching** - Advanced routing features
- [x] **Phase 7: Import/Export + Collections** - Data portability and organization
- [ ] **Phase 8: OpenAPI Import** - YAML/JSON spec parsing with schema generation
- [ ] **Phase 9: PRO Features** - StoreKit 2, paywall, 3-endpoint limit
- [ ] **Phase 10: Navigation Polish** - iPad/iPhone layouts, empty state
- [ ] **Phase 11: Accessibility** - VoiceOver, Dynamic Type, Reduce Motion

## Phase Details

### Phase 1: Foundation
**Goal**: SwiftData models and stores provide persistence and state management for all app features
**Depends on**: Nothing (first phase)
**Requirements**: ENDP-01, ENDP-02, ENDP-03, ENDP-11
**Success Criteria** (what must be TRUE):
  1. MockEndpoint model persists path, method, status code, response body, headers, and enabled state
  2. EndpointStore provides create, read, update, delete operations for endpoints
  3. ServerStore maintains server running state and configuration (port, CORS toggle, auto-start)
  4. ProManager tracks PRO purchase status and enforces 3-endpoint free tier limit
  5. RequestLog model persists timestamp, method, path, status code, response time, headers, body
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md -- SwiftData models (MockEndpoint, RequestLog), HTTPMethod constants, ServerConfiguration, KeychainService, model unit tests
- [ ] 01-02-PLAN.md -- EndpointStore, ServerStore, ProManager stores, app entry point wiring, store unit tests

### Phase 2: Server Engine Core
**Goal**: Local HTTP server runs on localhost, handles requests, matches endpoints, returns responses
**Depends on**: Phase 1
**Requirements**: SRVR-01, SRVR-02, SRVR-03, SRVR-04, SRVR-05, SRVR-06, SRVR-07, SRVR-08, SRVR-09, SRVR-10, SRVR-11, SRVR-12
**Success Criteria** (what must be TRUE):
  1. User can start server with one tap and see running status with localhost URL
  2. User can stop server with one tap and see stopped status
  3. Server handles GET requests to defined endpoints and returns configured JSON responses
  4. Server handles POST/PUT/DELETE requests with method-aware routing
  5. Server returns 404 JSON error for unmatched paths and 405 with Allow header for unmatched methods
  6. Server auto-stops when app backgrounds and auto-restarts when foregrounded (if auto-start enabled)
  7. Server handles CORS preflight OPTIONS requests automatically with 204 response
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md -- TDD pure HTTP services (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher) with ~37 unit tests
- [x] 02-02-PLAN.md -- MockServerEngine actor with NWListener, connection management, Sendable DTOs
- [x] 02-03-PLAN.md -- ServerStore engine integration, port fallback, scenePhase lifecycle (auto-stop/restart)

### Phase 3: Endpoint Editor UI
**Goal**: User can create, edit, delete, and configure mock endpoints through SwiftUI interface
**Depends on**: Phase 2
**Requirements**: RESP-01, RESP-02, RESP-03, RESP-04, RESP-05, ENDP-04, ENDP-05, ENDP-09
**Success Criteria** (what must be TRUE):
  1. User can create new endpoint with path, HTTP method selection, status code, response body
  2. User can edit existing endpoint and changes are saved immediately
  3. User can delete endpoint from list view
  4. User can enable/disable individual endpoints via toggle without deleting
  5. User can duplicate endpoint to create copy with same configuration
  6. User can add custom response headers as key-value pairs
  7. User can edit JSON response body with validation indicator showing valid/invalid state
  8. User can reorder endpoints via drag handles in list view
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md -- Design tokens (MockPadColors, MockPadTypography, MockPadMetrics) + EndpointListView with delete, toggle, duplicate, reorder
- [x] 03-02-PLAN.md -- EndpointEditorView, AddEndpointSheet, StatusCodePickerView, HTTPMethodPickerView
- [x] 03-03-PLAN.md -- ResponseBodyEditorView with JSON validation/pretty-print + ResponseHeadersEditorView

### Phase 4: Request Log
**Goal**: User can observe incoming requests in real time and inspect full request/response details
**Depends on**: Phase 2
**Requirements**: RLOG-01, RLOG-02, RLOG-03, RLOG-04, RLOG-05, RLOG-06, RLOG-07, RLOG-08, RLOG-09, RLOG-10
**Success Criteria** (what must be TRUE):
  1. User sees new log entries appear in real time as server receives requests
  2. Each log entry shows timestamp, HTTP method badge, path, status code, response time
  3. User can tap log entry to see full request details (headers, body, query parameters)
  4. User can tap log entry to see response details (matched endpoint, response headers, body, timing)
  5. User can filter log by HTTP method (GET/POST/PUT/DELETE) using chips
  6. User can filter log by status category (2xx/4xx/5xx) using chips
  7. User can search log entries by path substring
  8. User can clear entire request log with one button
  9. User can copy logged request as cURL command to clipboard
  10. Log auto-prunes to 1,000 entries maximum (oldest entries removed)
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md -- Model additions (responseHeaders, matchedEndpointPath), CurlGenerator TDD, EndpointStore.clearLog()
- [x] 04-02-PLAN.md -- RequestLogListView with @Query real-time updates, filter chips, search, clear, navigation wiring
- [x] 04-03-PLAN.md -- RequestDetailView with request/response inspection, cURL copy to clipboard

### Phase 5: Response Templates + Delay
**Goal**: User can select from built-in templates, save custom templates, and simulate response delays
**Depends on**: Phase 3
**Requirements**: RESP-06, RESP-07, RESP-08
**Success Criteria** (what must be TRUE):
  1. User can select from 8 built-in response templates (Success, User Object, User List, Not Found, Unauthorized, Validation Error, Server Error, Rate Limited)
  2. User can apply template to populate endpoint response body and status code
  3. User can save custom response template from current endpoint configuration (PRO)
  4. User can set response delay 0-10,000ms per endpoint (PRO)
  5. Server waits specified delay before sending response (verified in request log timing)
**Plans**: 3 plans

Plans:
- [x] 05-01-PLAN.md -- Data layer: MockEndpoint.responseDelayMs, EndpointSnapshot.responseDelayMs, ResponseTemplate @Model, BuiltInTemplates (8 static templates), ModelContainer registration
- [x] 05-02-PLAN.md -- Template picker + delay UI: TemplatePickerView, SaveTemplateSheet, EndpointEditorView template/delay sections
- [x] 05-03-PLAN.md -- Server engine delay: EndpointMatcher delay data flow, Task.sleep in MockServerEngine before response send

### Phase 6: Path Parameters + Wildcard Matching
**Goal**: Server supports dynamic path parameters and wildcard paths with token substitution in responses
**Depends on**: Phase 2
**Requirements**: ENDP-06, ENDP-07, ENDP-08, RESP-09
**Success Criteria** (what must be TRUE):
  1. User can define path parameter using :param syntax (e.g., /api/users/:id)
  2. Server extracts path parameter values from incoming requests
  3. Path parameter tokens in response body ({id}, {userId}) are replaced with actual values
  4. User can define wildcard path using * (e.g., /api/*) that matches any sub-path
  5. Endpoint matcher prioritizes exact matches over path params over wildcards
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md -- TDD: Enhanced EndpointMatcher with matchPath (param + wildcard), priority selection, PathParamReplacer token substitution, ~24+ tests
- [x] 06-02-PLAN.md -- MockServerEngine integration: pathParams extraction + PathParamReplacer.replace in response pipeline

### Phase 7: Import/Export + Collections
**Goal**: User can organize endpoints into collections, export as JSON, import from JSON, and share via iOS share sheet
**Depends on**: Phase 1
**Requirements**: ENDP-10, EXPT-01, EXPT-02, EXPT-03, EXPT-04
**Success Criteria** (what must be TRUE):
  1. User can create named endpoint collections (PRO)
  2. User can assign endpoints to collections from editor (PRO)
  3. User can filter endpoint list by collection (PRO)
  4. User can export endpoint collection as JSON file (PRO)
  5. User can import endpoint collection from MockPad JSON file
  6. User can share exported JSON file via iOS share sheet (AirDrop, Files, Messages)
  7. Import handles duplicate endpoints with user choice (skip, replace, import as new)
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md -- TDD: MockEndpoint.collectionName, Codable export models, CollectionExporter + CollectionImporter services, MockPadDocument, MockPadExportFile, 13 unit tests
- [x] 07-02-PLAN.md -- Collection UI: CollectionFilterChipsView, EndpointListView collection filtering, EndpointEditorView collection assignment (PRO)
- [x] 07-03-PLAN.md -- Import/Export/Share UI: fileExporter, fileImporter, ShareLink, ImportPreviewSheet with duplicate resolution

### Phase 8: OpenAPI Import
**Goal**: User can import OpenAPI 3.x specs from JSON/YAML files and generate mock endpoints with schema-based responses
**Depends on**: Phase 1
**Requirements**: IMPT-01, IMPT-02, IMPT-03, IMPT-04, IMPT-05, IMPT-06
**Success Criteria** (what must be TRUE):
  1. User can select OpenAPI JSON file from Files app and parse spec (PRO)
  2. User can select OpenAPI YAML file from Files app and parse spec via Yams (PRO)
  3. User sees preview of discovered endpoints with select/deselect checkboxes before import
  4. Imported endpoints generate mock response bodies from schema examples or type-based generation
  5. OpenAPI path parameters ({id}) are converted to MockPad format (:id) automatically
  6. User sees warnings for unsupported OpenAPI features (allOf/oneOf, webhooks) during preview
**Plans**: 3 plans

Plans:
- [ ] 08-01-PLAN.md -- TDD YAMLConverter: minimal YAML-to-JSON converter for OpenAPI YAML subset (~15 tests)
- [ ] 08-02-PLAN.md -- TDD OpenAPIParser + MockResponseGenerator: spec parsing, $ref resolution, mock response generation (~34 tests)
- [ ] 08-03-PLAN.md -- OpenAPIPreviewSheet UI + EndpointListView Import OpenAPI menu integration

### Phase 9: PRO Features
**Goal**: StoreKit 2 integration enforces 3-endpoint free tier and unlocks PRO features with $5.99 purchase
**Depends on**: Phase 1
**Requirements**: PRO-01, PRO-02, PRO-03, PRO-04, PRO-05
**Success Criteria** (what must be TRUE):
  1. Free tier allows 3 endpoints - adding 4th endpoint triggers PRO paywall
  2. PRO paywall shows feature list (unlimited endpoints, OpenAPI import, custom templates, collections, response delay, export/share)
  3. PRO paywall shows $5.99 one-time purchase price with "No subscription" messaging
  4. User can purchase PRO via StoreKit 2 and immediately unlock all PRO features
  5. User can restore previous PRO purchase on new device
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 10: Navigation Polish
**Goal**: iPad uses 3-column NavigationSplitView, iPhone uses TabView, empty state provides quick-start flow
**Depends on**: Phase 3, Phase 4
**Requirements**: NAVI-01, NAVI-02, NAVI-03, NAVI-04
**Success Criteria** (what must be TRUE):
  1. iPad uses NavigationSplitView with 3 columns (sidebar: server + endpoints, content: editor/log, detail: request inspector)
  2. iPhone uses TabView with 3 tabs (Endpoints, Log, Settings) and persistent server status bar
  3. Empty state shows "Create Sample API" button that generates 4 sample CRUD endpoints and auto-starts server
  4. Settings screen includes port config, localhost-only toggle, CORS toggle, auto-start toggle, clear log, import/export, about, ecosystem links
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 11: Accessibility
**Goal**: All interactive elements are accessible via VoiceOver, text scales with Dynamic Type, animations respect Reduce Motion
**Depends on**: Phase 3, Phase 4
**Requirements**: ACCS-01, ACCS-02, ACCS-03, ACCS-04, ACCS-05
**Success Criteria** (what must be TRUE):
  1. All badges, toggles, buttons have descriptive VoiceOver labels
  2. All text content scales correctly with Dynamic Type at largest size
  3. All animations respect Reduce Motion accessibility preference
  4. HTTP method badges use distinct colors with different luminance for color blindness accessibility
  5. All tap targets meet 44pt minimum size
**Plans**: TBD

Plans:
- [ ] TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | ✓ Complete | 2026-02-16 |
| 2. Server Engine Core | 3/3 | ✓ Complete | 2026-02-16 |
| 3. Endpoint Editor UI | 3/3 | ✓ Complete | 2026-02-16 |
| 4. Request Log | 3/3 | ✓ Complete | 2026-02-16 |
| 5. Response Templates + Delay | 3/3 | ✓ Complete | 2026-02-17 |
| 6. Path Parameters + Wildcard Matching | 2/2 | ✓ Complete | 2026-02-17 |
| 7. Import/Export + Collections | 3/3 | ✓ Complete | 2026-02-17 |
| 8. OpenAPI Import | 0/3 | Not started | - |
| 9. PRO Features | 0/TBD | Not started | - |
| 10. Navigation Polish | 0/TBD | Not started | - |
| 11. Accessibility | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-16*
