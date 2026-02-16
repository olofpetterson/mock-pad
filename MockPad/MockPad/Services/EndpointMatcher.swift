//
//  EndpointMatcher.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Pure endpoint matcher. Caseless enum with nonisolated static methods
/// callable from any actor context (MainActor or MockServerEngine actor).
///
/// Phase 2: EXACT path matching only. Path parameters (:id) and
/// wildcards (*) are Phase 6.
enum EndpointMatcher {

    /// Result of matching a request to an endpoint.
    enum MatchResult: Sendable {
        case matched(path: String, method: String, statusCode: Int,
                     responseBody: String, responseHeaders: [String: String])
        case notFound
        case methodNotAllowed(allowedMethods: [String])
    }

    /// Lightweight endpoint data for matching. Uses tuple to avoid
    /// SwiftData model dependency (MockEndpoint is MainActor-isolated).
    typealias EndpointData = (path: String, method: String, statusCode: Int,
                              responseBody: String, responseHeaders: [String: String],
                              isEnabled: Bool)

    /// Match a request method and path against a list of endpoint data.
    ///
    /// - Parameters:
    ///   - method: HTTP method from the request (e.g., "GET")
    ///   - path: Request path (e.g., "/api/users")
    ///   - endpoints: Array of endpoint data tuples
    /// - Returns: MatchResult indicating matched, not found, or method not allowed
    nonisolated static func match(
        method: String,
        path: String,
        endpoints: [EndpointData]
    ) -> MatchResult {
        let enabledEndpoints = endpoints.filter { $0.isEnabled }

        // Find endpoints matching the path (case-insensitive)
        let pathMatches = enabledEndpoints.filter {
            $0.path.lowercased() == path.lowercased()
        }

        guard !pathMatches.isEmpty else { return .notFound }

        // Find endpoint matching both path and method (case-insensitive)
        if let match = pathMatches.first(where: {
            $0.method.uppercased() == method.uppercased()
        }) {
            return .matched(
                path: match.path,
                method: match.method,
                statusCode: match.statusCode,
                responseBody: match.responseBody,
                responseHeaders: match.responseHeaders
            )
        }

        // Path matched but method did not -> 405 with allowed methods
        let allowedMethods = Array(Set(pathMatches.map { $0.method.uppercased() })).sorted()
        return .methodNotAllowed(allowedMethods: allowedMethods)
    }
}
