//
//  EndpointSnapshot.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Sendable DTO that carries endpoint configuration from MainActor
/// (EndpointStore/MockEndpoint) to the MockServerEngine actor.
/// MockEndpoint is a SwiftData @Model class bound to MainActor --
/// it cannot cross actor boundaries. EndpointSnapshot carries the
/// same data in a plain Sendable struct.
struct EndpointSnapshot: Sendable {
    let path: String
    let method: String
    let statusCode: Int
    let responseBody: String
    let responseHeaders: [String: String]
    let isEnabled: Bool
    let responseDelayMs: Int
}
