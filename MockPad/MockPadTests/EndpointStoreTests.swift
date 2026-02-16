//
//  EndpointStoreTests.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Testing
import Foundation
import SwiftData
@testable import MockPad

@MainActor
struct EndpointStoreTests {
    private func makeStore() throws -> (EndpointStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self,
            configurations: config
        )
        let context = ModelContext(container)
        return (EndpointStore(modelContext: context), context)
    }

    @Test func addEndpoint() throws {
        let (store, _) = try makeStore()
        let endpoint = MockEndpoint(path: "/api/users")

        store.addEndpoint(endpoint)

        #expect(store.endpoints.count == 1)
        #expect(store.endpoints[0].path == "/api/users")
    }

    @Test func deleteEndpoint() throws {
        let (store, _) = try makeStore()
        let endpoint = MockEndpoint(path: "/api/users")
        store.addEndpoint(endpoint)

        store.deleteEndpoint(endpoint)

        #expect(store.endpoints.count == 0)
    }

    @Test func endpointCount() throws {
        let (store, _) = try makeStore()
        store.addEndpoint(MockEndpoint(path: "/one"))
        store.addEndpoint(MockEndpoint(path: "/two"))
        store.addEndpoint(MockEndpoint(path: "/three"))

        #expect(store.endpointCount == 3)
    }

    @Test func endpointsSortedBySortOrder() throws {
        let (store, _) = try makeStore()
        store.addEndpoint(MockEndpoint(path: "/c", sortOrder: 2))
        store.addEndpoint(MockEndpoint(path: "/a", sortOrder: 0))
        store.addEndpoint(MockEndpoint(path: "/b", sortOrder: 1))

        let endpoints = store.endpoints
        #expect(endpoints[0].path == "/a")
        #expect(endpoints[1].path == "/b")
        #expect(endpoints[2].path == "/c")
    }

    @Test func updateEndpoint() throws {
        let (store, _) = try makeStore()
        let endpoint = MockEndpoint(path: "/original")
        store.addEndpoint(endpoint)

        endpoint.path = "/updated"
        store.updateEndpoint()

        #expect(store.endpoints[0].path == "/updated")
    }

    @Test func addLogEntry() throws {
        let (store, context) = try makeStore()
        let log = RequestLog(
            method: "GET",
            path: "/api/test",
            responseStatusCode: 200,
            responseTimeMs: 42.0
        )

        store.addLogEntry(log)

        let descriptor = FetchDescriptor<RequestLog>()
        let logs = try context.fetch(descriptor)
        #expect(logs.count == 1)
        #expect(logs[0].path == "/api/test")
        #expect(logs[0].responseTimeMs == 42.0)
    }

    @Test func autopruneKeepsLatest1000() throws {
        let (store, context) = try makeStore()

        // Insert 1005 log entries with incrementing timestamps
        for i in 0..<1005 {
            let log = RequestLog(
                timestamp: Date(timeIntervalSince1970: Double(i)),
                method: "GET",
                path: "/api/test",
                responseStatusCode: 200,
                responseTimeMs: 1.0
            )
            store.addLogEntry(log)
        }

        // After pruning, only 1000 entries should remain
        let countDescriptor = FetchDescriptor<RequestLog>()
        let count = try context.fetchCount(countDescriptor)
        #expect(count == 1000)

        // Verify the oldest entries (timestamps 0-4) were removed
        // and the newest entries (timestamps 5-1004) remain
        let sortDescriptor = FetchDescriptor<RequestLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let logs = try context.fetch(sortDescriptor)
        let oldestTimestamp = logs.first?.timestamp.timeIntervalSince1970 ?? -1
        let newestTimestamp = logs.last?.timestamp.timeIntervalSince1970 ?? -1
        #expect(oldestTimestamp == 5.0)
        #expect(newestTimestamp == 1004.0)
    }
}
