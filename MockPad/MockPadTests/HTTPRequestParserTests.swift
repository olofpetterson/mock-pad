//
//  HTTPRequestParserTests.swift
//  MockPadTests
//
//  Created with GSD workflow on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct HTTPRequestParserTests {

    // MARK: - Request Line Parsing

    @Test func parseSimpleGET() {
        let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.method == "GET")
        #expect(request?.path == "/api/users")
        #expect(request?.httpVersion == "HTTP/1.1")
        #expect(request?.body == nil)
    }

    @Test func parsePOSTWithJSONBody() {
        let raw = "POST /api/users HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"name\":\"John\"}"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.method == "POST")
        #expect(request?.path == "/api/users")
        #expect(request?.body == "{\"name\":\"John\"}")
    }

    @Test func parsePUTWithBody() {
        let raw = "PUT /api/users/1 HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{\"name\":\"Jane\"}"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.method == "PUT")
        #expect(request?.path == "/api/users/1")
        #expect(request?.body == "{\"name\":\"Jane\"}")
    }

    @Test func parseDELETE() {
        let raw = "DELETE /api/users/1 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.method == "DELETE")
        #expect(request?.path == "/api/users/1")
        #expect(request?.body == nil)
    }

    // MARK: - Query String

    @Test func parseQueryString() {
        let raw = "GET /api/users?page=1&limit=20 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.path == "/api/users")
        #expect(request?.queryString == "page=1&limit=20")
    }

    // MARK: - Headers

    @Test func parseMultipleHeaders() {
        let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nAuthorization: Bearer token123\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.headers["Host"] == "localhost")
        #expect(request?.headers["Content-Type"] == "application/json")
        #expect(request?.headers["Authorization"] == "Bearer token123")
    }

    @Test func headerWithColonInValue() {
        let raw = "GET / HTTP/1.1\r\nHost: localhost:8080\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.headers["Host"] == "localhost:8080")
    }

    // MARK: - Body Edge Cases

    @Test func emptyBody_returnsNil() {
        let raw = "GET /api/users HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.body == nil)
    }

    // MARK: - Invalid Input

    @Test func invalidData_returnsNil() {
        let raw = "not an http request"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request == nil)
    }

    @Test func emptyData_returnsNil() {
        let request = HTTPRequestParser.parse(data: Data())
        #expect(request == nil)
    }

    // MARK: - Minimal Request

    @Test func requestLineOnly_parsesMinimal() {
        let raw = "GET / HTTP/1.1\r\n\r\n"
        let request = HTTPRequestParser.parse(data: Data(raw.utf8))
        #expect(request != nil)
        #expect(request?.method == "GET")
        #expect(request?.path == "/")
    }

    // MARK: - parseQueryString Helper

    @Test func parseQueryStringHelper_multipleParams() {
        let result = HTTPRequestParser.parseQueryString("page=1&limit=20")
        #expect(result["page"] == "1")
        #expect(result["limit"] == "20")
        #expect(result.count == 2)
    }

    @Test func parseQueryStringHelper_encodedValues() {
        let result = HTTPRequestParser.parseQueryString("name=John%20Doe")
        #expect(result["name"] == "John Doe")
    }

    @Test func parseQueryStringHelper_emptyString() {
        let result = HTTPRequestParser.parseQueryString("")
        #expect(result.isEmpty)
    }

    @Test func parseQueryStringHelper_nil() {
        let result = HTTPRequestParser.parseQueryString(nil)
        #expect(result.isEmpty)
    }
}
