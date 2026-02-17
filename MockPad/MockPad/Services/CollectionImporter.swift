//
//  CollectionImporter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum CollectionImporter {
    enum ImportError: Error, LocalizedError, Equatable {
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let export: MockPadExport
        do {
            export = try decoder.decode(MockPadExport.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }

        guard export.format == "mockpad-collection" else {
            throw ImportError.invalidFormat
        }

        guard export.version == 1 else {
            throw ImportError.unsupportedVersion(export.version)
        }

        return export
    }

    static func findDuplicates(imported: [ExportedEndpoint], existing: [MockEndpoint]) -> [ExportedEndpoint] {
        imported.filter { imp in
            existing.contains { ex in
                ex.path.lowercased() == imp.path.lowercased() &&
                ex.httpMethod.uppercased() == imp.httpMethod.uppercased()
            }
        }
    }
}
