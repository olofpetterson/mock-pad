//
//  RequestLog.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation
import SwiftData

@Model
final class RequestLog {
    var timestamp: Date
    var method: String
    var path: String
    var queryParametersData: Data?
    var requestHeadersData: Data?
    var requestBody: String?
    var responseStatusCode: Int
    var responseBody: String?
    var responseHeadersData: Data?
    var matchedEndpointPath: String?
    var responseTimeMs: Double

    var queryParameters: [String: String] {
        get {
            guard let data = queryParametersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            queryParametersData = try? JSONEncoder().encode(newValue)
        }
    }

    var requestHeaders: [String: String] {
        get {
            guard let data = requestHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            requestHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    var responseHeaders: [String: String] {
        get {
            guard let data = responseHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            responseHeadersData = try? JSONEncoder().encode(newValue)
        }
    }

    static let maxBodySize = 64 * 1024

    static func truncateBody(_ body: String?) -> String? {
        guard let body, !body.isEmpty else { return body }
        if body.utf8.count > maxBodySize {
            let truncated = String(body.prefix(maxBodySize))
            return truncated + "\n[truncated]"
        }
        return body
    }

    init(
        timestamp: Date = Date(),
        method: String,
        path: String,
        queryParameters: [String: String] = [:],
        requestHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseStatusCode: Int,
        responseBody: String? = nil,
        responseHeaders: [String: String] = [:],
        matchedEndpointPath: String? = nil,
        responseTimeMs: Double
    ) {
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.queryParametersData = try? JSONEncoder().encode(queryParameters)
        self.requestHeadersData = try? JSONEncoder().encode(requestHeaders)
        self.requestBody = Self.truncateBody(requestBody)
        self.responseStatusCode = responseStatusCode
        self.responseBody = Self.truncateBody(responseBody)
        self.responseHeadersData = try? JSONEncoder().encode(responseHeaders)
        self.matchedEndpointPath = matchedEndpointPath
        self.responseTimeMs = responseTimeMs
    }
}
