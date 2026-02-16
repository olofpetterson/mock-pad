//
//  HTTPResponseBuilder.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Pure HTTP response builder. Caseless enum with nonisolated static methods
/// callable from any actor context (MainActor or MockServerEngine actor).
enum HTTPResponseBuilder {

    /// Build a complete HTTP/1.1 response as Data.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code (200, 404, etc.)
    ///   - headers: Custom response headers (user headers can override defaults)
    ///   - body: Response body string
    ///   - corsEnabled: Whether to include CORS headers
    /// - Returns: Complete HTTP response as Data
    nonisolated static func build(
        statusCode: Int,
        headers: [String: String] = [:],
        body: String = "",
        corsEnabled: Bool = true
    ) -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusPhrase(statusCode))\r\n"

        var allHeaders = headers
        allHeaders["Server"] = allHeaders["Server"] ?? "MockPad/1.0"
        allHeaders["Date"] = allHeaders["Date"] ?? httpDateString()
        allHeaders["Content-Length"] = String(body.utf8.count)
        allHeaders["Connection"] = "close"

        if corsEnabled {
            allHeaders["Access-Control-Allow-Origin"] =
                allHeaders["Access-Control-Allow-Origin"] ?? "*"
            allHeaders["Access-Control-Allow-Methods"] =
                allHeaders["Access-Control-Allow-Methods"] ?? "GET, POST, PUT, DELETE, PATCH, OPTIONS"
            allHeaders["Access-Control-Allow-Headers"] =
                allHeaders["Access-Control-Allow-Headers"] ?? "Content-Type, Authorization, Accept"
        }

        // Sort headers for deterministic output (helps testing)
        for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            response += "\(key): \(value)\r\n"
        }

        response += "\r\n"
        response += body

        return Data(response.utf8)
    }

    /// Build an HTTP 204 preflight response with CORS headers.
    ///
    /// - Parameter corsEnabled: Whether to include CORS headers (typically always true for preflight)
    /// - Returns: Complete HTTP preflight response as Data
    nonisolated static func buildPreflightResponse(corsEnabled: Bool) -> Data {
        build(
            statusCode: 204,
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept",
                "Access-Control-Max-Age": "86400"
            ],
            body: "",
            corsEnabled: corsEnabled
        )
    }

    /// Map HTTP status code to reason phrase.
    nonisolated private static func statusPhrase(_ code: Int) -> String {
        switch code {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        default: "Unknown"
        }
    }

    /// Format current date as HTTP Date header value (RFC 7231).
    nonisolated private static func httpDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: Date()) + " GMT"
    }
}
