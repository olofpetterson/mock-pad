# Feature Research

**Domain:** iOS-native mock HTTP server app
**Researched:** 2026-02-16
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Endpoint CRUD (path, method, status, body, headers) | Every mock server tool provides this. It's the literal definition of the product. | MEDIUM | Core data model: Endpoint entity with path, HTTP method, status code, response body (JSON/text), custom headers. SwiftData model. |
| Multiple HTTP methods per path | Postman, WireMock, Mockoon all support GET/POST/PUT/PATCH/DELETE/OPTIONS on the same path. Developers expect REST semantics. | LOW | Method is part of the matching tuple (path + method). |
| JSON response body editor | JSON is the dominant response format. Every competitor has a JSON editor. | MEDIUM | Syntax-highlighted text editor. Consider a basic JSON validator (flag malformed JSON before serving it). |
| Custom response headers | All competitors support custom response headers (Content-Type, Cache-Control, auth headers, etc.). | LOW | Array of key-value pairs per endpoint. Default Content-Type: application/json. |
| HTTP status code selection | Every tool lets you pick the status code (200, 201, 400, 404, 500, etc.). | LOW | Picker with common codes + freeform entry. Group by category (2xx, 3xx, 4xx, 5xx). |
| Response delay simulation | WireMock, Mockoon, MockServer, Postman all support fixed delays. Developers need to test loading states and timeout handling. | LOW | Simple fixed delay (milliseconds) per endpoint. Implemented via Task.sleep before responding. |
| Live request log | Mockoon, MockServer, and Postman all show incoming requests. Without this, developers can't verify their client is hitting the mock. | HIGH | Real-time list of received requests showing timestamp, method, path, headers, body. SwiftData or in-memory array. This is the most UI-intensive table-stakes feature. |
| Server start/stop control | Every tool has an explicit on/off toggle. Developers need to control when the server is listening. | LOW | Toggle button. NWListener start/cancel. Show bound port clearly. |
| Localhost binding with visible port | All local mock servers display the URL (e.g., http://localhost:8080). The developer needs to know where to point their client. | LOW | Display URL prominently. Allow port selection. Default to a non-privileged port (e.g., 8080). |
| Export/share endpoint configurations | Mockoon exports to JSON/OpenAPI. Postman uses collections. Developers need to share mocks with teammates. | MEDIUM | Export as JSON file (custom format or OpenAPI v3). Share via iOS share sheet (AirDrop, Files, Messages). |
| Multiple response variants per endpoint | Mockoon and WireMock support multiple responses per route with rules/scenarios to switch between them. Developers test success, error, and edge cases. | MEDIUM | Array of response variants per endpoint. Manual selection or sequential cycling. |
| Path parameters and wildcards | WireMock, Mockoon, Postman all support /users/:id style path params. Real APIs use them universally. | MEDIUM | Support :param syntax in path definitions. Match incoming requests with path extraction. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| iPad Split View (mock server + client app side by side) | No desktop mock server can do this. This is THE killer use case for an iOS-native mock server -- run MockPad in one pane, your app-under-test in the other. Zero competitors offer this. | LOW | SwiftUI adaptive layout. Works automatically if the app supports multitasking (which SwiftUI apps do by default on iPad). Promote this heavily in marketing. |
| Zero-setup on-device mock server | Desktop tools (Mockoon, WireMock) require a Mac/PC. Postman requires cloud. MockPad runs on the same device or same network as the app being tested. No Docker, no Node.js, no terminal. | LOW | This is inherent to the product concept itself. The differentiation is the platform, not a feature to build. |
| OpenAPI v3 import | Prism, Mockoon, MockServer all support OpenAPI import, but no iOS app does. Import a spec and get pre-configured endpoints instantly. Saves massive setup time. | HIGH | Parse OpenAPI v3 JSON/YAML. Extract paths, methods, response schemas, examples. Generate Endpoint entities. Consider Codable models for OpenAPI schema subset. YAML parsing needs a library or custom parser. |
| Response templates library | Pre-built response templates for common patterns (paginated list, auth token response, error envelope, empty array, 401/403/404 errors). No competitor offers curated mobile-friendly templates. | MEDIUM | Ship 10-15 built-in templates. Each is a complete endpoint config (path, method, status, body, headers). User taps to add, then customizes. |
| Live request log with detail drill-down | Mockoon and MockServer have request logs, but on a phone/iPad the UX opportunity is different. Tap a logged request to see full headers, body, timing. Swipe to create an endpoint from a logged request. | HIGH | Extends the table-stakes request log. Detail view with formatted JSON body, header list, timing info. "Create endpoint from this request" action. |
| Haptic/visual feedback on request received | No desktop tool does this. A subtle haptic tap or flash when MockPad receives a request gives immediate tactile confirmation the mock is working. | LOW | UIImpactFeedbackGenerator on each incoming request. Optional -- user can disable in settings. |
| Bonjour/mDNS service advertisement | Advertise the mock server on the local network so other devices can discover it automatically. No competitor on any platform does easy zero-conf discovery for mock servers. | MEDIUM | NWListener supports Bonjour natively. Advertise as _http._tcp service. Client apps or browsers on same network can discover without knowing the IP/port. |
| PRO paywall (3 free endpoints, $5.99 unlimited) | Monetization model. Free tier validates the product, PRO removes limits for serious use. | MEDIUM | StoreKit 2 for IAP. Gate endpoint creation beyond 3. All other features available in free tier. |
| Endpoint grouping/folders | Organize endpoints by API or feature area (e.g., "Auth", "Users", "Products"). Mockoon and Postman have this; useful once you have 10+ endpoints. | LOW | Simple string tag or folder entity. Filter/group in list view. |
| Quick-duplicate endpoint | One-tap duplicate of an existing endpoint to create variations (same path, different status codes). Faster than creating from scratch. | LOW | Copy all fields, append " (copy)" to name. |

### Anti-Features (Deliberately NOT Building in v1)

Features that seem good but create problems, especially for a v1 iOS app.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Dynamic response templating (Handlebars/Faker) | WireMock and Mockoon have it. Seems powerful. | Massive complexity: need a template engine, Faker data generation, request-aware variable substitution. Overkill for v1. Most developers just need static responses they control. | Static JSON responses with manual editing. Add templating in v2 if user demand warrants it. |
| Stateful scenarios (WireMock-style state machines) | WireMock's scenario feature is powerful for multi-step flows. | Requires a state machine engine, UI for defining states/transitions, and complex matching logic. Very few developers need this in a mobile mock server. | Multiple response variants with manual switching. Developers can tap to change which response is active. |
| Record & playback (proxy to real API, capture responses) | WireMock, Mockoon, MockServer all have it. | Requires implementing an HTTP proxy, managing network permissions, SSL certificate handling for HTTPS proxying, and significant networking complexity. iOS sandbox restrictions complicate proxying. | Manual endpoint creation. If a user has a real API, they can copy responses into MockPad manually. Consider for v2. |
| GraphQL mocking | GraphQL has a rich mocking ecosystem (Apollo, graphql-faker). | Requires GraphQL schema parsing, query matching (not just URL matching), and a completely different request-handling pipeline. Too specialized for v1. | Users can mock GraphQL as a POST endpoint with a static JSON response body. Works for simple cases. |
| WebSocket mocking | WireMock supports WebSocket. Real-time apps need it. | Entirely different protocol. NWListener can handle TCP but WebSocket framing, upgrade handshake, and message routing are substantial work. Tiny user segment for v1. | Out of scope. Revisit if user demand appears. |
| HTTPS/TLS support | WireMock, MockServer, Mockoon all support HTTPS. | Requires certificate generation, trust configuration on the client device, and adds setup friction. Localhost HTTP is fine for development mocking. | Serve HTTP only on localhost. HTTPS adds zero value for local dev mocking and significant complexity. |
| Request body matching (route based on POST body content) | WireMock and Postman support matching on request body. | Complex matching logic, UI for defining body matchers (JSONPath, regex), and edge cases around content types. Path + method matching covers 90% of use cases. | Match on path + method only. Multiple response variants handle the "different responses for same endpoint" case. |
| CI/CD integration / headless mode | MockServer and WireMock are used in CI pipelines. | MockPad is an iOS GUI app, not a CI tool. Headless mode contradicts the product's value proposition (visual, on-device). | This is a different product category entirely. MockPad is for interactive development, not automated testing infrastructure. |
| Cloud sync / team collaboration | Postman has workspaces. Mockoon has Mockoon Cloud. | Requires a backend service, user accounts, conflict resolution, and ongoing server costs. Way too complex for v1 of an indie app. | Export/import via files. Share via AirDrop, iCloud Drive, or any file-sharing mechanism. |
| CORS header management | MockServer and WireMock have configurable CORS. | MockPad serves to native iOS apps on localhost, not to browsers. CORS is a browser-only concern and irrelevant for the primary use case. | If needed later (for web dev use case), add default CORS headers as a setting. Not v1. |
| Request validation against schema | Prism validates incoming requests against OpenAPI schemas. | Requires a full OpenAPI schema validator, error reporting UI, and adds complexity without clear value for a mock server (the point is to return responses, not validate requests). | Out of scope. Mock servers should be permissive, not strict. |

## Feature Dependencies

```
[Server Engine (NWListener)]
    +--requires--> [Endpoint Data Model]
    |                  +--requires--> [Endpoint CRUD UI]
    |                  +--enhances--> [Response Variants]
    |                  +--enhances--> [Path Parameters]
    |
    +--enables---> [Live Request Log]
    |                  +--enhances--> [Request Detail Drill-down]
    |                  +--enhances--> [Haptic Feedback]
    |
    +--enables---> [Server Start/Stop + Port Display]

[Endpoint CRUD UI]
    +--enhances--> [Response Templates Library]
    +--enhances--> [Endpoint Grouping/Folders]
    +--enhances--> [Quick-Duplicate Endpoint]

[Endpoint Data Model]
    +--enables---> [Export/Share]
    +--enables---> [OpenAPI Import]

[OpenAPI Import]
    +--requires--> [Endpoint Data Model]
    +--requires--> [JSON/YAML Parsing]

[PRO Paywall]
    +--gates-----> [Endpoint CRUD] (beyond 3 endpoints)
    +--requires--> [StoreKit 2 Integration]
```

### Dependency Notes

- **Server Engine requires Endpoint Data Model:** The NWListener request handler must look up matching endpoints to determine what response to serve. The data model must exist before the server can function.
- **Live Request Log requires Server Engine:** Requests can only be logged once the server is receiving them. The log is populated by the server's request handler.
- **OpenAPI Import requires Endpoint Data Model + JSON/YAML Parsing:** Import creates Endpoint entities, so the model must be defined first. YAML parsing is an additional dependency if supporting YAML-format specs.
- **Export/Share requires Endpoint Data Model:** Can only export what's been defined. Serialization format must be designed alongside the data model.
- **PRO Paywall gates Endpoint CRUD:** The paywall doesn't block features -- it limits quantity. The endpoint creation flow must check the count and prompt for upgrade.
- **Response Templates enhance Endpoint CRUD:** Templates are pre-filled endpoint configurations. They use the same creation flow but skip the manual entry step.

## MVP Definition

### Launch With (v1)

Minimum viable product -- what's needed to validate the concept.

- [ ] **Server engine (NWListener on localhost)** -- without this, there is no product
- [ ] **Endpoint CRUD (path, method, status, body, headers)** -- core interaction loop
- [ ] **Response delay simulation** -- low-cost feature that adds immediate testing value
- [ ] **Multiple response variants per endpoint** -- essential for testing error/success paths
- [ ] **Path parameter support** -- real APIs use /users/:id universally
- [ ] **Live request log** -- developers need confirmation their mock is being hit
- [ ] **Server start/stop with port display** -- basic server control
- [ ] **Export/import endpoint configs** -- sharing and backup capability
- [ ] **PRO paywall (3 free, $5.99 unlimited)** -- monetization from day one
- [ ] **iPad multitasking support** -- the killer use case, and it's nearly free with SwiftUI

### Add After Validation (v1.x)

Features to add once core is working and users are engaged.

- [ ] **OpenAPI v3 import** -- trigger: users requesting it, or to attract API-first teams
- [ ] **Response templates library** -- trigger: observing users creating the same patterns repeatedly
- [ ] **Request detail drill-down** -- trigger: users wanting more than the summary log view
- [ ] **Endpoint grouping/folders** -- trigger: users with 10+ endpoints struggling with flat lists
- [ ] **Bonjour/mDNS advertisement** -- trigger: users wanting to mock for apps on other devices
- [ ] **Haptic/visual feedback** -- trigger: polish pass after core stability

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Dynamic response templating** -- only if users demand dynamic data generation
- [ ] **Record & playback** -- requires HTTP proxy, significant complexity
- [ ] **Stateful scenarios** -- niche power-user feature
- [ ] **HTTPS support** -- only if users need it for non-localhost testing
- [ ] **GraphQL mocking** -- only if GraphQL developers are a significant user segment

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Server engine (NWListener) | HIGH | HIGH | P1 |
| Endpoint CRUD | HIGH | MEDIUM | P1 |
| JSON body editor | HIGH | MEDIUM | P1 |
| Custom response headers | HIGH | LOW | P1 |
| Status code selection | HIGH | LOW | P1 |
| Response delay | HIGH | LOW | P1 |
| Multiple response variants | HIGH | MEDIUM | P1 |
| Path parameters | HIGH | MEDIUM | P1 |
| Live request log | HIGH | HIGH | P1 |
| Server start/stop + port | HIGH | LOW | P1 |
| Export/import configs | MEDIUM | MEDIUM | P1 |
| PRO paywall | MEDIUM | MEDIUM | P1 |
| iPad multitasking | HIGH | LOW | P1 |
| OpenAPI import | HIGH | HIGH | P2 |
| Response templates | MEDIUM | MEDIUM | P2 |
| Request detail drill-down | MEDIUM | MEDIUM | P2 |
| Endpoint grouping | MEDIUM | LOW | P2 |
| Bonjour advertisement | MEDIUM | MEDIUM | P2 |
| Quick-duplicate endpoint | MEDIUM | LOW | P2 |
| Haptic feedback | LOW | LOW | P2 |
| Dynamic templating | MEDIUM | HIGH | P3 |
| Record & playback | MEDIUM | HIGH | P3 |
| Stateful scenarios | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Postman Mock | WireMock | Mockoon | json-server | Prism | MockPad (Our Approach) |
|---------|-------------|----------|---------|-------------|-------|----------------------|
| Platform | Cloud + desktop | Java CLI/lib | Electron desktop | Node.js CLI | Node.js CLI | Native iOS/iPadOS |
| Setup time | Minutes (account required) | Minutes (Java required) | Seconds (download app) | Seconds (npm install) | Seconds (npm install) | Seconds (App Store install) |
| Endpoint definition | Collection examples | JSON/Java API | GUI | JSON file | OpenAPI spec | GUI (SwiftUI) |
| Response delay | Yes (limited) | Yes (fixed, random, chunked) | Yes (fixed, random) | No | No | Yes (fixed) |
| Dynamic responses | Pre-request scripts | Handlebars templating | Handlebars + Faker.js | Custom middleware | Schema-based random | No (v1) -- static only |
| Request logging | Call logs (7-30 days) | Verification API | GUI log viewer | Console output | CLI output | GUI log viewer (on-device) |
| OpenAPI support | Import collections | JSON expectations | Import v2/v3, export v3 | No | Native (reads spec directly) | Import v3 (v1.x) |
| Multiple responses | Multiple examples | Scenarios + state machines | Rules-based routing | No | Example-based | Manual variant selection |
| Offline capable | No (cloud-dependent) | Yes | Yes | Yes | Yes | Yes (fully offline) |
| Mobile-native | No | No | No | No | No | Yes (only player here) |
| iPad Split View | No | No | No | No | No | Yes (unique advantage) |
| Price | Free tier + paid plans | Free (OSS) | Free (OSS) + Cloud paid | Free (OSS) | Free (OSS) | Free (3 endpoints) + $5.99 PRO |
| Record & playback | No | Yes | Yes | No | No (proxy mode) | No (v1) |
| Fault injection | No | Yes (empty, malformed, reset) | No | No | No | No (v1) |
| HTTPS | Yes | Yes | Yes (TLS) | No | No | No (v1) |
| Proxy mode | No | Yes | Yes (partial) | No | Yes | No (v1) |
| Stateful scenarios | No | Yes (state machines) | No (rules only) | No | No | No (v1) |

## Sources

- [Postman Mock Server Docs](https://learning.postman.com/docs/designing-and-developing-your-api/mocking-data/setting-up-mock/)
- [Postman Mock Features](https://www.postman.com/features/mock-api/)
- [WireMock GitHub](https://github.com/wiremock/wiremock)
- [WireMock Docs](https://wiremock.org/docs/)
- [WireMock Stateful Behaviour](https://wiremock.org/docs/stateful-behaviour/)
- [WireMock Fault Simulation](https://wiremock.org/docs/simulating-faults/)
- [Mockoon](https://mockoon.com/)
- [Mockoon Dynamic Rules](https://mockoon.com/docs/latest/route-responses/dynamic-rules/)
- [Mockoon Templating](https://mockoon.com/docs/latest/templating/overview/)
- [Mockoon OpenAPI Import/Export](https://mockoon.com/docs/latest/openapi/import-export-openapi-format/)
- [json-server GitHub](https://github.com/typicode/json-server)
- [Stoplight Prism](https://stoplight.io/open-source/prism)
- [Prism GitHub](https://github.com/stoplightio/prism)
- [MockServer](https://www.mock-server.com/)
- [MockServer CORS](https://www.mock-server.com/mock_server/CORS_support.html)
- [Mockifer GitHub](https://github.com/MarcelBraghetto/mockifer)
- [Apple NWListener Docs](https://developer.apple.com/documentation/network/nwlistener)
- [Postman Mock Call Logs](https://blog.postman.com/introducing-postman-mock-call-logs/)
- [WireMock Record & Playback](https://wiremock.org/docs/record-playback/)

---
*Feature research for: iOS-native mock HTTP server app*
*Researched: 2026-02-16*
