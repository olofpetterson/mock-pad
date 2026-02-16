//
//  CurlGeneratorTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct CurlGeneratorTests {
    @Test func simpleGETProducesMinimalCurl() {
        let curl = CurlGenerator.generate(
            method: "GET",
            path: "/api/users",
            headers: [:],
            body: nil,
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("curl"))
        #expect(curl.contains("'http://localhost:8080/api/users'"))
        #expect(!curl.contains("-X"))  // GET is default, no -X flag needed
        #expect(!curl.contains("-d"))
    }

    @Test func getWithHeadersIncludesHeaderFlags() {
        let curl = CurlGenerator.generate(
            method: "GET",
            path: "/api/users",
            headers: ["Accept": "application/json", "Authorization": "Bearer token123"],
            body: nil,
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("-H 'Accept: application/json'"))
        #expect(curl.contains("-H 'Authorization: Bearer token123'"))
    }

    @Test func postWithBodyIncludesMethodAndData() {
        let curl = CurlGenerator.generate(
            method: "POST",
            path: "/api/users",
            headers: ["Content-Type": "application/json"],
            body: "{\"name\":\"Alice\"}",
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("-X POST"))
        #expect(curl.contains("-d"))
        #expect(curl.contains("Alice"))
    }

    @Test func deleteMethodIncludesExplicitMethod() {
        let curl = CurlGenerator.generate(
            method: "DELETE",
            path: "/api/users/42",
            headers: [:],
            body: nil,
            baseURL: "http://localhost:8080"
        )
        #expect(curl.contains("-X DELETE"))
    }

    @Test func bodyWithSingleQuotesEscapedCorrectly() {
        let curl = CurlGenerator.generate(
            method: "POST",
            path: "/api/data",
            headers: [:],
            body: "{\"msg\":\"it's a test\"}",
            baseURL: "http://localhost:8080"
        )
        // Single quotes in body escaped with shell convention
        #expect(curl.contains("'\\''"))
    }

    @Test func emptyBodyOmitsDataFlag() {
        let curl = CurlGenerator.generate(
            method: "POST",
            path: "/api/data",
            headers: [:],
            body: "",
            baseURL: "http://localhost:8080"
        )
        #expect(!curl.contains("-d"))
    }

    @Test func headersAreSortedAlphabetically() {
        let curl = CurlGenerator.generate(
            method: "GET",
            path: "/api",
            headers: ["Zebra": "last", "Alpha": "first"],
            body: nil,
            baseURL: "http://localhost:8080"
        )
        // Alpha should appear before Zebra in the output
        let alphaRange = curl.range(of: "Alpha")!
        let zebraRange = curl.range(of: "Zebra")!
        #expect(alphaRange.lowerBound < zebraRange.lowerBound)
    }
}
