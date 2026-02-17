# Phase 6: Path Parameters + Wildcard Matching - Research

**Researched:** 2026-02-17
**Domain:** URL path matching algorithms, path parameter extraction, wildcard routing, response token substitution
**Confidence:** HIGH

## Summary

Phase 6 upgrades the EndpointMatcher from exact-path-only matching to a full routing engine that supports three match types: exact paths (`/api/users`), parameterized paths (`/api/users/:id`), and wildcard paths (`/api/*`). The phase also adds response body token substitution, where `{paramName}` tokens in the response body are replaced with actual path parameter values extracted from the incoming request.

The technical scope is well-defined and self-contained. The core work is a `matchPath(pattern:against:)` function inside EndpointMatcher that splits URL paths into segments and matches them against endpoint patterns. This is a pure function -- no networking, no UI framework, no SwiftData -- making it ideal for TDD. The only integration points are: (1) the MatchResult enum gains a `pathParams` dictionary, (2) MockServerEngine applies token substitution to the response body before sending, and (3) the EndpointSnapshot/EndpointData tuples carry the path params through the pipeline.

The MOCKPAD-TECHNICAL.md Section 3.4 provides a reference implementation of `matchPath` that handles all three match types in approximately 45 lines. The priority system (exact > parameterized > wildcard) ensures deterministic routing when multiple endpoints could match the same request path. The token substitution (RESP-09) is a simple string replacement operation performed in MockServerEngine after matching but before response building.

**Primary recommendation:** Build this phase in two plans: (1) TDD the enhanced EndpointMatcher with `matchPath`, path parameter extraction, wildcard matching, priority-based selection, and a `PathParamReplacer` service for response body token substitution (~20+ unit tests), then (2) integrate into MockServerEngine by threading `pathParams` through MatchResult, applying token substitution before building the response, and updating the EndpointSnapshot-to-EndpointData pipeline.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Foundation | iOS 17+ | String splitting, path segment manipulation | Standard library. Path matching is pure string operations: `split(separator:)`, `hasPrefix`, `lowercased()`. No regex needed. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for path matching, parameter extraction, token substitution | All test files. ~20+ tests covering exact, parameterized, wildcard, priority, edge cases. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual segment-by-segment matching | NSRegularExpression pattern matching | Regex is overkill for segment-based URL matching. Manual splitting is simpler, faster, and more readable. The technical doc uses manual splitting. |
| Simple string replacement for tokens | Handlebars/Mustache template engine | Template engines handle conditionals, loops, etc. RESP-09 only needs `{key}` -> `value` replacement. String replacement is sufficient. Advanced templating is deferred to v2 (ADVN-01). |
| Flat priority selection (first match wins) | Scored matching with specificity ranking | Scored matching handles complex overlapping patterns. For MockPad's three tiers (exact, param, wildcard), a simple ordered filter is clear and correct. |

## Architecture Patterns

### Recommended Project Structure

```
MockPad/MockPad/
├── Services/
│   ├── EndpointMatcher.swift         # MODIFY: add matchPath, priority-based matching, pathParams in MatchResult
│   ├── PathParamReplacer.swift       # NEW: caseless enum, replace {token} with path param values
│   ├── MockServerEngine.swift        # MODIFY: apply PathParamReplacer to response body before sending
│   ├── EndpointSnapshot.swift        # NO CHANGE: path field already stores :param and * patterns
│   └── ...                           # Remaining services unchanged

MockPadTests/
├── EndpointMatcherTests.swift        # MODIFY: add ~15 new tests for path params, wildcards, priority
├── PathParamReplacerTests.swift      # NEW: ~6 tests for token substitution
```

### Pattern 1: Segment-Based Path Matching (matchPath)

**What:** Split both the endpoint pattern and the request path by `/`, then compare segment by segment. Literal segments must match exactly (case-insensitive). `:param` segments match any single segment and capture the value. `*` at the end matches any remaining segments.

**When to use:** Every request matching operation inside EndpointMatcher.

**Why this pattern:** The MOCKPAD-TECHNICAL.md Section 3.4 specifies this exact algorithm. It handles all three match types in a single pass through the segments, returning extracted parameters as a dictionary.

