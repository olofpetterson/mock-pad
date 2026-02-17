# Phase 8: OpenAPI Import - Research

**Researched:** 2026-02-17
**Domain:** OpenAPI 3.x specification parsing, YAML subset parsing, schema-to-mock-response generation, path parameter format conversion
**Confidence:** HIGH

## Summary

Phase 8 adds OpenAPI 3.x specification import -- users can select a JSON or YAML file from the Files app, preview discovered endpoints, and import them as MockEndpoint entries with auto-generated mock response bodies. The technical domain spans three distinct problems: (1) parsing the OpenAPI document structure to extract paths, operations, and response schemas, (2) resolving `$ref` references to component schemas, and (3) generating realistic mock JSON response bodies from schema definitions.

The project's zero-external-dependencies constraint means Yams cannot be used despite the roadmap mentioning it. The PROJECT.md key decision is explicit: "Minimal YAML parser: Best-effort for OpenAPI YAML; JSON fully supported, YAML is fallback." This means building a minimal YAML-to-JSON converter that handles the subset of YAML used by OpenAPI specs (block mappings, block sequences, scalar types, indentation-based nesting) and then feeding the result to Foundation's `JSONDecoder` for Codable-based parsing. JSON import uses `JSONDecoder` directly with zero conversion.

The codebase already provides the infrastructure pattern: `CollectionImporter` (caseless enum service, parse + validate, error handling), `ImportPreviewSheet` (preview UI with select/deselect, PRO gating, duplicate resolution), `ExportedEndpoint` (Codable DTO for endpoint data), and `EndpointStore.importEndpoints()` (batch insertion with duplicate handling). The OpenAPI importer follows the same pattern but adds an OpenAPI-specific parsing layer before producing `ExportedEndpoint` DTOs that feed into the existing import pipeline.

**Primary recommendation:** Build three new caseless enum services: `OpenAPIParser` (parses OpenAPI JSON/YAML into typed Codable DTOs), `YAMLConverter` (minimal YAML-to-JSON converter for the OpenAPI subset), and `MockResponseGenerator` (generates mock JSON response bodies from OpenAPI schema objects). Reuse the existing `ImportPreviewSheet` pattern (with modifications for select/deselect checkboxes and warnings) and the existing `EndpointStore.importEndpoints()` for final insertion.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Foundation | iOS 26+ | `JSONDecoder`/`JSONSerialization` for JSON OpenAPI parsing, `Data(contentsOf:)` for file reading | Built-in. Handles JSON natively. |
| SwiftUI | iOS 26+ | `fileImporter` for file selection, sheet for OpenAPI preview UI | Already in use. Same pattern as MockPad JSON import. |
| UniformTypeIdentifiers | iOS 26+ | `UTType.json`, `UTType(filenameExtension: "yaml")`, `UTType(filenameExtension: "yml")` for file picker | YAML has no built-in UTType; create from extension. |
| Swift Testing | Xcode 26+ | TDD for parser, converter, and generator services | Project convention. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None | - | - | Zero external dependencies. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled YAML converter | Yams SPM package | Yams provides full YAML spec support, but violates project's zero-dependencies constraint. The PROJECT.md key decision explicitly says "Minimal YAML parser." OpenAPI YAML uses a well-defined subset (block mappings, sequences, scalars, indentation) that is feasible to hand-roll. |
| Hand-rolled OpenAPI parser | OpenAPIKit / swift-openapi-generator | These provide full spec compliance but bring heavy transitive dependencies. MockPad only needs to extract paths, operations, and response schemas -- a small fraction of the full spec. |
| Codable DTOs for OpenAPI types | `JSONSerialization` with `[String: Any]` dictionaries | Codable DTOs provide type safety and clear structure. However, OpenAPI's flexible schema (optional fields everywhere, `$ref` at any level) makes pure Codable parsing fragile. Recommendation: Use `JSONSerialization` to parse into `[String: Any]` first, then manually extract into typed structs. This handles `$ref`, optional fields, and unknown keys gracefully without needing exhaustive Codable mapping. |

## Architecture Patterns

### Recommended Project Structure

```
MockPad/MockPad/
├── Services/
│   ├── OpenAPIParser.swift          # NEW: Extracts endpoints from OpenAPI JSON/YAML
│   ├── YAMLConverter.swift          # NEW: Minimal YAML-to-JSON converter
│   ├── MockResponseGenerator.swift  # NEW: Generates mock JSON from schema objects
│   ├── CollectionImporter.swift     # EXISTING: Reuse for final import logic
│   └── MockPadExportModels.swift    # EXISTING: ExportedEndpoint DTO reused
│
├── Views/
│   ├── OpenAPIPreviewSheet.swift    # NEW: Preview with checkboxes + warnings
│   └── EndpointListView.swift       # MODIFY: Add "Import OpenAPI" menu item
│
└── MockPadTests/
    ├── OpenAPIParserTests.swift      # NEW: ~20 tests for spec parsing
    ├── YAMLConverterTests.swift      # NEW: ~15 tests for YAML subset conversion
    └── MockResponseGeneratorTests.swift # NEW: ~12 tests for response generation
```

