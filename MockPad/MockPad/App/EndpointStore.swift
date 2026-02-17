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
                isEnabled: endpoint.isEnabled,
                responseDelayMs: endpoint.responseDelayMs
            )
        }
    }

    var collectionNames: [String] {
        Set(endpoints.compactMap(\.collectionName)).sorted()
    }

    func endpoints(inCollection name: String?) -> [MockEndpoint] {
        let descriptor = FetchDescriptor<MockEndpoint>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        return all.filter { $0.collectionName == name }
    }

    func importEndpoints(_ imported: [ExportedEndpoint], collectionName: String?, resolution: DuplicateResolution) {
        let existing = endpoints
        let maxSortOrder = existing.map(\.sortOrder).max() ?? -1

        switch resolution {
        case .skip:
            let nonDuplicates = imported.filter { imp in
                !existing.contains { ex in
                    ex.path.lowercased() == imp.path.lowercased() &&
                    ex.httpMethod.uppercased() == imp.httpMethod.uppercased()
                }
            }
            for (index, ep) in nonDuplicates.enumerated() {
                let endpoint = MockEndpoint(
                    path: ep.path,
                    httpMethod: ep.httpMethod,
                    responseStatusCode: ep.responseStatusCode,
                    responseBody: ep.responseBody,
                    responseHeaders: ep.responseHeaders,
                    isEnabled: ep.isEnabled,
                    responseDelayMs: ep.responseDelayMs,
                    sortOrder: maxSortOrder + 1 + index,
                    collectionName: collectionName
                )
                modelContext.insert(endpoint)
            }
        case .replace:
            for (index, ep) in imported.enumerated() {
                if let match = existing.first(where: {
                    $0.path.lowercased() == ep.path.lowercased() &&
                    $0.httpMethod.uppercased() == ep.httpMethod.uppercased()
                }) {
                    modelContext.delete(match)
                }
                let endpoint = MockEndpoint(
                    path: ep.path,
                    httpMethod: ep.httpMethod,
                    responseStatusCode: ep.responseStatusCode,
                    responseBody: ep.responseBody,
                    responseHeaders: ep.responseHeaders,
                    isEnabled: ep.isEnabled,
                    responseDelayMs: ep.responseDelayMs,
                    sortOrder: maxSortOrder + 1 + index,
                    collectionName: collectionName
                )
                modelContext.insert(endpoint)
            }
        case .importAsNew:
            for (index, ep) in imported.enumerated() {
                let endpoint = MockEndpoint(
                    path: ep.path,
                    httpMethod: ep.httpMethod,
                    responseStatusCode: ep.responseStatusCode,
                    responseBody: ep.responseBody,
                    responseHeaders: ep.responseHeaders,
                    isEnabled: ep.isEnabled,
                    responseDelayMs: ep.responseDelayMs,
                    sortOrder: maxSortOrder + 1 + index,
                    collectionName: collectionName
                )
                modelContext.insert(endpoint)
            }
        }
        try? modelContext.save()
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

    func clearLog() {
        let descriptor = FetchDescriptor<RequestLog>()
        guard let allLogs = try? modelContext.fetch(descriptor) else { return }
        for log in allLogs {
            modelContext.delete(log)
        }
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
