//
//  ResponseTemplate.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation
import SwiftData

@Model
final class ResponseTemplate {
    var name: String
    var statusCode: Int
    var responseBody: String
    var responseHeadersData: Data?
    var createdAt: Date

    var responseHeaders: [String: String] {
        get {
            guard let data = responseHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            responseHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        name: String,
        statusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = ["Content-Type": "application/json"]
    ) {
        self.name = name
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.responseHeadersData = try? JSONEncoder().encode(responseHeaders)
        self.createdAt = Date()
    }
}