**Example:**
```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.4
private static func matchPath(
    pattern: String,
    against path: String
) -> [String: String]? {
    let patternSegments = pattern.split(separator: "/").map(String.init)
    let pathSegments = path.split(separator: "/").map(String.init)

    // Check for wildcard at end
    if let last = patternSegments.last, last == "*" {
        let nonWildcard = patternSegments.dropLast()
        guard pathSegments.count >= nonWildcard.count else { return nil }
        var params: [String: String] = [:]
        for (patternSeg, pathSeg) in zip(nonWildcard, pathSegments) {
            if patternSeg.hasPrefix(":") {
                params[String(patternSeg.dropFirst())] = pathSeg
            } else if patternSeg.lowercased() != pathSeg.lowercased() {
                return nil
            }
        }
        return params
    }

    // Exact segment count required for non-wildcard patterns
    guard patternSegments.count == pathSegments.count else { return nil }

    var params: [String: String] = [:]
    for (patternSeg, pathSeg) in zip(patternSegments, pathSegments) {
        if patternSeg.hasPrefix(":") {
            params[String(patternSeg.dropFirst())] = pathSeg
        } else if patternSeg.lowercased() != pathSeg.lowercased() {
            return nil
        }
    }
    return params
}
```

**Key properties:**
- Returns `nil` for no match, `[:]` (empty dict) for exact match, `["id": "42"]` for parameterized match
- Case-insensitive comparison on literal segments (consistent with existing exact matching)
- Wildcard only valid at the end of the pattern (not mid-path)
- `matchPath` is a pure function, no state, fully testable

### Pattern 2: Priority-Based Match Selection

**What:** When multiple endpoints match a request path, select the most specific match. Priority: exact match (0 params) > parameterized (has params, no wildcard) > wildcard.

**When to use:** In the `match()` function, after collecting all path matches, sort/filter by specificity before checking method.

**Why this pattern:** MOCKPAD-TECHNICAL.md Section 3.4 specifies this priority order. Without it, a wildcard `/api/*` would shadow a more specific `/api/users/:id`.

**Example approach:**
```swift
// Collect all path matches with their extracted params
var pathMatches: [(endpoint: EndpointData, params: [String: String])] = []
for ep in enabledEndpoints {
    if let params = matchPath(pattern: ep.path, against: path) {
        pathMatches.append((ep, params))
    }
}

// Sort by specificity: fewer params = more specific
// Exact (0 params, no wildcard) > Parameterized > Wildcard
pathMatches.sort { a, b in
    let aIsWildcard = a.endpoint.path.hasSuffix("/*") || a.endpoint.path.hasSuffix("*")
    let bIsWildcard = b.endpoint.path.hasSuffix("/*") || b.endpoint.path.hasSuffix("*")
    if aIsWildcard != bIsWildcard { return !aIsWildcard }  // non-wildcard first
    return a.params.count < b.params.count  // fewer params = more specific
}
```

**Specificity scoring (simpler alternative):**
- Exact match: path has no `:` segments and no `*` --> score 0
- Parameterized: path has `:` segments but no `*` --> score 1
- Wildcard: path ends with `*` --> score 2
- Lower score wins. Within same score, first defined (array order) wins.

### Pattern 3: Token Substitution in Response Body (PathParamReplacer)

**What:** A caseless enum service with a single static function that scans the response body for `{paramName}` tokens and replaces them with actual values from the path params dictionary.

**When to use:** In MockServerEngine, after matching and before response building, for matched endpoints only.

**Why this pattern:** Follows the established caseless-enum pure-function pattern (HTTPRequestParser, HTTPResponseBuilder, EndpointMatcher, CurlGenerator, BuiltInTemplates). Simple string replacement is sufficient for RESP-09; advanced templating is v2 (ADVN-01).

**Example:**
```swift
enum PathParamReplacer {
    nonisolated static func replace(
        in body: String,
        with params: [String: String]
    ) -> String {
        var result = body
        for (key, value) in params {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
```

**Design note:** The replacement is intentionally simple -- literal `{key}` to `value`. No escaping, no nested tokens, no conditionals. This matches the MOCKPAD-TECHNICAL.md Section 12.4 specification: `{"id": {id}, "name": "User {id}"}` becomes `{"id": 42, "name": "User 42"}`. The replacement handles both JSON values (`{id}` unquoted for numbers) and string interpolation (`"User {id}"` inside quotes).

### Pattern 4: MatchResult with Path Parameters

**What:** Extend the MatchResult.matched case to carry extracted path parameters alongside the existing response data.