### Pattern 1: OpenAPI Document as `[String: Any]` Dictionary Tree

**What:** Parse the OpenAPI document using `JSONSerialization` (for JSON) or `YAMLConverter` + `JSONSerialization` (for YAML) into a `[String: Any]` dictionary tree, then walk the tree to extract endpoints.

**When to use:** For all OpenAPI parsing. The OpenAPI spec has too many optional fields, extension keys (`x-*`), and `$ref` references to map cleanly with pure Codable. Dictionary-based parsing is more resilient.

**Why this pattern:** OpenAPI documents are deeply nested with `$ref` references at any level. A `$ref` like `"#/components/schemas/Pet"` is a JSON Pointer that refers to another location in the same document. Resolving these requires access to the full document tree. Codable decoding would require a two-pass approach (decode references, then resolve). Dictionary walking handles this naturally with a single-pass resolver.

**Example:**
```swift
// Source: Project conventions (caseless enum service pattern)
enum OpenAPIParser {
    enum ParseError: Error, LocalizedError, Equatable {
        case invalidJSON(String)
        case notOpenAPI
        case unsupportedVersion(String)
        case noPaths

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let detail): return "Invalid file: \(detail)"
            case .notOpenAPI: return "Not an OpenAPI specification"
            case .unsupportedVersion(let v): return "Unsupported OpenAPI version: \(v)"
            case .noPaths: return "No API paths found in specification"
            }
        }
    }

    struct DiscoveredEndpoint {
        let path: String           // Already converted to :param format
        let httpMethod: String     // Uppercased
        let summary: String?       // From operation summary
        let responseStatusCode: Int // First success status code
        let responseBody: String   // Generated mock JSON
        let responseHeaders: [String: String]
        var isSelected: Bool = true // For preview UI
        var warnings: [String] = [] // Unsupported features
    }

    struct ParseResult {
        let title: String
        let version: String
        let endpoints: [DiscoveredEndpoint]
        let globalWarnings: [String]
    }

    static func parse(data: Data) throws -> ParseResult {
        // 1. Try JSON first, fall back to YAML conversion
        // 2. Validate openapi version field
        // 3. Walk paths -> operations -> responses
        // 4. Resolve $ref references
        // 5. Generate mock responses from schemas
        // 6. Convert {param} to :param format
        // 7. Collect warnings for unsupported features
    }
}
```

### Pattern 2: Minimal YAML-to-JSON Converter

**What:** A line-by-line YAML parser that handles the subset of YAML used by OpenAPI specifications: block mappings (key: value), block sequences (- item), indentation-based nesting, and scalar types (string, integer, boolean, null). Converts to a `[String: Any]` dictionary that can be serialized to JSON via `JSONSerialization`.

**When to use:** When the file extension is `.yaml` or `.yml`, or when `JSONSerialization` fails on the raw data (auto-detection).

**Why this pattern:** YAML is a superset of JSON. OpenAPI specs use a well-defined subset: block mappings, block sequences, scalars with basic types. Features like anchors/aliases (`&`/`*`), multi-line literal blocks (`|`/`>`), flow collections (`{}`/`[]`), and tags (`!!`) are rare in OpenAPI specs. A minimal parser covering 95%+ of real-world OpenAPI YAML files is feasible at ~200-300 lines of Swift.

**Example:**
```swift
enum YAMLConverter {
    enum ConversionError: Error, LocalizedError {
        case invalidYAML(String)

        var errorDescription: String? {
            switch self {
            case .invalidYAML(let detail): return "Invalid YAML: \(detail)"
            }
        }
    }

    /// Convert YAML string to JSON Data
    static func toJSON(_ yaml: String) throws -> Data {
        let parsed = try parseYAML(yaml)
        return try JSONSerialization.data(withJSONObject: parsed)
    }

    // Internal: line-by-line parser tracking indentation
    private static func parseYAML(_ yaml: String) throws -> Any {
        // Track indentation levels with a stack
        // Parse key: value pairs into dictionaries
        // Parse - items into arrays
        // Handle quoted strings, integers, floats, booleans, null
        // Return [String: Any] or [Any]
    }
}
```

### Pattern 3: `$ref` Resolution via Document Tree Walking

