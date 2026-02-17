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
/// Supports exact paths (/api/users), parameterized paths (/api/users/:id),
/// and wildcard paths (/api/*). Priority: exact > parameterized > wildcard.
enum EndpointMatcher {

    /// Result of matching a request to an endpoint.
    enum MatchResult: Sendable {
        case matched(path: String, method: String, statusCode: Int,
                     responseBody: String, responseHeaders: [String: String],
                     responseDelayMs: Int, pathParams: [String: String])
        case notFound
        case methodNotAllowed(allowedMethods: [String])
    }

    /// Lightweight endpoint data for matching. Uses tuple to avoid
    /// SwiftData model dependency (MockEndpoint is MainActor-isolated).
    typealias EndpointData = (path: String, method: String, statusCode: Int,
                              responseBody: String, responseHeaders: [String: String],
                              isEnabled: Bool, responseDelayMs: Int)

    /// Match a request method and path against a list of endpoint data.
    ///
    /// Uses segment-based path matching with support for `:param` extraction
    /// and `*` wildcards. Priority order: exact > parameterized > wildcard.
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

        // Phase 1: Find all path matches with extracted params
        var pathMatches: [(endpoint: EndpointData, params: [String: String])] = []
        for ep in enabledEndpoints {
            if let params = matchPath(pattern: ep.path, against: path) {
                pathMatches.append((ep, params))
            }
        }

        guard !pathMatches.isEmpty else { return .notFound }

        // Phase 2: Sort by specificity (exact > parameterized > wildcard)
        // Stable sort preserves array order within same specificity (first-match-wins)
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

        // Path matched but method did not -> 405 with allowed methods
        let allowedMethods = Array(Set(pathMatches.map {
            $0.endpoint.method.uppercased()
        })).sorted()
        return .methodNotAllowed(allowedMethods: allowedMethods)
    }

    /// Match a URL path pattern against an actual request path.
    ///
    /// - Literal segments: case-insensitive exact match
    /// - `:param` segments: match any single segment, capture value
    /// - `*` at end of pattern: match any remaining segments (0+)
    ///
    /// - Parameters:
    ///   - pattern: Endpoint path pattern (e.g., "/api/users/:id")
    ///   - path: Actual request path (e.g., "/api/users/42")
    /// - Returns: Dictionary of extracted params, or nil if no match.
    ///           Empty dict `[:]` for exact matches with no parameters.
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

    /// Specificity score for a path pattern.
    /// Lower score = more specific = higher priority.
    ///
    /// - 0: exact (no `:` or `*` segments)
    /// - 1: parameterized (has `:` segments, no `*`)
    /// - 2: wildcard (ends with `*`)
    nonisolated private static func specificity(of pattern: String) -> Int {
        let segments = pattern.split(separator: "/").map(String.init)
        if segments.last == "*" { return 2 }
        if segments.contains(where: { $0.hasPrefix(":") }) { return 1 }
        return 0
    }
}