**When to use:** When returning a match from EndpointMatcher.

**Example:**
```swift
enum MatchResult: Sendable {
    case matched(path: String, method: String, statusCode: Int,
                 responseBody: String, responseHeaders: [String: String],
                 responseDelayMs: Int, pathParams: [String: String])
    case notFound
    case methodNotAllowed(allowedMethods: [String])
}
```

**Design note:** Adding `pathParams` as the last associated value minimizes diff to existing code. The MockServerEngine extracts `pathParams` in the `.matched` case and passes it to `PathParamReplacer.replace(in:with:)` before building the response.

### Anti-Patterns to Avoid

- **Regex-based path matching:** Using `NSRegularExpression` to match URL paths is overkill and harder to debug than segment splitting. URL paths are structured with `/` delimiters -- use `split(separator: "/")`.

- **Mutating the endpoint's stored response body:** Token substitution must operate on a copy of the response body for each request. Never modify the stored endpoint data with request-specific values.

- **Wildcard in the middle of a path:** The spec only supports wildcard at the end (`/api/*`). Do not implement mid-path wildcards (`/api/*/posts`) -- this is out of scope and adds ambiguity.

- **Case-sensitive path parameter names:** Path parameter names in the pattern (`:id`) and tokens in the response body (`{id}`) should be case-sensitive to each other. `/users/:id` extracts key `"id"`, which replaces `{id}` but NOT `{ID}`. This matches developer expectations from Express.js, Rails, etc.

- **Forgetting to pass pathParams to the 405 code path:** When a path matches but the method does not, the 405 response does not need path params (no response body substitution on error responses). But the path match collection must still work correctly with parameterized paths for 405 detection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL path segment splitting | Custom parser for slashes | `String.split(separator: "/")` | Foundation handles empty segments, leading/trailing slashes correctly |
| Template engine | Handlebars/Mustache-style parser | Simple `String.replacingOccurrences(of:with:)` loop | RESP-09 only needs `{key}` -> `value`. No conditionals, loops, or nesting. |

**Key insight:** This entire phase is pure string manipulation. No frameworks, no networking changes, no UI changes. The EndpointMatcher enhancement is ~50 lines of new code (matchPath + priority sort). The token replacer is ~10 lines. The MockServerEngine integration is ~5 lines of changed code. The test suite is the largest deliverable (~20+ tests).

## Common Pitfalls

### Pitfall 1: Leading/Trailing Slash Handling

**What goes wrong:** Pattern `/api/users` and path `/api/users/` have different segment counts after splitting. The match fails unexpectedly.