**What:** Resolve `$ref` references by splitting the JSON Pointer path (`#/components/schemas/Pet` -> `["components", "schemas", "Pet"]`) and walking the parsed dictionary tree to find the referenced object.

**When to use:** Whenever a `$ref` key is encountered while walking the OpenAPI document tree.

**Why this pattern:** OpenAPI uses `$ref` extensively to avoid duplication. Most references are internal (same document), pointing to `#/components/schemas/...`. External references (other files) are rare and out of scope for v1. Circular references (schema A references schema B which references schema A) need a visited-set guard with a depth limit to prevent infinite recursion.

**Example:**
```swift
// Within OpenAPIParser
private static func resolveRef(
    _ ref: String,
    in document: [String: Any],
    visited: inout Set<String>,
    depth: Int = 0
) -> [String: Any]? {
    guard depth < 20 else { return nil }  // Prevent infinite recursion
    guard !visited.contains(ref) else { return nil }  // Circular reference
    visited.insert(ref)

    // Parse "#/components/schemas/Pet" -> ["components", "schemas", "Pet"]
    guard ref.hasPrefix("#/") else { return nil }  // External refs not supported
    let parts = ref.dropFirst(2).split(separator: "/").map(String.init)

    var current: Any = document
    for part in parts {
        guard let dict = current as? [String: Any],
              let next = dict[part] else { return nil }
        current = next
    }
    return current as? [String: Any]
}
```

### Pattern 4: Mock Response Generation from Schema

**What:** Generate realistic mock JSON response bodies from OpenAPI Schema Objects. Priority: (1) use `example` field if present, (2) use `enum` first value if present, (3) generate type-based defaults (`"string"` -> `"example"`, `integer` -> `0`, `boolean` -> `true`, `object` -> recursed properties, `array` -> one-item array).

**When to use:** For every imported endpoint's response body.

**Why this pattern:** The mock server needs to return something when an imported endpoint is hit. Schema-based generation produces realistic responses that match the API contract. Using `example` fields first respects the spec author's intent. Type-based fallbacks ensure every schema produces output.

**Example:**
```swift
enum MockResponseGenerator {
    static func generate(
        from schema: [String: Any],
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int = 0
    ) -> Any {
        guard depth < 10 else { return "..." }  // Depth limit

        // 1. Resolve $ref if present
        if let ref = schema["$ref"] as? String {
            guard let resolved = OpenAPIParser.resolveRef(ref, in: document, visited: &visited, depth: depth) else {
                return "{}"
            }
            return generate(from: resolved, in: document, visited: &visited, depth: depth + 1)
        }

        // 2. Use example if available
        if let example = schema["example"] { return example }

        // 3. Use first enum value if available
        if let enumValues = schema["enum"] as? [Any], let first = enumValues.first {
            return first
        }

        // 4. Type-based generation
        let type = schema["type"] as? String ?? "object"
        let format = schema["format"] as? String

        switch type {
        case "string":
            switch format {
            case "date": return "2024-01-01"
            case "date-time": return "2024-01-01T00:00:00Z"
            case "email": return "user@example.com"
            case "uuid": return "550e8400-e29b-41d4-a716-446655440000"
            case "uri", "url": return "https://example.com"
            default: return "string"
            }
        case "integer": return 0
        case "number": return 0.0
        case "boolean": return true
        case "array":
            if let items = schema["items"] as? [String: Any] {
                let item = generate(from: items, in: document, visited: &visited, depth: depth + 1)
                return [item]
            }
            return []
        case "object":
            var obj: [String: Any] = [:]
            if let properties = schema["properties"] as? [String: Any] {
                for (key, value) in properties {
                    if let propSchema = value as? [String: Any] {
                        obj[key] = generate(from: propSchema, in: document, visited: &visited, depth: depth + 1)
                    }
                }
            }
            return obj
        default:
            return "{}"
        }
    }

    static func generateJSON(from schema: [String: Any], in document: [String: Any]) -> String {
        var visited = Set<String>()
        let value = generate(from: schema, in: document, visited: &visited)
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
```

### Pattern 5: OpenAPI Path Parameter Conversion

**What:** Convert OpenAPI `{param}` path format to MockPad `:param` format.

**When to use:** During endpoint extraction, before creating `DiscoveredEndpoint`.

**Why this pattern:** OpenAPI uses `{id}` for path parameters. MockPad uses `:id`. This is a simple regex or string replacement. The existing `EndpointMatcher` and `PathParamReplacer` already handle the `:param` format.

