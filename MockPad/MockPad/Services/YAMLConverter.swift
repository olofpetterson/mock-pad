//
//  YAMLConverter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum YAMLConverter {
    enum ConversionError: Error, LocalizedError, Equatable {
        case invalidYAML(String)

        var errorDescription: String? {
            switch self {
            case .invalidYAML(let detail):
                "Invalid YAML: \(detail)"
            }
        }
    }

    /// Convert YAML string to JSON-compatible Data
    static func toJSON(_ yaml: String) throws -> Data {
        throw ConversionError.invalidYAML("Not implemented")
    }
}
