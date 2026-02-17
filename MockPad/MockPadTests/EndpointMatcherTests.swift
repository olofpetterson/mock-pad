//
//  EndpointMatcherTests.swift
//  MockPadTests
//
//  Created with GSD workflow on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct EndpointMatcherTests {

    // MARK: - Helpers

    private func endpoint(
        path: String,
        method: String,
        statusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = [:],
        isEnabled: Bool = true,
        responseDelayMs: Int = 0
    ) -> EndpointMatcher.EndpointData {
        (path: path, method: method, statusCode: statusCode,
         responseBody: responseBody, responseHeaders: responseHeaders,
         isEnabled: isEnabled, responseDelayMs: responseDelayMs)
    }

    // MARK: - Exact Match (existing, updated for pathParams arity)

    @Test func exactMatch_returnsMatched() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET", statusCode: 200, responseBody: "[{\"id\":1}]", responseHeaders: ["Content-Type": "application/json"])
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case let .matched(path, method, statusCode, responseBody, responseHeaders, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(path == "/api/users")
        #expect(method == "GET")
        #expect(statusCode == 200)
        #expect(responseBody == "[{\"id\":1}]")
        #expect(responseHeaders["Content-Type"] == "application/json")
        #expect(pathParams.isEmpty)
    }

    // MARK: - Method Not Allowed

    @Test func methodNotAllowed_returnsAllowedMethods() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET")
        ]
        let result = EndpointMatcher.match(method: "POST", path: "/api/users", endpoints: endpoints)
        guard case let .methodNotAllowed(allowedMethods) = result else {
            Issue.record("Expected .methodNotAllowed but got \(result)")
            return
        }
        #expect(allowedMethods.contains("GET"))
    }

    // MARK: - Not Found

    @Test func noMatch_returnsNotFound() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET")
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/nonexistent", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    // MARK: - Disabled Endpoints

    @Test func disabledEndpoint_ignored() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET", isEnabled: false)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    // MARK: - Case Insensitivity

    @Test func caseInsensitivePath() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET")
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/API/Users", endpoints: endpoints)
        guard case .matched = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
    }

    @Test func caseInsensitiveMethod() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET")
        ]
        let result = EndpointMatcher.match(method: "get", path: "/api/users", endpoints: endpoints)
        guard case .matched = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
    }

    // MARK: - Multiple Methods

    @Test func multipleMethodsOnSamePath() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET"),
            endpoint(path: "/api/users", method: "POST")
        ]
        let result = EndpointMatcher.match(method: "DELETE", path: "/api/users", endpoints: endpoints)
        guard case let .methodNotAllowed(allowedMethods) = result else {
            Issue.record("Expected .methodNotAllowed but got \(result)")
            return
        }
        #expect(allowedMethods.contains("GET"))
        #expect(allowedMethods.contains("POST"))
        #expect(allowedMethods.count == 2)
    }

    // MARK: - Empty Endpoints

    @Test func emptyEndpoints_returnsNotFound() {
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: [])
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    // MARK: - First Match Wins

    @Test func firstMatchWins() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET", statusCode: 200),
            endpoint(path: "/api/users", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 200)
    }

    // MARK: - Path Parameter Tests (NEW)

    @Test func pathParam_singleParam_extractsValue() {
        let endpoints = [endpoint(path: "/api/users/:id", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(pathParams["id"] == "42")
    }

    @Test func pathParam_multipleParams_extractsAll() {
        let endpoints = [endpoint(path: "/api/users/:userId/posts/:postId", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42/posts/7", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(pathParams["userId"] == "42")
        #expect(pathParams["postId"] == "7")
    }

    @Test func pathParam_segmentCountMismatch_returnsNotFound() {
        let endpoints = [endpoint(path: "/api/users/:id", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    @Test func pathParam_tooManySegments_returnsNotFound() {
        let endpoints = [endpoint(path: "/api/users", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    @Test func pathParam_caseInsensitiveLiteralSegments() {
        let endpoints = [endpoint(path: "/API/Users/:id", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(pathParams["id"] == "42")
    }

    @Test func pathParam_disabledEndpoint_ignored() {
        let endpoints = [endpoint(path: "/api/users/:id", method: "GET", isEnabled: false)]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    @Test func pathParam_methodNotAllowed_with405() {
        let endpoints = [endpoint(path: "/api/users/:id", method: "GET")]
        let result = EndpointMatcher.match(method: "DELETE", path: "/api/users/42", endpoints: endpoints)
        guard case let .methodNotAllowed(allowedMethods) = result else {
            Issue.record("Expected .methodNotAllowed but got \(result)")
            return
        }
        #expect(allowedMethods.contains("GET"))
    }

    // MARK: - Wildcard Tests (NEW)

    @Test func wildcard_matchesSubPath() {
        let endpoints = [endpoint(path: "/api/*", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42/posts", endpoints: endpoints)
        guard case .matched = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
    }

    @Test func wildcard_matchesZeroSubSegments() {
        let endpoints = [endpoint(path: "/api/*", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api", endpoints: endpoints)
        guard case .matched = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
    }

    @Test func wildcard_paramPlusWildcard() {
        let endpoints = [endpoint(path: "/api/:version/*", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/v2/users", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(pathParams["version"] == "v2")
    }

    @Test func wildcard_noMatchDifferentPrefix() {
        let endpoints = [endpoint(path: "/api/*", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/other/users", endpoints: endpoints)
        guard case .notFound = result else {
            Issue.record("Expected .notFound but got \(result)")
            return
        }
    }

    // MARK: - Priority Tests (NEW)

    @Test func priority_exactOverParam() {
        let endpoints = [
            endpoint(path: "/api/users/:id", method: "GET", statusCode: 200),
            endpoint(path: "/api/users/me", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/me", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 201)
    }

    @Test func priority_paramOverWildcard() {
        let endpoints = [
            endpoint(path: "/api/*", method: "GET", statusCode: 200),
            endpoint(path: "/api/users/:id", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 201)
    }

    @Test func priority_exactOverWildcard() {
        let endpoints = [
            endpoint(path: "/api/*", method: "GET", statusCode: 200),
            endpoint(path: "/api/users", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 201)
    }

    @Test func priority_firstMatchWinsWithinSameSpecificity() {
        let endpoints = [
            endpoint(path: "/api/users/:id", method: "GET", statusCode: 200),
            endpoint(path: "/api/users/:name", method: "GET", statusCode: 201)
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users/42", endpoints: endpoints)
        guard case let .matched(_, _, statusCode, _, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 200)
    }

    @Test func exactMatch_returnsEmptyPathParams() {
        let endpoints = [endpoint(path: "/api/users", method: "GET")]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case let .matched(_, _, _, _, _, _, pathParams) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(pathParams.isEmpty)
    }
}