**Example:**
```swift
// Within OpenAPIParser
private static func convertPathParams(_ path: String) -> String {
    // Replace {paramName} with :paramName
    var result = path
    let pattern = /\{([a-zA-Z_][a-zA-Z0-9_]*)\}/
    for match in path.matches(of: pattern) {
        result = result.replacingOccurrences(
            of: String(match.output.0),
            with: ":\(match.output.1)"
        )
    }
    return result
}
```

### Pattern 6: OpenAPI Preview Sheet with Select/Deselect and Warnings

**What:** A new `OpenAPIPreviewSheet` that shows discovered endpoints with checkboxes for select/deselect, warnings for unsupported features, and an import button. Feeds selected endpoints into `EndpointStore.importEndpoints()` as `ExportedEndpoint` DTOs.

**When to use:** After OpenAPI parsing, before import.

**Why this pattern:** The existing `ImportPreviewSheet` works for MockPad JSON format but does not support checkboxes or warnings. A new sheet is cleaner than overloading the existing one.

**Example flow:**
```
User taps "Import OpenAPI" menu item
  -> fileImporter presents file picker (JSON + YAML types)
  -> Security-scoped file access
  -> Data read from file
  -> OpenAPIParser.parse(data:) -> ParseResult
  -> OpenAPIPreviewSheet shown with endpoints and warnings
  -> User selects/deselects endpoints
  -> User taps "Import N Endpoints"
  -> PRO check via ProManager
  -> Convert DiscoveredEndpoint -> ExportedEndpoint
  -> EndpointStore.importEndpoints() for final insertion
  -> Dismiss sheet, sync engine
```

### Anti-Patterns to Avoid

- **Full OpenAPI spec compliance:** MockPad is a mock server, not an OpenAPI validator. Parse what we need (paths, operations, responses, schemas), warn on what we skip (allOf/oneOf, webhooks, callbacks, security schemes), and ignore the rest. Trying to model the full spec is months of work with diminishing returns.

- **Codable-only parsing for OpenAPI:** The OpenAPI spec has too many optional fields, extension keys (`x-*`), and polymorphic structures (`$ref` can appear anywhere) for clean Codable mapping. Use `JSONSerialization` -> `[String: Any]` and extract manually.

- **External `$ref` resolution:** References like `"./models/user.yaml"` point to other files. Supporting this requires recursive file I/O, path resolution, and security-scoped access to directories. Out of scope for v1. Only internal references (`#/...`) are supported.

- **Full YAML spec parser:** YAML has anchors, aliases, tags, flow mappings, multi-line literals, and other features that are complex to parse correctly. OpenAPI specs use a manageable subset. Building a full YAML parser is unnecessary and error-prone.

- **Modifying ImportPreviewSheet for both formats:** The existing sheet is tightly coupled to `MockPadExport` (collectionName, format validation). Building a separate `OpenAPIPreviewSheet` with checkboxes and warnings is cleaner than making one sheet serve two different import flows.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom JSON tokenizer | `JSONSerialization` / `JSONDecoder` | Foundation handles all JSON edge cases |
| File picker UI | Custom document browser | `fileImporter` SwiftUI modifier | Native, sandbox-aware, security-scoped |
| JSON pretty-printing | Manual string building | `JSONSerialization.data(withJSONObject:options:.prettyPrinted)` | Handles escaping, nesting, Unicode |
| Path parameter regex | Character-by-character scanner | Swift Regex (`/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/`) | Clean, readable, well-tested |
| Endpoint insertion | Direct SwiftData operations | `EndpointStore.importEndpoints()` | Already handles sort ordering, context save, duplicate resolution |

**Key insight:** The OpenAPI parsing and YAML conversion are the genuinely new work. Everything downstream (preview UI, endpoint creation, PRO gating, engine sync) reuses existing infrastructure.

## Common Pitfalls

### Pitfall 1: Circular `$ref` References Cause Infinite Recursion

**What goes wrong:** Schema A references Schema B which references Schema A. The parser recurses infinitely and crashes with stack overflow.

**Why it happens:** OpenAPI allows circular references (e.g., a `TreeNode` with a `children` property of type `[TreeNode]`). Without cycle detection, `$ref` resolution recurses forever.

**How to avoid:** Maintain a `visited: Set<String>` of resolved `$ref` paths. If a `$ref` has already been visited in the current resolution chain, return a placeholder value (empty object `{}` or `"..."`) instead of recursing. Also enforce a maximum depth limit (10-20 levels).

**Warning signs:** App hangs or crashes when importing specific OpenAPI specs. Stack overflow in debug console.

### Pitfall 2: YAML Indentation Parsing Edge Cases

**What goes wrong:** The YAML converter misparses specs with mixed indentation widths (2-space vs 4-space), inline comments, or multiline string values.

