//
//  CollectionExporter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum CollectionExporter {
    static func export(endpoints: [MockEndpoint], collectionName: String?) throws -> Data {
        let exportedEndpoints = endpoints.map { ep in
            ExportedEndpoint(
                path: ep.path,
                httpMethod: ep.httpMethod,
                responseStatusCode: ep.responseStatusCode,
                responseBody: ep.responseBody,
                responseHeaders: ep.responseHeaders,
                isEnabled: ep.isEnabled,
                responseDelayMs: ep.responseDelayMs
            )
        }

        let export = MockPadExport(
            format: "mockpad-collection",
            version: 1,
            exportedAt: Date(),
            collectionName: collectionName,
            endpoints: exportedEndpoints
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    static func exportDocument(endpoints: [MockEndpoint], collectionName: String?) throws -> MockPadDocument {
        let data = try export(endpoints: endpoints, collectionName: collectionName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(MockPadExport.self, from: data)
        return try MockPadDocument(export: export)
    }
}
