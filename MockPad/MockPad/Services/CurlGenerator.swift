//
//  CurlGenerator.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Generates cURL command strings from HTTP request data.
/// Caseless enum with nonisolated static method callable from any actor context.
enum CurlGenerator {

    /// Generate a cURL command string from request components.
    ///
    /// - Parameters:
    ///   - method: HTTP method (e.g., "GET", "POST")
    ///   - path: Request path (e.g., "/api/users")
    ///   - headers: Request headers dictionary
    ///   - body: Request body string, if any
    ///   - baseURL: Server base URL (e.g., "http://localhost:8080")
    /// - Returns: A formatted cURL command string
    nonisolated static func generate(
        method: String,
        path: String,
        headers: [String: String],
        body: String?,
        baseURL: String
    ) -> String {
        var parts = ["curl"]

        // Only include -X flag for non-GET methods (GET is curl's default)
        if method.uppercased() != "GET" {
            parts.append("-X \(method.uppercased())")
        }

        // Single-quoted URL
        parts.append("'\(baseURL)\(path)'")

        // Headers sorted alphabetically by key for deterministic output
        for key in headers.keys.sorted() {
            let value = headers[key]!
            parts.append("-H '\(key): \(value)'")
        }

        // Body with single quote escaping
        if let body, !body.isEmpty {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escaped)'")
        }

        return parts.joined(separator: " \\\n  ")
    }
}