**Why it happens:** YAML's indentation semantics are complex. Different sections of the same file can use different indentation widths. Comments (`# ...`) can appear anywhere. Multiline strings use `|` or `>` indicators.

**How to avoid:** Count leading spaces per line. Track the indentation level of the current context (dictionary or array). Treat each line's indentation relative to its parent context, not as an absolute value. Strip inline comments. For multiline strings (`|` / `>`), collect subsequent indented lines until the indentation decreases. Test with real-world OpenAPI YAML files (Petstore, Stripe, etc.).

**Warning signs:** Parser produces empty or incorrect results for YAML files that work correctly in Swagger Editor.

### Pitfall 3: OpenAPI Response Status Code Selection

**What goes wrong:** The parser picks the wrong status code for the mock response (e.g., selects "default" or "4xx" instead of "200").

**Why it happens:** OpenAPI `responses` is a map with string keys like `"200"`, `"201"`, `"default"`, `"4xx"`. The keys are not sorted and there may not be a `"200"` entry. Different operations use different success codes (201 for POST, 204 for DELETE).

**How to avoid:** Priority order for selecting the "primary" response: (1) "200", (2) "201", (3) "204", (4) first 2xx code found, (5) "default". Parse the status code key as an integer. The `default` key is a catch-all.

**Warning signs:** All imported endpoints have status code 0, or all have the error response instead of the success response.

### Pitfall 4: YAML Not Detected When Extension Is Wrong

**What goes wrong:** User selects a YAML file with `.txt` or no extension. The parser tries JSON first, fails, and shows an error instead of trying YAML.

**Why it happens:** Detection relies solely on file extension.

**How to avoid:** Try JSON first (`JSONSerialization`). If it fails, try YAML conversion regardless of file extension. This auto-detection approach handles all cases.

**Warning signs:** "Invalid file format" error when importing valid YAML with unexpected extension.

### Pitfall 5: `$ref` to Non-Schema Components

**What goes wrong:** The parser only resolves `$ref` to `#/components/schemas/...` but the spec uses `$ref` to `#/components/responses/...` or `#/components/parameters/...`.

**Why it happens:** OpenAPI uses `$ref` at multiple levels: response objects, parameter objects, request body objects, not just schemas.

**How to avoid:** The `$ref` resolver should be generic -- it walks the document tree by the JSON Pointer path regardless of what it points to. The resolver does not need to know whether it is resolving a schema, response, or parameter. It just follows the path and returns whatever dictionary it finds.

**Warning signs:** Imported endpoints have empty responses for specs that use `$ref` in their `responses` section.

### Pitfall 6: OpenAPI YAML with Flow Collections

**What goes wrong:** The YAML converter fails on lines like `required: [id, name]` or `enum: [active, inactive]` because it does not handle inline JSON-like syntax.

**Why it happens:** YAML supports "flow collections" which are JSON-like inline arrays `[a, b]` and objects `{a: 1, b: 2}`. These are common in OpenAPI YAML for `required`, `enum`, and `tags` fields.

**How to avoid:** Detect flow collection syntax (value starts with `[` or `{`) and parse it as inline JSON using `JSONSerialization`. This avoids building a full flow collection parser.

**Warning signs:** Arrays like `required` and `enum` are parsed as single string values instead of arrays.

### Pitfall 7: PRO Gating Not Applied to OpenAPI Import

**What goes wrong:** Free-tier users import OpenAPI specs without hitting the PRO paywall, bypassing the feature gate.

**Why it happens:** OpenAPI import is listed as a PRO feature (IMPT-01, IMPT-02) but the import flow does not check `proManager.isPro`.

**How to avoid:** Gate the "Import OpenAPI" menu item behind `proManager.isPro`. Show PRO alert if tapped by free user. Additionally, after parsing, check `proManager.canImportEndpoints(currentCount:importCount:)` before allowing the import.

**Warning signs:** Free users can import unlimited endpoints via OpenAPI specs.

## Code Examples

Verified patterns from project conventions and domain research:

### Endpoint Extraction from OpenAPI Paths

