//
//  MockServerError.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation

/// Error cases for mock server failures.
enum MockServerError: Error, LocalizedError {
    case invalidPort
    case portInUse(UInt16)
    case listenerFailed(String)
    case alreadyRunning
    case tooManyConnections

    var errorDescription: String? {
        switch self {
        case .invalidPort: "Invalid port number"
        case .portInUse(let port): "Port \(port) is already in use"
        case .listenerFailed(let msg): "Server failed: \(msg)"
        case .alreadyRunning: "Server is already running"
        case .tooManyConnections: "Too many concurrent connections"
        }
    }
}
