//
//  RequestLogData.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Sendable DTO that carries request log data from MockServerEngine actor
/// to MainActor for SwiftData persistence via EndpointStore.addLogEntry().
/// The engine actor cannot create SwiftData objects directly -- this struct
/// bridges the data across actor boundaries.
struct RequestLogData: Sendable {
    let timestamp: Date
    let method: String
    let path: String
    let queryParameters: [String: String]
    let requestHeaders: [String: String]
    let requestBody: String?
    let responseStatusCode: Int
    let responseBody: String?
    let responseTimeMs: Double
}
