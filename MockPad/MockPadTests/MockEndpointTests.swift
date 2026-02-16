//
//  MockEndpointTests.swift
//  MockPadTests
//
//  Created by Olof Petterson on 2026-02-16.
//

import Testing
import Foundation
import SwiftData
@testable import MockPad

@MainActor
struct MockEndpointTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func createEndpointWithDefaults() throws {
        let context = try makeContext()
        let endpoint = MockEndpoint(path: "/api/users")

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched.count == 1)
        #expect(fetched[0].path == "/api/users")
        #expect(fetched[0].httpMethod == "GET")
        #expect(fetched[0].responseStatusCode == 200)
        #expect(fetched[0].responseBody == "{}")
        #expect(fetched[0].isEnabled == true)
        #expect(fetched[0].sortOrder == 0)
    }

    @Test func responseHeadersRoundTrip() throws {
        let context = try makeContext()
        let headers = ["Content-Type": "application/json", "X-Custom": "value"]
        let endpoint = MockEndpoint(path: "/test", responseHeaders: headers)

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched[0].responseHeaders == headers)
    }

    @Test func emptyHeadersReturnEmptyDict() throws {
        let context = try makeContext()
        let endpoint = MockEndpoint(path: "/test", responseHeaders: [:])

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched[0].responseHeaders == [:])
    }

    @Test func sortOrderPersists() throws {
        let context = try makeContext()
        let e1 = MockEndpoint(path: "/first", sortOrder: 0)
        let e2 = MockEndpoint(path: "/second", sortOrder: 1)

        context.insert(e1)
        context.insert(e2)
        try context.save()

        let descriptor = FetchDescriptor<MockEndpoint>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched[0].path == "/first")
        #expect(fetched[1].path == "/second")
    }

    @Test func allFieldsPersist() throws {
        let context = try makeContext()
        let headers = ["Authorization": "Bearer token", "Accept": "text/html"]
        let endpoint = MockEndpoint(
            path: "/api/admin",
            httpMethod: "POST",
            responseStatusCode: 201,
            responseBody: "{\"created\": true}",
            responseHeaders: headers,
            isEnabled: false,
            sortOrder: 5
        )

        context.insert(endpoint)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MockEndpoint>())
        #expect(fetched.count == 1)
        #expect(fetched[0].path == "/api/admin")
        #expect(fetched[0].httpMethod == "POST")
        #expect(fetched[0].responseStatusCode == 201)
        #expect(fetched[0].responseBody == "{\"created\": true}")
        #expect(fetched[0].responseHeaders == headers)
        #expect(fetched[0].isEnabled == false)
        #expect(fetched[0].sortOrder == 5)
        #expect(fetched[0].createdAt <= Date())
    }
}
