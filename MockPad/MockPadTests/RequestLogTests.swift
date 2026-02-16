//
//  RequestLogTests.swift
//  MockPadTests
//
//  Created by Olof Petterson on 2026-02-16.
//

import Testing
import Foundation
import SwiftData
@testable import MockPad

@MainActor
struct RequestLogTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func createLogWithDefaults() throws {
        let context = try makeContext()
        let log = RequestLog(
            method: "GET",
            path: "/api/users",
            responseStatusCode: 200,
            responseTimeMs: 42.5
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched.count == 1)
        #expect(fetched[0].method == "GET")
        #expect(fetched[0].path == "/api/users")
        #expect(fetched[0].responseStatusCode == 200)
        #expect(fetched[0].responseTimeMs == 42.5)
        #expect(fetched[0].requestBody == nil)
        #expect(fetched[0].responseBody == nil)
        #expect(fetched[0].queryParameters == [:])
        #expect(fetched[0].requestHeaders == [:])
    }

    @Test func queryParametersRoundTrip() throws {
        let context = try makeContext()
        let params = ["page": "1", "limit": "20"]
        let log = RequestLog(
            method: "GET",
            path: "/api/users",
            queryParameters: params,
            responseStatusCode: 200,
            responseTimeMs: 15.0
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched[0].queryParameters == params)
    }

    @Test func requestHeadersRoundTrip() throws {
        let context = try makeContext()
        let headers = ["Authorization": "Bearer token"]
        let log = RequestLog(
            method: "POST",
            path: "/api/data",
            requestHeaders: headers,
            responseStatusCode: 201,
            responseTimeMs: 30.0
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched[0].requestHeaders == headers)
    }

    @Test func bodyTruncationUnderLimit() throws {
        let context = try makeContext()
        let body = String(repeating: "a", count: 1000)
        let log = RequestLog(
            method: "POST",
            path: "/api/data",
            requestBody: body,
            responseStatusCode: 200,
            responseBody: body,
            responseTimeMs: 10.0
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched[0].requestBody == body)
        #expect(fetched[0].responseBody == body)
        #expect(fetched[0].requestBody?.contains("[truncated]") == false)
    }

    @Test func bodyTruncationAtLimit() throws {
        let context = try makeContext()
        let body = String(repeating: "a", count: 65_536)
        let log = RequestLog(
            method: "POST",
            path: "/api/data",
            requestBody: body,
            responseStatusCode: 200,
            responseBody: body,
            responseTimeMs: 10.0
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched[0].requestBody?.hasSuffix("\n[truncated]") == true)
        #expect(fetched[0].responseBody?.hasSuffix("\n[truncated]") == true)
    }

    @Test func nilBodyRemainsNil() throws {
        let context = try makeContext()
        let log = RequestLog(
            method: "GET",
            path: "/api/data",
            requestBody: nil,
            responseStatusCode: 200,
            responseBody: nil,
            responseTimeMs: 5.0
        )

        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RequestLog>())
        #expect(fetched[0].requestBody == nil)
        #expect(fetched[0].responseBody == nil)
    }

    @Test func truncateBodyStaticMethod() {
        #expect(RequestLog.truncateBody(nil) == nil)
        #expect(RequestLog.truncateBody("") == "")
        #expect(RequestLog.truncateBody("hello") == "hello")

        let underLimit = String(repeating: "b", count: 64 * 1024)
        #expect(RequestLog.truncateBody(underLimit) == underLimit)

        let overLimit = String(repeating: "c", count: 65_536)
        let result = RequestLog.truncateBody(overLimit)
        #expect(result?.hasSuffix("\n[truncated]") == true)
        #expect(result != overLimit)
    }
}
