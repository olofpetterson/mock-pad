//
//  HTTPRequestParser.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Pure HTTP request parser. Caseless enum with nonisolated static methods
/// callable from any actor context (MainActor or MockServerEngine actor).
enum HTTPRequestParser {

    /// Parsed HTTP request data. Sendable for cross-actor transfer.
    struct ParsedRequest: Sendable {
        let method: String
        let path: String
        let queryString: String?
        let httpVersion: String
        let headers: [String: String]
        let body: String?
    }

    /// Parse raw HTTP request data into a structured ParsedRequest.
    /// Returns nil for malformed or empty input.
    nonisolated static func parse(data: Data) -> ParsedRequest? {
        guard !data.isEmpty,
              let rawString = String(data: data, encoding: .utf8),
              !rawString.isEmpty else {
            return nil
        }

        // Split headers from body at double CRLF
        let parts = rawString.components(separatedBy: "\r\n\r\n")
        guard let headerSection = parts.first, !headerSection.isEmpty else {
            return nil
        }

        // Body is everything after the first \r\n\r\n delimiter
        let body: String? = if parts.count > 1 {
            {
                let joined = parts.dropFirst().joined(separator: "\r\n\r\n")
                return joined.isEmpty ? nil : joined
            }()
        } else {
            nil
        }

        // Parse request line: "GET /api/users?page=1 HTTP/1.1"
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count >= 2 else {
            return nil
        }

        let method = String(requestParts[0])
        let fullPath = String(requestParts[1])
        let httpVersion = requestParts.count >= 3 ? String(requestParts[2]) : "HTTP/1.1"

        // Validate it looks like an HTTP request line
        guard method.allSatisfy({ $0.isUppercase || $0.isNumber }),
              fullPath.hasPrefix("/") else {
            return nil
        }

        // Separate path from query string
        let pathComponents = fullPath.components(separatedBy: "?")
        let path = pathComponents[0]
        let queryString: String? = if pathComponents.count > 1 {
            pathComponents.dropFirst().joined(separator: "?")
        } else {
            nil
        }

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { break }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = String(headerParts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return ParsedRequest(
            method: method,
            path: path,
            queryString: queryString,
            httpVersion: httpVersion,
            headers: headers,
            body: body
        )
    }

    /// Parse query string into key-value dictionary.
    /// Handles percent-encoded values.
    nonisolated static func parseQueryString(_ queryString: String?) -> [String: String] {
        guard let queryString, !queryString.isEmpty else { return [:] }
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                params[key] = value
            } else if kv.count == 1 {
                params[String(kv[0])] = ""
            }
        }
        return params
    }
}
