//
//  MockPadExportModels.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

struct MockPadExport: Codable {
    let format: String
    let version: Int
    let exportedAt: Date
    let collectionName: String?
    let endpoints: [ExportedEndpoint]
}

struct ExportedEndpoint: Codable {
    let path: String
    let httpMethod: String
    let responseStatusCode: Int
    let responseBody: String
    let responseHeaders: [String: String]
    let isEnabled: Bool
    let responseDelayMs: Int
}

enum DuplicateResolution: String, CaseIterable {
    case skip
    case replace
    case importAsNew
}

struct MockPadDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(export: MockPadExport) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.data = try encoder.encode(export)
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct MockPadExportFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { exportFile in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(exportFile.filename + ".json")
            try exportFile.data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }
}
