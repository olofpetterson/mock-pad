//
//  PathParamReplacer.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

/// Token substitution service. Replaces {paramName} tokens in response
/// bodies with actual path parameter values extracted from the request.
///
/// Caseless enum with nonisolated static method, callable from any actor
/// context. Simple literal replacement -- no escaping, no nesting.
enum PathParamReplacer {

    /// Replace {paramName} tokens in the response body with actual values.
    ///
    /// - Parameters:
    ///   - body: Response body string potentially containing {key} tokens
    ///   - params: Dictionary of path parameter names to values
    /// - Returns: Body with all matching tokens replaced
    nonisolated static func replace(
        in body: String,
        with params: [String: String]
    ) -> String {
        guard !params.isEmpty else { return body }
        var result = body
        for (key, value) in params {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
