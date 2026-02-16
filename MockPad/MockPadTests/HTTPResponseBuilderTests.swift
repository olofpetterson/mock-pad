//
//  HTTPResponseBuilderTests.swift
//  MockPadTests
//
//  Created with GSD workflow on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct HTTPResponseBuilderTests {

    // MARK: - Helper

    private func responseString(statusCode: Int, headers: [String: String] = [:], body: String = "", corsEnabled: Bool = true) -> String {
        let data = HTTPResponseBuilder.build(statusCode: statusCode, headers: headers, body: body, corsEnabled: corsEnabled)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Status Line

    @Test func build200Response() {
        let response = responseString(statusCode: 200, body: "{}")
        #expect(response.contains("HTTP/1.1 200 OK"))
        #expect(response.contains("Content-Length: 2"))
        #expect(response.contains("{}"))
    }

    @Test func build404Response() {
        let response = responseString(statusCode: 404, body: "")
        #expect(response.contains("HTTP/1.1 404 Not Found"))
    }

    @Test func build405Response() {
        let response = responseString(statusCode: 405, body: "")
        #expect(response.contains("HTTP/1.1 405 Method Not Allowed"))
    }

    @Test func build400Response() {
        let response = responseString(statusCode: 400, body: "")
        #expect(response.contains("HTTP/1.1 400 Bad Request"))
    }

    // MARK: - Headers

    @Test func buildWithCustomHeaders() {
        let response = responseString(statusCode: 200, headers: ["X-Custom": "value"], body: "")
        #expect(response.contains("X-Custom: value"))
    }

    @Test func buildConnectionClose() {
        let response = responseString(statusCode: 200, body: "")
        #expect(response.contains("Connection: close"))
    }

    @Test func buildServerHeader() {
        let response = responseString(statusCode: 200, body: "")
        #expect(response.contains("Server: MockPad/1.0"))
    }

    @Test func buildContentLength() {
        let response = responseString(statusCode: 200, body: "hello")
        #expect(response.contains("Content-Length: 5"))
    }

    @Test func buildEmptyBody() {
        let response = responseString(statusCode: 200, body: "")
        #expect(response.contains("Content-Length: 0"))
    }

    // MARK: - CORS

    @Test func buildWithCORSEnabled() {
        let response = responseString(statusCode: 200, body: "", corsEnabled: true)
        #expect(response.contains("Access-Control-Allow-Origin: *"))
        #expect(response.contains("Access-Control-Allow-Methods:"))
        #expect(response.contains("Access-Control-Allow-Headers:"))
    }

    @Test func buildWithCORSDisabled() {
        let response = responseString(statusCode: 200, body: "", corsEnabled: false)
        #expect(!response.contains("Access-Control-Allow-Origin"))
    }

    // MARK: - Preflight

    @Test func buildPreflightResponse() {
        let data = HTTPResponseBuilder.buildPreflightResponse(corsEnabled: true)
        let response = String(data: data, encoding: .utf8) ?? ""
        #expect(response.contains("HTTP/1.1 204 No Content"))
        #expect(response.contains("Access-Control-Max-Age: 86400"))
        #expect(response.contains("Access-Control-Allow-Origin: *"))
        #expect(response.contains("Access-Control-Allow-Methods:"))
        #expect(response.contains("Access-Control-Allow-Headers:"))
    }

    @Test func buildPreflightNoBody() {
        let data = HTTPResponseBuilder.buildPreflightResponse(corsEnabled: true)
        let response = String(data: data, encoding: .utf8) ?? ""
        // After the final \r\n (end of headers), there should be no body content
        let headerBodySplit = response.components(separatedBy: "\r\n\r\n")
        let bodyPart = headerBodySplit.count > 1 ? headerBodySplit.dropFirst().joined(separator: "\r\n\r\n") : ""
        #expect(bodyPart.isEmpty)
    }
}