**Why it happens:** `"/api/users/".split(separator: "/")` returns `["api", "users"]` (Swift's split drops empty trailing elements), but `"/api/users/".components(separatedBy: "/")` returns `["", "api", "users", ""]` with empty strings.

**How to avoid:** Use `.split(separator: "/")` consistently for both pattern and path. Swift's `split` drops empty subsequences by default, which normalizes trailing slashes. Leading slashes are also handled because the empty string before the first `/` is dropped.

**Warning signs:** Tests pass for `/api/users` but fail for `/api/users/` (with trailing slash).

### Pitfall 2: Priority Order with Method Filtering

**What goes wrong:** The priority sort is applied after method filtering, which means a less-specific endpoint with the right method beats a more-specific endpoint with the wrong method. The 405 response references the wrong match.

**Why it happens:** The matching algorithm should: (1) collect ALL path matches regardless of method, (2) sort by specificity, (3) filter by method on the sorted list.

**How to avoid:** Separate path matching from method matching. First find all endpoints whose path pattern matches the request path. Sort by specificity. Then check if the most-specific path match has the right method. If no method match exists among path matches, return 405 with allowed methods from ALL path-matched endpoints.

**Warning signs:** 405 responses list methods from a wildcard endpoint instead of the exact/parameterized endpoint that should have matched.

### Pitfall 3: Empty Path Parameters

**What goes wrong:** Request to `/api/users//posts` (double slash) could match `/api/users/:id/posts` with an empty `id` parameter.

**Why it happens:** Depending on split behavior, an empty segment between slashes could be matched against a `:param` segment.

**How to avoid:** `String.split(separator: "/")` in Swift drops empty subsequences by default, so `"/api/users//posts"` splits to `["api", "users", "posts"]` (3 segments), which would NOT match the 4-segment pattern `["api", "users", ":id", "posts"]`. This is the correct behavior -- double slashes in the request path are collapsed.

**Warning signs:** Unexpected matches or mismatched parameter counts with malformed URLs.

### Pitfall 4: Token Substitution Breaking JSON Validity

**What goes wrong:** User writes `{"id": {id}}` (no quotes around `{id}`). After substitution with value `"42"`, the result is `{"id": 42}` which is valid JSON. But if the value is `"abc"`, the result is `{"id": abc}` which is INVALID JSON.

**Why it happens:** The substitution is a literal string replacement with no awareness of JSON structure.

**How to avoid:** This is by design per the MOCKPAD-TECHNICAL.md Section 12.4 specification. The substitution is "simple template substitution" -- the user is responsible for ensuring the response body remains valid after substitution. Document this behavior but do not attempt to add JSON-aware substitution (that's v2 ADVN-01 territory).

**Warning signs:** User reports invalid JSON responses when using path parameter tokens with non-numeric values in unquoted positions. This is expected behavior, not a bug.

### Pitfall 5: Wildcard Matching Empty Sub-Paths

**What goes wrong:** Pattern `/api/*` should match `/api/users`, `/api/users/42`, etc. But should it match `/api` itself (no sub-path)?

**Why it happens:** After splitting, `/api/*` has segments `["api", "*"]` and `/api` has segments `["api"]`. The wildcard check `pathSegments.count >= nonWildcard.count` compares `1 >= 1` which is true, so `/api` matches `/api/*`.

**How to avoid:** Decide on the semantics. The reference implementation in MOCKPAD-TECHNICAL.md uses `pathSegments.count >= nonWildcard.count`, which means `/api/*` matches `/api` (with zero wildcard segments). This is reasonable -- the wildcard means "anything from this point, including nothing." Keep this behavior but test it explicitly.

**Warning signs:** Unexpected behavior when users expect `/api/*` to only match paths with content after `/api/`.

### Pitfall 6: Existing EndpointMatcher Tests Breaking

**What goes wrong:** The existing 9 EndpointMatcher tests use the current `MatchResult.matched` case with 6 associated values. Adding `pathParams: [String: String]` to the case changes the destructuring pattern and breaks all existing tests.

**Why it happens:** Swift tuple/enum destructuring is positional. Adding a new associated value requires updating all `case let .matched(...)` patterns.

**How to avoid:** Update all existing test `guard case let .matched(...)` patterns to include the new `pathParams` parameter. For existing exact-match tests, the `pathParams` should be an empty dictionary `[:]`. This is a mechanical change -- 4 existing tests destructure the matched case and need updating.

**Warning signs:** Compile errors in EndpointMatcherTests after modifying MatchResult.

## Code Examples

Verified patterns from project conventions and MOCKPAD-TECHNICAL.md:

### Complete matchPath Implementation

```swift
// Source: MOCKPAD-TECHNICAL.md Section 3.4
nonisolated private static func matchPath(
    pattern: String,
    against path: String
) -> [String: String]? {
    let patternSegments = pattern.split(separator: "/").map(String.init)
    let pathSegments = path.split(separator: "/").map(String.init)

    // Wildcard at end of pattern
    if let last = patternSegments.last, last == "*" {
        let nonWildcard = patternSegments.dropLast()
        guard pathSegments.count >= nonWildcard.count else { return nil }
        var params: [String: String] = [:]
        for (patternSeg, pathSeg) in zip(nonWildcard, pathSegments) {
            if patternSeg.hasPrefix(":") {
                params[String(patternSeg.dropFirst())] = pathSeg
            } else if patternSeg.lowercased() != pathSeg.lowercased() {
                return nil
            }
        }
        return params
    }

    // Non-wildcard: segment count must match exactly
    guard patternSegments.count == pathSegments.count else { return nil }

    var params: [String: String] = [:]
    for (patternSeg, pathSeg) in zip(patternSegments, pathSegments) {
        if patternSeg.hasPrefix(":") {
            params[String(patternSeg.dropFirst())] = pathSeg
        } else if patternSeg.lowercased() != pathSeg.lowercased() {
            return nil
        }
    }
    return params
}
```

### Priority-Based Match in Updated match() Function

```swift
// Source: Project conventions + MOCKPAD-TECHNICAL.md priority spec
nonisolated static func match(
    method: String,
    path: String,
    endpoints: [EndpointData]
) -> MatchResult {
    let enabledEndpoints = endpoints.filter { $0.isEnabled }

    // Phase 1: Find all path matches with extracted params
    var pathMatches: [(endpoint: EndpointData, params: [String: String])] = []
    for ep in enabledEndpoints {
        if let params = matchPath(pattern: ep.path, against: path) {
            pathMatches.append((ep, params))
        }
    }

    guard !pathMatches.isEmpty else { return .notFound }

    // Phase 2: Sort by specificity (exact > parameterized > wildcard)
    pathMatches.sort { a, b in
        specificity(of: a.endpoint.path) < specificity(of: b.endpoint.path)
    }

    // Phase 3: Find method match among sorted path matches
    if let best = pathMatches.first(where: {
        $0.endpoint.method.uppercased() == method.uppercased()
    }) {
        return .matched(
            path: best.endpoint.path,
            method: best.endpoint.method,
            statusCode: best.endpoint.statusCode,
            responseBody: best.endpoint.responseBody,
            responseHeaders: best.endpoint.responseHeaders,
            responseDelayMs: best.endpoint.responseDelayMs,
            pathParams: best.params
        )
    }

    // Path matched but method did not -> 405
    let allowedMethods = Array(Set(pathMatches.map {
        $0.endpoint.method.uppercased()
    })).sorted()
    return .methodNotAllowed(allowedMethods: allowedMethods)
}

/// Specificity score: 0 = exact, 1 = parameterized, 2 = wildcard
nonisolated private static func specificity(of pattern: String) -> Int {
    let segments = pattern.split(separator: "/").map(String.init)
    if segments.last == "*" { return 2 }
    if segments.contains(where: { $0.hasPrefix(":") }) { return 1 }
    return 0
}
```

### PathParamReplacer Service

```swift
// Source: MOCKPAD-TECHNICAL.md Section 12.4
enum PathParamReplacer {
    /// Replace {paramName} tokens in the response body with actual values.
    /// Simple literal replacement -- no escaping, no nesting.
    nonisolated static func replace(
        in body: String,
        with params: [String: String]
    ) -> String {
        guard !params.isEmpty else { return body }
        var result = body
        for (key, value) in params {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
```

### MockServerEngine Integration Point

```swift
// In handleReceivedData, after match and before response building:
case .matched(let path, _, let statusCode, let body, let headers, let matchedDelayMs, let pathParams):
    delayMs = matchedDelayMs
    responseStatusCode = statusCode
    // Apply path parameter token substitution before building response
    let resolvedBody = PathParamReplacer.replace(in: body, with: pathParams)
    responseBody = resolvedBody
    matchedEndpointPath = path
    // ... build response with resolvedBody instead of body
```

### Test Patterns for Path Matching

```swift
// Source: Project test conventions (Swift Testing, struct-based suites)
struct EndpointMatcherTests {
    // ... existing tests (updated for new pathParams associated value) ...

    // NEW: Path parameter tests
    @Test func pathParam_singleParam_extractsValue() {
        let endpoints = [endpoint(path: "/api/users/:id", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched")
            return
        }
        #expect(pathParams["id"] == "42")
    }

    @Test func pathParam_multipleParams_extractsAll() {
        let endpoints = [endpoint(path: "/api/users/:userId/posts/:postId", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42/posts/7", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched")
            return
        }
        #expect(pathParams["userId"] == "42")
        #expect(pathParams["postId"] == "7")
    }

    @Test func wildcard_matchesSubPath() {
        let endpoints = [endpoint(path: "/api/*", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42/posts", endpoints: endpoints)
        guard case .matched = result else {
            Issue.record("Expected .matched")
            return
        }
    }

    @Test func priority_exactOverParam() {
        let endpoints = [
            endpoint(path: "/api/users/:id", method: "GET", statusCode: 200),
            endpoint(path: "/api/users/me", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/me", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched")
            return
        }
        #expect(statusCode == 201)  // Exact match wins
    }

    @Test func priority_paramOverWildcard() {
        let endpoints = [
            endpoint(path: "/api/*", method: "GET", statusCode: 200),
            endpoint(path: "/api/users/:id", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched")
            return
        }
        #expect(statusCode == 201)  // Parameterized wins over wildcard
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| EndpointMatcher: exact path string comparison | Segment-based matching with params and wildcards | Phase 6 (this phase) | Supports dynamic paths like `/api/users/:id` and catch-all wildcards `/api/*` |
| Static response body | Response body with token substitution | Phase 6 (this phase) | `{id}` in response body replaced with actual request value |

**Deprecated/outdated:**
- Nothing deprecated. Phase 6 extends the EndpointMatcher; the existing exact-matching behavior is preserved as the highest-priority match type.

## Open Questions

1. **Should `matchPath` handle percent-encoded path segments?**
   - What we know: `HTTPRequestParser.parse` preserves path segments as-is from the request line. Browsers and HTTP clients percent-encode special characters in URL paths (e.g., spaces become `%20`).
   - What's unclear: Whether endpoint patterns defined by users contain percent-encoded characters.
   - Recommendation: Keep path matching on raw segments for Phase 6. Users define patterns with literal characters (`:id`, not `:%69d`). If percent-encoding issues arise in practice, add `.removingPercentEncoding` to the path segments before matching in a future phase. LOW risk since mock server URLs are developer-controlled.

2. **Should wildcard `*` match at the path root (just `/*` or even `*`)?**
   - What we know: The spec says `/api/*` matches any sub-path under `/api/`. A root wildcard `/*` would match everything.
   - What's unclear: Whether users would define `/*` as a catch-all endpoint.
   - Recommendation: Allow it. `/*` is a valid pattern -- it matches every path. This is useful as a default fallback endpoint. The priority system ensures more specific endpoints still win.

3. **Should path params be included in the request log?**
   - What we know: The MOCKPAD-TOOLS.md (Feature 3, Response Tab) specifies `Path Parameters: {"id": "42"}` as a section in the request detail view.
   - What's unclear: Whether to add path params to RequestLogData/RequestLog in Phase 6 or defer to a later enhancement.
   - Recommendation: Defer to a separate plan if scoped into Phase 6. The core requirements (ENDP-06, ENDP-07, ENDP-08, RESP-09) focus on matching and substitution, not logging. Adding path params to the log model requires a SwiftData lightweight migration field addition. If included, it would be a separate plan from the core matching logic.

## Sources

### Primary (HIGH confidence)
- `/workspace/.planning/mockpad/MOCKPAD-TECHNICAL.md` Section 3.4 -- Complete `matchPath` reference implementation, priority rules, path parameter extraction algorithm
- `/workspace/.planning/mockpad/MOCKPAD-TECHNICAL.md` Section 12.4 -- Path parameter injection specification: `{paramName}` token replacement in response bodies
- `/workspace/.planning/mockpad/MOCKPAD-TOOLS.md` Feature 2 -- Path input requirements: `:param` notation, wildcard support, token replacement in response body
- `/workspace/MockPad/MockPad/Services/EndpointMatcher.swift` -- Current exact-match implementation (Phase 2), to be extended
- `/workspace/MockPad/MockPad/Services/MockServerEngine.swift` -- Current request processing pipeline, integration point for token substitution
- `/workspace/MockPad/MockPadTests/EndpointMatcherTests.swift` -- 9 existing tests that must continue to pass after refactoring

### Secondary (MEDIUM confidence)
- `/workspace/.planning/phases/02-server-engine-core/02-RESEARCH.md` -- Established architecture patterns (caseless enum services, actor isolation, Sendable DTOs)
- `/workspace/.planning/phases/05-response-templates-delay/05-03-PLAN.md` -- Pattern for extending EndpointMatcher.EndpointData tuple and MatchResult (followed for responseDelayMs addition)

### Tertiary (LOW confidence)
- None -- all findings verified with project codebase and technical documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- This phase uses only Foundation string operations. No new frameworks or libraries needed. Zero-dependency constraint is trivially satisfied.
- Architecture: HIGH -- The matchPath algorithm is specified in MOCKPAD-TECHNICAL.md with a complete reference implementation. The integration points (MatchResult extension, MockServerEngine substitution) follow the exact pattern used in Phase 5 for responseDelayMs.
- Pitfalls: HIGH -- All pitfalls identified from code analysis of the existing codebase. The `split(separator:)` vs `components(separatedBy:)` behavior is verified in Swift standard library documentation. Existing test breakage is predictable from the MatchResult enum change.

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (Pure algorithmic work, no framework version dependencies)
