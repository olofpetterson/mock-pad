//
//  CollectionExporter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum CollectionExporter {
    static func export(endpoints: [MockEndpoint], collectionName: String?) throws -> Data {
        // TODO: Implement in GREEN phase
        Data()
    }

    static func exportDocument(endpoints: [MockEndpoint], collectionName: String?) throws -> MockPadDocument {
        let data = try export(endpoints: endpoints, collectionName: collectionName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(MockPadExport.self, from: data)
        return try MockPadDocument(export: export)
    }
}
