//
//  MockEndpoint.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation
import SwiftData

@Model
final class MockEndpoint {
    var path: String
    var httpMethod: String
    var responseStatusCode: Int
    var responseBody: String
    var responseHeadersData: Data?
    var isEnabled: Bool
    var sortOrder: Int
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
        path: String,
        httpMethod: String = "GET",
        responseStatusCode: Int = 200,
        responseBody: String = "{}",
        responseHeaders: [String: String] = ["Content-Type": "application/json"],
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.path = path
        self.httpMethod = httpMethod
        self.responseStatusCode = responseStatusCode
        self.responseBody = responseBody
        self.responseHeadersData = try? JSONEncoder().encode(responseHeaders)
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
