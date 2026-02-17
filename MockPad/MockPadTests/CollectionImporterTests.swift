//
//  CollectionImporterTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
import SwiftData
@testable import MockPad

struct CollectionImporterTests {
    private func makeValidJSON(
        format: String = "mockpad-collection",
        version: Int = 1,
        collectionName: String? = nil,
        endpoints: [[String: Any]] = []
    ) -> Data {
        var dict: [String: Any] = [
            "format": format,
            "version": version,
            "exportedAt": "2026-01-01T00:00:00Z",
            "endpoints": endpoints
        ]
        if let name = collectionName {
            dict["collectionName"] = name
        }
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    private func makeEndpointDict(
        path: String = "/api/test",
        httpMethod: String = "GET",
        responseStatusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = [:],
        isEnabled: Bool = true,
        responseDelayMs: Int = 0
    ) -> [String: Any] {
        [
            "path": path,
            "httpMethod": httpMethod,
            "responseStatusCode": responseStatusCode,
            "responseBody": responseBody,
            "responseHeaders": responseHeaders,
            "isEnabled": isEnabled,
            "responseDelayMs": responseDelayMs
        ]
    }

    @Test func parse_validExport() throws {
        let json = makeValidJSON(
            collectionName: "Test Collection",
            endpoints: [makeEndpointDict(path: "/api/users", httpMethod: "GET")]
        )

        let result = try CollectionImporter.parse(data: json)

        #expect(result.format == "mockpad-collection")
        #expect(result.version == 1)
        #expect(result.collectionName == "Test Collection")
        #expect(result.endpoints.count == 1)
        #expect(result.endpoints[0].path == "/api/users")
    }

    @Test func parse_invalidFormat() throws {
        let json = makeValidJSON(format: "not-mockpad")

        #expect(throws: CollectionImporter.ImportError.invalidFormat) {
            try CollectionImporter.parse(data: json)
        }
    }

    @Test func parse_unsupportedVersion() throws {
        let json = makeValidJSON(version: 99)

        #expect(throws: CollectionImporter.ImportError.unsupportedVersion(99)) {
            try CollectionImporter.parse(data: json)
        }
    }

    @Test func parse_invalidJSON() throws {
        let data = "this is not json".data(using: .utf8)!

        #expect {
            try CollectionImporter.parse(data: data)
        } throws: { error in
            guard let importError = error as? CollectionImporter.ImportError else { return false }
            if case .decodingFailed = importError { return true }
            return false
        }
    }

    @Test @MainActor func findDuplicates_matchByPathAndMethod() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self, ResponseTemplate.self,
            configurations: config
        )
        let context = ModelContext(container)

        let existing = MockEndpoint(path: "/api/users", httpMethod: "GET")
        context.insert(existing)

        let imported = [
            ExportedEndpoint(path: "/api/users", httpMethod: "GET", responseStatusCode: 200, responseBody: "{}", responseHeaders: [:], isEnabled: true, responseDelayMs: 0),
            ExportedEndpoint(path: "/api/posts", httpMethod: "POST", responseStatusCode: 201, responseBody: "{}", responseHeaders: [:], isEnabled: true, responseDelayMs: 0)
        ]

        let duplicates = CollectionImporter.findDuplicates(imported: imported, existing: [existing])
        #expect(duplicates.count == 1)
        #expect(duplicates[0].path == "/api/users")
    }

    @Test @MainActor func findDuplicates_caseInsensitive() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self, ResponseTemplate.self,
            configurations: config
        )
        let context = ModelContext(container)

        let existing = MockEndpoint(path: "/api/users", httpMethod: "GET")
        context.insert(existing)

        let imported = [
            ExportedEndpoint(path: "/API/Users", httpMethod: "get", responseStatusCode: 200, responseBody: "{}", responseHeaders: [:], isEnabled: true, responseDelayMs: 0)
        ]

        let duplicates = CollectionImporter.findDuplicates(imported: imported, existing: [existing])
        #expect(duplicates.count == 1)
    }

    @Test @MainActor func findDuplicates_differentMethodNotDuplicate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self, ResponseTemplate.self,
            configurations: config
        )
        let context = ModelContext(container)

        let existing = MockEndpoint(path: "/api/users", httpMethod: "GET")
        context.insert(existing)

        let imported = [
            ExportedEndpoint(path: "/api/users", httpMethod: "POST", responseStatusCode: 201, responseBody: "{}", responseHeaders: [:], isEnabled: true, responseDelayMs: 0)
        ]

        let duplicates = CollectionImporter.findDuplicates(imported: imported, existing: [existing])
        #expect(duplicates.count == 0)
    }

    @Test func findDuplicates_noDuplicates() {
        let imported = [
            ExportedEndpoint(path: "/api/users", httpMethod: "GET", responseStatusCode: 200, responseBody: "{}", responseHeaders: [:], isEnabled: true, responseDelayMs: 0)
        ]

        let duplicates = CollectionImporter.findDuplicates(imported: imported, existing: [])
        #expect(duplicates.count == 0)
    }
}