```swift
// Source: OpenAPI 3.0 Specification paths structure
private static func extractEndpoints(
    from document: [String: Any]
) -> [DiscoveredEndpoint] {
    guard let paths = document["paths"] as? [String: Any] else { return [] }

    let httpMethods = ["get", "post", "put", "patch", "delete", "head", "options"]
    var endpoints: [DiscoveredEndpoint] = []

    for (path, pathItemAny) in paths {
        guard let pathItem = pathItemAny as? [String: Any] else { continue }

        for method in httpMethods {
            guard let operation = pathItem[method] as? [String: Any] else { continue }

            let summary = operation["summary"] as? String
                       ?? operation["description"] as? String

            // Find best response
            let (statusCode, schema) = selectBestResponse(
                from: operation["responses"] as? [String: Any] ?? [:],
                in: document
            )

            // Generate mock response body
            let responseBody: String
            if let schema = schema {
                responseBody = MockResponseGenerator.generateJSON(
                    from: schema, in: document
                )
            } else {
                responseBody = "{}"
            }

            // Convert path params: {id} -> :id
            let convertedPath = convertPathParams(path)

            // Collect warnings
            var warnings: [String] = []
            if let _ = operation["callbacks"] { warnings.append("Callbacks not supported") }
            if let _ = operation["security"] { warnings.append("Security schemes ignored") }

            endpoints.append(DiscoveredEndpoint(
                path: convertedPath,
                httpMethod: method.uppercased(),
                summary: summary,
                responseStatusCode: statusCode,
                responseBody: responseBody,
                responseHeaders: ["Content-Type": "application/json"]
            ))
        }
    }

    return endpoints
}
```

### Best Response Selection

```swift
// Source: OpenAPI 3.0 Responses Object structure
private static func selectBestResponse(
    from responses: [String: Any],
    in document: [String: Any]
) -> (statusCode: Int, schema: [String: Any]?) {
    // Priority: 200 > 201 > 204 > first 2xx > default
    let priorities = ["200", "201", "204"]

    for code in priorities {
        if let response = resolveResponse(responses[code], in: document) {
            let schema = extractSchema(from: response, in: document)
            return (Int(code) ?? 200, schema)
        }
    }

    // Find first 2xx
    for (code, responseAny) in responses.sorted(by: { $0.key < $1.key }) {
        if code.hasPrefix("2"), let statusCode = Int(code) {
            let response = resolveResponse(responseAny, in: document)
            let schema = response.flatMap { extractSchema(from: $0, in: document) }
            return (statusCode, schema)
        }
    }

    // Fall back to default
    if let response = resolveResponse(responses["default"], in: document) {
        let schema = extractSchema(from: response, in: document)
        return (200, schema)
    }

    return (200, nil)
}

private static func extractSchema(
    from response: [String: Any],
    in document: [String: Any]
) -> [String: Any]? {
    guard let content = response["content"] as? [String: Any] else { return nil }
    // Prefer application/json
    let mediaType = content["application/json"] as? [String: Any]
                 ?? content.values.first as? [String: Any]
    return mediaType?["schema"] as? [String: Any]
}
```

### Converting DiscoveredEndpoint to ExportedEndpoint for Import

```swift
// Source: Existing ExportedEndpoint from MockPadExportModels.swift
extension OpenAPIParser.DiscoveredEndpoint {
    func toExportedEndpoint() -> ExportedEndpoint {
        ExportedEndpoint(
            path: path,
            httpMethod: httpMethod,
            responseStatusCode: responseStatusCode,
            responseBody: responseBody,
            responseHeaders: responseHeaders,
            isEnabled: true,
            responseDelayMs: 0
        )
    }
}
```

### Minimal YAML Key-Value Parsing (Core Logic)

```swift
// Source: YAML spec subset analysis for OpenAPI files
private static func parseLine(_ line: String) -> (indent: Int, key: String?, value: Any?, isArrayItem: Bool) {
    let stripped = line.replacingOccurrences(of: "\t", with: "  ")
    let indent = stripped.prefix(while: { $0 == " " }).count
    let trimmed = String(stripped.dropFirst(indent))

    // Strip inline comments (not inside quotes)
    let content = stripComment(trimmed)
    guard !content.isEmpty else { return (indent, nil, nil, false) }

    let isArrayItem = content.hasPrefix("- ")
    let itemContent = isArrayItem ? String(content.dropFirst(2)) : content

    // Key: value pair
    if let colonIndex = itemContent.firstIndex(of: ":") {
        let key = String(itemContent[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let afterColon = String(itemContent[itemContent.index(after: colonIndex)...])
            .trimmingCharacters(in: .whitespaces)

        if afterColon.isEmpty {
            return (indent, key, nil, isArrayItem)  // Nested object follows
        }
        return (indent, key, parseScalar(afterColon), isArrayItem)
    }

    // Bare scalar (array item value)
    return (indent, nil, parseScalar(itemContent), isArrayItem)
}

private static func parseScalar(_ value: String) -> Any {
    // Quoted string
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
       (value.hasPrefix("'") && value.hasSuffix("'")) {
        return String(value.dropFirst().dropLast())
    }
    // Flow collection (inline JSON array/object)
    if value.hasPrefix("[") || value.hasPrefix("{") {
        if let data = value.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) {
            return parsed
        }
    }
    // Boolean
    if value == "true" || value == "True" || value == "TRUE" { return true }
    if value == "false" || value == "False" || value == "FALSE" { return false }
    // Null
    if value == "null" || value == "~" || value == "Null" || value == "NULL" { return NSNull() }
    // Integer
    if let intVal = Int(value) { return intVal }
    // Float
    if let doubleVal = Double(value), value.contains(".") { return doubleVal }
    // Default: unquoted string
    return value
}
```

