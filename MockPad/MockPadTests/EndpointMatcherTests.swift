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

    // MARK: - Exact Match

    @Test func exactMatch_returnsMatched() {
        let endpoints = [
            endpoint(path: "/api/users", method: "GET", statusCode: 200, responseBody: "[{\"id\":1}]", responseHeaders: ["Content-Type": "application/json"])
        ]
        let result = EndpointMatcher.match(method: "GET", path: "/api/users", endpoints: endpoints)
        guard case let .matched(path, method, statusCode, responseBody, responseHeaders, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(path == "/api/users")
        #expect(method == "GET")
        #expect(statusCode == 200)
        #expect(responseBody == "[{\"id\":1}]")
        #expect(responseHeaders["Content-Type"] == "application/json")
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
        guard case let .matched(_, _, statusCode, _, _, _) = result else {
            Issue.record("Expected .matched but got \(result)")
            return
        }
        #expect(statusCode == 200)
    }
}
