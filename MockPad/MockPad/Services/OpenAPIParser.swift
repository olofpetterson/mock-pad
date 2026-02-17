//
//  OpenAPIParser.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

/// Parses OpenAPI 3.x specifications (JSON or YAML) into structured results
/// with discovered endpoints and warnings.
/// Caseless enum service pattern -- all methods are static.
enum OpenAPIParser {

    // MARK: - Error Types

    enum ParseError: Error, LocalizedError, Equatable {
        case invalidJSON(String)
        case notOpenAPI
        case unsupportedVersion(String)
        case noPaths

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let detail):
                "Invalid file: \(detail)"
            case .notOpenAPI:
                "Not an OpenAPI specification"
            case .unsupportedVersion(let version):
                "Unsupported OpenAPI version: \(version)"
            case .noPaths:
                "No API paths found in specification"
            }
        }
    }

    // MARK: - Result Types

    struct DiscoveredEndpoint {
        let path: String
        let httpMethod: String
        let summary: String?
        let responseStatusCode: Int
        let responseBody: String
        let responseHeaders: [String: String]
        var isSelected: Bool
        var warnings: [String]
    }

    struct ParseResult {
        let title: String
        let version: String
        let endpoints: [DiscoveredEndpoint]
        let globalWarnings: [String]
    }

    // MARK: - Public API

    /// Parse OpenAPI spec from raw Data (JSON or YAML).
    /// Tries JSON first, falls back to YAML conversion via YAMLConverter.
    static func parse(data: Data) throws -> ParseResult {
        let document = try parseDocument(data: data)

        // Validate OpenAPI version
        try validateVersion(document)

        // Extract info
        let info = document["info"] as? [String: Any] ?? [:]
        let title = info["title"] as? String ?? "Untitled API"
        let version = info["version"] as? String ?? "0.0.0"

        // Extract paths
        guard let paths = document["paths"] as? [String: Any], !paths.isEmpty else {
            throw ParseError.noPaths
        }

        // Extract endpoints
        let endpoints = extractEndpoints(from: paths, in: document)

        // Collect global warnings
        let globalWarnings = detectWarnings(in: document)

        return ParseResult(
            title: title,
            version: version,
            endpoints: endpoints,
            globalWarnings: globalWarnings
        )
    }

    // MARK: - Document Parsing

    private static func parseDocument(data: Data) throws -> [String: Any] {
        // Try JSON first
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let dict = jsonObject as? [String: Any] {
            return dict
        }

        // Fall back to YAML conversion
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ParseError.invalidJSON("Unable to read file as text")
        }

        do {
            let jsonData = try YAMLConverter.toJSON(yamlString)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return jsonObject
            }
            throw ParseError.invalidJSON("YAML conversion produced non-object result")
        } catch is YAMLConverter.ConversionError {
            throw ParseError.invalidJSON("Not valid JSON or YAML")
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError.invalidJSON(error.localizedDescription)
        }
    }

    // MARK: - Version Validation

    private static func validateVersion(_ document: [String: Any]) throws {
        guard let version = document["openapi"] as? String else {
            // Check for Swagger 2.0
            if document["swagger"] as? String != nil {
                throw ParseError.unsupportedVersion("2.0 (Swagger)")
            }
            throw ParseError.notOpenAPI
        }

        guard version.hasPrefix("3.") else {
            throw ParseError.unsupportedVersion(version)
        }
    }

    // MARK: - Endpoint Extraction

    private static let httpMethods = ["get", "post", "put", "patch", "delete", "head", "options"]

    private static func extractEndpoints(
        from paths: [String: Any],
        in document: [String: Any]
    ) -> [DiscoveredEndpoint] {
        var endpoints: [DiscoveredEndpoint] = []

        for (path, pathItemAny) in paths.sorted(by: { $0.key < $1.key }) {
            guard let pathItem = pathItemAny as? [String: Any] else { continue }

            for method in httpMethods {
                guard let operation = pathItem[method] as? [String: Any] else { continue }

                let summary = operation["summary"] as? String
                    ?? operation["description"] as? String

                // Find best response
                let responses = operation["responses"] as? [String: Any] ?? [:]
                let (statusCode, schema) = selectBestResponse(from: responses, in: document)

                // Generate mock response body
                let responseBody: String
                if let schema = schema {
                    responseBody = MockResponseGenerator.generateJSON(from: schema, in: document)
                } else {
                    responseBody = "{}"
                }

                // Convert path params: {id} -> :id
                let convertedPath = convertPathParams(path)

                // Collect per-endpoint warnings
                var warnings: [String] = []
                if operation["callbacks"] != nil {
                    warnings.append("Callbacks not supported")
                }
                if operation["security"] != nil {
                    warnings.append("Security schemes ignored")
                }

                endpoints.append(DiscoveredEndpoint(
                    path: convertedPath,
                    httpMethod: method.uppercased(),
                    summary: summary,
                    responseStatusCode: statusCode,
                    responseBody: responseBody,
                    responseHeaders: ["Content-Type": "application/json"],
                    isSelected: true,
                    warnings: warnings
                ))
            }
        }

        return endpoints
    }

    // MARK: - Response Selection

    /// Select the best response from an operation's responses map.
    /// Priority: 200 > 201 > 204 > first 2xx > default.
    private static func selectBestResponse(
        from responses: [String: Any],
        in document: [String: Any]
    ) -> (statusCode: Int, schema: [String: Any]?) {
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

    /// Resolve a response object that may be a $ref.
    private static func resolveResponse(_ value: Any?, in document: [String: Any]) -> [String: Any]? {
        guard let value = value else { return nil }

        if let dict = value as? [String: Any] {
            if let ref = dict["$ref"] as? String {
                var visited = Set<String>()
                return MockResponseGenerator.resolveRef(ref, in: document, visited: &visited, depth: 0)
            }
            return dict
        }

        return nil
    }

    /// Extract schema from a response object's content.
    /// Prefers application/json, falls back to first media type.
    private static func extractSchema(
        from response: [String: Any],
        in document: [String: Any]
    ) -> [String: Any]? {
        guard let content = response["content"] as? [String: Any] else { return nil }

        let mediaType = content["application/json"] as? [String: Any]
            ?? content.values.first as? [String: Any]

        return mediaType?["schema"] as? [String: Any]
    }

    // MARK: - Path Parameter Conversion

    /// Convert OpenAPI {param} path format to MockPad :param format.
    private static func convertPathParams(_ path: String) -> String {
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

    // MARK: - Warning Detection

    /// Detect unsupported features in the document and collect warnings.
    private static func detectWarnings(in document: [String: Any]) -> [String] {
        var warnings: [String] = []

        // Check for webhooks
        if document["webhooks"] != nil {
            warnings.append("Webhooks not supported")
        }

        // Check components
        if let components = document["components"] as? [String: Any] {
            // Security schemes
            if components["securitySchemes"] != nil {
                warnings.append("Security schemes ignored")
            }

            // Schema composition warnings
            if let schemas = components["schemas"] as? [String: Any] {
                for (name, schemaAny) in schemas.sorted(by: { $0.key < $1.key }) {
                    if let schema = schemaAny as? [String: Any] {
                        if schema["allOf"] != nil {
                            warnings.append("Schema '\(name)' uses allOf (simplified)")
                        }
                        if schema["oneOf"] != nil {
                            warnings.append("Schema '\(name)' uses oneOf (first option used)")
                        }
                        if schema["anyOf"] != nil {
                            warnings.append("Schema '\(name)' uses anyOf (first option used)")
                        }
                        if schema["discriminator"] != nil {
                            warnings.append("Schema '\(name)' uses discriminator (ignored)")
                        }
                    }
                }
            }

            // Callbacks at component level
            if components["callbacks"] != nil {
                warnings.append("Callbacks not supported")
            }
        }

        return warnings
    }
}