### Unsupported Feature Detection

```swift
// Source: OpenAPI 3.0 spec features outside MockPad scope
private static func detectWarnings(in document: [String: Any]) -> [String] {
    var warnings: [String] = []

    // Global warnings
    if let components = document["components"] as? [String: Any] {
        if let schemas = components["schemas"] as? [String: Any] {
            for (name, schemaAny) in schemas {
                if let schema = schemaAny as? [String: Any] {
                    if schema["allOf"] != nil { warnings.append("Schema '\(name)' uses allOf (simplified)") }
                    if schema["oneOf"] != nil { warnings.append("Schema '\(name)' uses oneOf (first option used)") }
                    if schema["anyOf"] != nil { warnings.append("Schema '\(name)' uses anyOf (first option used)") }
                    if schema["discriminator"] != nil { warnings.append("Schema '\(name)' uses discriminator (ignored)") }
                }
            }
        }
        if components["callbacks"] != nil { warnings.append("Callbacks not supported") }
        if components["securitySchemes"] != nil { warnings.append("Security schemes ignored") }
    }
    if document["webhooks"] != nil { warnings.append("Webhooks not supported") }

    return warnings
}
```

### fileImporter with JSON + YAML UTTypes

```swift
// Source: Apple docs + UTType for YAML research
.fileImporter(
    isPresented: $showOpenAPIImporter,
    allowedContentTypes: [
        .json,
        UTType(filenameExtension: "yaml") ?? .plainText,
        UTType(filenameExtension: "yml") ?? .plainText
    ],
    allowsMultipleSelection: false
) { result in
    guard let url = (try? result.get())?.first else { return }
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    do {
        let data = try Data(contentsOf: url)
        let parseResult = try OpenAPIParser.parse(data: data)
        pendingOpenAPIImport = parseResult
        showOpenAPIPreview = true
    } catch {
        importError = error.localizedDescription
        showImportError = true
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OpenAPI 2.0 (Swagger) | OpenAPI 3.0.x / 3.1.x | 2017-2021 | 3.0 restructured paths/responses with `content` media type map. 3.1 aligned with JSON Schema 2020-12. MockPad targets 3.0.x for maximum compatibility. |
| Full spec parser libraries | Lightweight partial parsers for specific use cases | Ongoing | Full parsers (OpenAPIKit, swift-openapi-generator) are overkill for mock server import. Partial parsing extracts only what is needed. |
| External YAML libraries required | JSON-first with YAML fallback | Ongoing | JSON OpenAPI files are increasingly common. Many tools output JSON. YAML support is nice-to-have but JSON covers the majority of use cases. |

**Deprecated/outdated:**
- OpenAPI 2.0 (Swagger): Still in use but OpenAPI 3.0+ is the standard. MockPad should only support 3.0.x (`"openapi": "3.0.*"`). Detecting and rejecting 2.0 (`"swagger": "2.0"`) with a clear error message is good UX.
- Yams for YAML parsing: Not deprecated but not usable in this project due to zero-dependencies constraint. The PROJECT.md key decision explicitly chose "Minimal YAML parser."

## Open Questions

1. **How much of allOf/oneOf should be supported vs warned?**
   - What we know: `allOf` is commonly used for inheritance (merge base + extension schemas). `oneOf` is used for polymorphism (pick one variant). Both are prevalent in real-world OpenAPI specs.
   - What's unclear: Whether ignoring them entirely produces usable mock responses, or if a minimal `allOf` merge (combine all properties from all sub-schemas) would be worth the complexity.
   - Recommendation: Implement basic `allOf` support (merge properties from all sub-schemas into one object) since it is very common and mechanically simple. For `oneOf`/`anyOf`, use the first option. Show warnings in preview for all three. This provides 80%+ coverage with minimal code.

2. **Should the preview sheet allow editing the generated response body?**
   - What we know: The generated mock response may not match what the user wants. After import, the user can edit via EndpointEditorView.
   - What's unclear: Whether editing during preview is worth the UI complexity.
   - Recommendation: No editing in preview. Show the generated response as read-only. Users edit after import via the existing EndpointEditorView. This keeps the preview sheet focused on select/deselect and warnings.

3. **How should the collection name be determined for imported OpenAPI endpoints?**
   - What we know: OpenAPI specs have an `info.title` field (e.g., "Petstore API"). This is a natural collection name.
   - What's unclear: Whether users want the API title as the collection name or prefer to choose.
   - Recommendation: Default the collection name to `info.title` from the spec. Show it in the preview sheet. The user can change it after import via EndpointEditorView. This provides sensible defaults without adding UI complexity.

4. **What is the YAML subset coverage target?**
   - What we know: OpenAPI YAML uses block mappings, block sequences, scalars, flow collections (inline `[a, b]` and `{a: b}`), and occasionally multiline strings (`|`/`>`).
   - What's unclear: How many real-world OpenAPI YAML files use features beyond this subset (anchors, tags, complex multi-line).
   - Recommendation: Support block mappings, block sequences, scalars (string/int/float/bool/null), quoted strings, flow collections (parse via `JSONSerialization`), and inline comments. Warn on unsupported YAML features. This covers 90%+ of real-world OpenAPI YAML files. Users with complex YAML can convert to JSON online.

## Sources

### Primary (HIGH confidence)
- [OpenAPI Specification v3.0.3](https://spec.openapis.org/oas/v3.0.3.html) -- Official spec, document structure, Schema Object, Reference Object, all field definitions
- [JSON Schema for OpenAPI 3.0](https://spec.openapis.org/oas/3.0/schema/2024-10-18.html) -- Machine-readable schema definition
- Project codebase: `CollectionImporter.swift`, `MockPadExportModels.swift`, `ImportPreviewSheet.swift`, `EndpointListView.swift` -- existing import infrastructure patterns
- Project codebase: `PathParamReplacer.swift`, `EndpointMatcher.swift` -- `:param` format handling, caseless enum service pattern
- Project codebase: `ProManager.swift`, `EndpointStore.swift` -- PRO gating, endpoint insertion
- Project `PROJECT.md` Key Decisions: "Minimal YAML parser: Best-effort for OpenAPI YAML; JSON fully supported, YAML is fallback" -- zero dependencies constraint confirmed

### Secondary (MEDIUM confidence)
- [Swagger: oneOf, anyOf, allOf, not](https://swagger.io/docs/specification/v3_0/data-models/oneof-anyof-allof-not/) -- Composition keyword semantics and examples
- [Swagger: Inheritance & Polymorphism](https://swagger.io/docs/specification/v3_0/data-models/inheritance-and-polymorphism/) -- `discriminator` usage patterns
- [pb33f: Circular References in OpenAPI](https://pb33f.io/libopenapi/circular-references/) -- Circular `$ref` detection strategies, depth limits
- [MockServer: Using OpenAPI Specifications](https://www.mock-server.com/mock_server/using_openapi.html) -- Mock response generation from schema priority (example > schema > type-based)
- [Tyk: Mock Responses using OpenAPI Metadata](https://tyk.io/docs/5.6/product-stack/tyk-gateway/middleware/mock-response-openapi/) -- Schema-to-mock generation strategy (example > schema properties > type defaults)
- [Apple Developer Forums: UTType for YAML](https://developer.apple.com/forums/thread/688402) -- `UTType(filenameExtension:)` approach for non-standard file types
- [Yams GitHub](https://github.com/jpsim/Yams) -- Yams API confirmed (YAMLDecoder, Codable support); NOT used due to zero-dependencies constraint

### Tertiary (LOW confidence)
- [Build Your Own YAML Parser](https://codingchallenges.fyi/challenges/challenge-yaml/) -- General YAML parser building approach; needs validation with real OpenAPI YAML files
- [marcprux/universal](https://github.com/marcprux/universal) -- Zero-dependency YAML parser reference; NOT used but confirms approach feasibility

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All Apple-native frameworks. Zero new dependencies. Well-documented APIs.
- Architecture: HIGH -- Extends established project patterns (caseless enum services, ImportPreviewSheet, ExportedEndpoint DTOs, EndpointStore.importEndpoints). New services follow existing conventions.
- Pitfalls: HIGH -- Circular `$ref` and YAML parsing are well-documented challenges. Response status code selection and unsupported feature warnings are specific to OpenAPI domain. All pitfalls verified across multiple sources.
- YAML converter: MEDIUM -- Hand-rolling a YAML subset parser is feasible but the edge cases (flow collections, multiline strings, inline comments) need thorough testing with real-world OpenAPI YAML files. This is the highest-risk component.
- Mock response generation: HIGH -- Schema-to-mock generation is well-understood (example > enum > type-based defaults). Multiple mock server tools document this priority order.

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (OpenAPI 3.0 is stable; YAML subset is stable; Apple frameworks are stable)
