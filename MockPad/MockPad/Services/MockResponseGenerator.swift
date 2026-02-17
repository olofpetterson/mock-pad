//
//  MockResponseGenerator.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

/// Generates mock JSON response bodies from OpenAPI Schema Objects.
/// Caseless enum service pattern -- all methods are static.
enum MockResponseGenerator {

    private static let maxDepth = 20

    /// Generate a mock JSON string from an OpenAPI schema object.
    /// Returns pretty-printed JSON with sorted keys.
    static func generateJSON(from schema: [String: Any], in document: [String: Any]) -> String {
        var visited = Set<String>()
        let value = generate(from: schema, in: document, visited: &visited, depth: 0)

        // Wrap scalars in a serializable form if needed
        if JSONSerialization.isValidJSONObject(value) {
            guard let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys]
            ), let json = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return json
        }

        // Scalar value -- serialize as a JSON fragment
        if let stringVal = value as? String {
            // Wrap in quotes for valid JSON
            let escaped = stringVal
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        if let intVal = value as? Int {
            return "\(intVal)"
        }
        if let doubleVal = value as? Double {
            return "\(doubleVal)"
        }
        if let boolVal = value as? Bool {
            return boolVal ? "true" : "false"
        }

        return "{}"
    }

    /// Generate a mock value (Any) from an OpenAPI schema object.
    /// `visited` tracks $ref paths to prevent circular reference loops.
    /// `depth` prevents deeply nested schemas from infinite recursion.
    static func generate(
        from schema: [String: Any],
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> Any {
        guard depth < maxDepth else { return "..." }

        // 1. Resolve $ref if present
        if let ref = schema["$ref"] as? String {
            return resolveAndGenerate(ref: ref, in: document, visited: &visited, depth: depth)
        }

        // 2. Handle allOf -- merge properties from all sub-schemas
        if let allOf = schema["allOf"] as? [[String: Any]] {
            return generateAllOf(allOf, in: document, visited: &visited, depth: depth)
        }

        // 3. Handle oneOf -- use first option
        if let oneOf = schema["oneOf"] as? [[String: Any]], let first = oneOf.first {
            return generate(from: first, in: document, visited: &visited, depth: depth + 1)
        }

        // 4. Handle anyOf -- use first option
        if let anyOf = schema["anyOf"] as? [[String: Any]], let first = anyOf.first {
            return generate(from: first, in: document, visited: &visited, depth: depth + 1)
        }

        // 5. Use example if available (priority over type-based generation)
        if let example = schema["example"] {
            return example
        }

        // 6. Use first enum value if available
        if let enumValues = schema["enum"] as? [Any], let first = enumValues.first {
            return first
        }

        // 7. Type-based generation
        let type = schema["type"] as? String
        let format = schema["format"] as? String

        switch type {
        case "string":
            return generateString(format: format)
        case "integer":
            return 0
        case "number":
            return 0.0
        case "boolean":
            return true
        case "array":
            return generateArray(schema: schema, in: document, visited: &visited, depth: depth)
        case "object":
            return generateObject(schema: schema, in: document, visited: &visited, depth: depth)
        case nil:
            // No type field -- if properties exist, treat as object
            if schema["properties"] != nil {
                return generateObject(schema: schema, in: document, visited: &visited, depth: depth)
            }
            return [String: Any]()
        default:
            return [String: Any]()
        }
    }

    // MARK: - Private Helpers

    private static func generateString(format: String?) -> String {
        switch format {
        case "date":
            return "2024-01-01"
        case "date-time":
            return "2024-01-01T00:00:00Z"
        case "email":
            return "user@example.com"
        case "uuid":
            return "550e8400-e29b-41d4-a716-446655440000"
        case "uri", "url":
            return "https://example.com"
        default:
            return "string"
        }
    }

    private static func generateArray(
        schema: [String: Any],
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> [Any] {
        if let items = schema["items"] as? [String: Any] {
            let item = generate(from: items, in: document, visited: &visited, depth: depth + 1)
            return [item]
        }
        return []
    }

    private static func generateObject(
        schema: [String: Any],
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> [String: Any] {
        var obj: [String: Any] = [:]
        if let properties = schema["properties"] as? [String: Any] {
            for (key, value) in properties {
                if let propSchema = value as? [String: Any] {
                    obj[key] = generate(from: propSchema, in: document, visited: &visited, depth: depth + 1)
                }
            }
        }
        return obj
    }

    private static func generateAllOf(
        _ schemas: [[String: Any]],
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> [String: Any] {
        var merged: [String: Any] = [:]
        for subSchema in schemas {
            // Resolve $ref in allOf items
            let resolved: [String: Any]
            if let ref = subSchema["$ref"] as? String {
                resolved = resolveRef(ref, in: document, visited: &visited, depth: depth) ?? [:]
            } else {
                resolved = subSchema
            }

            // Merge properties from each sub-schema
            if let properties = resolved["properties"] as? [String: Any] {
                for (key, value) in properties {
                    if let propSchema = value as? [String: Any] {
                        merged[key] = generate(from: propSchema, in: document, visited: &visited, depth: depth + 1)
                    }
                }
            }
        }
        return merged
    }

    private static func resolveAndGenerate(
        ref: String,
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> Any {
        guard let resolved = resolveRef(ref, in: document, visited: &visited, depth: depth) else {
            return "..."
        }
        return generate(from: resolved, in: document, visited: &visited, depth: depth + 1)
    }

    /// Resolve a $ref JSON Pointer reference within the document.
    /// Only internal refs (#/...) are supported. External refs return nil.
    /// Guards against circular refs via `visited` set and depth limit.
    static func resolveRef(
        _ ref: String,
        in document: [String: Any],
        visited: inout Set<String>,
        depth: Int
    ) -> [String: Any]? {
        guard depth < maxDepth else { return nil }
        guard !visited.contains(ref) else { return nil }
        guard ref.hasPrefix("#/") else { return nil }

        visited.insert(ref)

        let parts = ref.dropFirst(2).split(separator: "/").map(String.init)

        var current: Any = document
        for part in parts {
            guard let dict = current as? [String: Any],
                  let next = dict[part] else { return nil }
            current = next
        }
        return current as? [String: Any]
    }
}
