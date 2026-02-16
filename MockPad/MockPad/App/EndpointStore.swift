//
//  EndpointStore.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class EndpointStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var endpoints: [MockEndpoint] {
        let descriptor = FetchDescriptor<MockEndpoint>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var endpointSnapshots: [EndpointSnapshot] {
        endpoints.map { endpoint in
            EndpointSnapshot(
                path: endpoint.path,
                method: endpoint.httpMethod,
                statusCode: endpoint.responseStatusCode,
                responseBody: endpoint.responseBody,
                responseHeaders: endpoint.responseHeaders,
                isEnabled: endpoint.isEnabled
            )
        }
    }

    var endpointCount: Int {
        let descriptor = FetchDescriptor<MockEndpoint>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    func addEndpoint(_ endpoint: MockEndpoint) {
        modelContext.insert(endpoint)
        try? modelContext.save()
    }

    func deleteEndpoint(_ endpoint: MockEndpoint) {
        modelContext.delete(endpoint)
        try? modelContext.save()
    }

    func updateEndpoint() {
        try? modelContext.save()
    }

    func addLogEntry(_ log: RequestLog) {
        modelContext.insert(log)
        try? modelContext.save()
        pruneOldEntries()
    }

    private func pruneOldEntries() {
        let countDescriptor = FetchDescriptor<RequestLog>()
        guard let count = try? modelContext.fetchCount(countDescriptor), count > 1000 else {
            return
        }

        let fetchDescriptor = FetchDescriptor<RequestLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let allLogs = try? modelContext.fetch(fetchDescriptor) else { return }

        let deleteCount = count - 1000
        for i in 0..<deleteCount {
            modelContext.delete(allLogs[i])
        }
        try? modelContext.save()
    }
}
