//
//  CollectionImporter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum CollectionImporter {
    enum ImportError: Error, LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                "The file is not a valid MockPad collection"
            case .unsupportedVersion(let version):
                "Unsupported format version: \(version)"
            case .decodingFailed(let detail):
                "Failed to decode collection: \(detail)"
            }
        }
    }

    static func parse(data: Data) throws -> MockPadExport {
        // TODO: Implement in GREEN phase
        throw ImportError.decodingFailed("Not implemented")
    }

    static func findDuplicates(imported: [ExportedEndpoint], existing: [MockEndpoint]) -> [ExportedEndpoint] {
        // TODO: Implement in GREEN phase
        []
    }
}
