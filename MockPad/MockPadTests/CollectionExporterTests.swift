//
//  CollectionExporterTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
import SwiftData
@testable import MockPad

@MainActor
struct CollectionExporterTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MockEndpoint.self, RequestLog.self, ResponseTemplate.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func export_producesValidJSON() throws {
        let context = try makeContext()
        let ep1 = MockEndpoint(path: "/api/users", httpMethod: "GET")
        let ep2 = MockEndpoint(path: "/api/posts", httpMethod: "POST")
        context.insert(ep1)
        context.insert(ep2)

        let data = try CollectionExporter.export(endpoints: [ep1, ep2], collectionName: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(MockPadExport.self, from: data)

        #expect(result.format == "mockpad-collection")
        #expect(result.version == 1)
        #expect(result.endpoints.count == 2)
    }

    @Test func export_includesAllEndpointFields() throws {
        let context = try makeContext()
        let ep = MockEndpoint(
            path: "/api/items",
            httpMethod: "PUT",
            responseStatusCode: 201,
            responseBody: "{\"created\":true}",
            responseHeaders: ["X-Custom": "value", "Content-Type": "application/json"],
            isEnabled: false,
            responseDelayMs: 500
        )
        context.insert(ep)

        let data = try CollectionExporter.export(endpoints: [ep], collectionName: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(MockPadExport.self, from: data)
        let exported = try #require(result.endpoints.first)

        #expect(exported.path == "/api/items")
        #expect(exported.httpMethod == "PUT")
        #expect(exported.responseStatusCode == 201)
        #expect(exported.responseBody == "{\"created\":true}")
        #expect(exported.responseHeaders["X-Custom"] == "value")
        #expect(exported.isEnabled == false)
        #expect(exported.responseDelayMs == 500)
    }

    @Test func export_withCollectionName() throws {
        let context = try makeContext()
        let ep = MockEndpoint(path: "/api/test")
        context.insert(ep)

        let data = try CollectionExporter.export(endpoints: [ep], collectionName: "My API")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(MockPadExport.self, from: data)

        #expect(result.collectionName == "My API")
    }

    @Test func export_withNilCollectionName() throws {
        let context = try makeContext()
        let ep = MockEndpoint(path: "/api/test")
        context.insert(ep)

        let data = try CollectionExporter.export(endpoints: [ep], collectionName: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(MockPadExport.self, from: data)

        #expect(result.collectionName == nil)
    }

    @Test func export_sortedKeys() throws {
        let context = try makeContext()
        let ep = MockEndpoint(path: "/api/test")
        context.insert(ep)

        let data = try CollectionExporter.export(endpoints: [ep], collectionName: nil)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // With sortedKeys, "collectionName" should come before "endpoints" before "exportedAt" before "format" before "version"
        let collectionNameRange = jsonString.range(of: "collectionName")
        let endpointsRange = jsonString.range(of: "\"endpoints\"")
        let formatRange = jsonString.range(of: "\"format\"")

        let cn = try #require(collectionNameRange)
        let ep2 = try #require(endpointsRange)
        let fm = try #require(formatRange)

        #expect(cn.lowerBound < ep2.lowerBound)
        #expect(ep2.lowerBound < fm.lowerBound)
    }
}
