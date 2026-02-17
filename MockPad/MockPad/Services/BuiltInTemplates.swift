//
//  BuiltInTemplates.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum BuiltInTemplates {
    struct Template: Sendable, Identifiable {
        let id: String
        let name: String
        let statusCode: Int
        let responseBody: String
        let responseHeaders: [String: String]
        let icon: String
    }

    static let success = Template(
        id: "success",
        name: "Success",
        statusCode: 200,
        responseBody: """
        {
          "message" : "OK",
          "success" : true
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "checkmark.circle"
    )

    static let userObject = Template(
        id: "user-object",
        name: "User Object",
        statusCode: 200,
        responseBody: """
        {
          "email" : "jane@example.com",
          "id" : 1,
          "name" : "Jane Smith",
          "role" : "admin"
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "person.circle"
    )

    static let userList = Template(
        id: "user-list",
        name: "User List",
        statusCode: 200,
        responseBody: """
        {
          "data" : [
            {
              "email" : "jane@example.com",
              "id" : 1,
              "name" : "Jane Smith"
            },
            {
              "email" : "john@example.com",
              "id" : 2,
              "name" : "John Doe"
            }
          ],
          "total" : 2
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "person.2.circle"
    )

    static let notFound = Template(
        id: "not-found",
        name: "Not Found",
        statusCode: 404,
        responseBody: """
        {
          "error" : "Not Found",
          "message" : "The requested resource was not found"
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "questionmark.circle"
    )

    static let unauthorized = Template(
        id: "unauthorized",
        name: "Unauthorized",
        statusCode: 401,
        responseBody: """
        {
          "error" : "Unauthorized",
          "message" : "Authentication required"
        }
        """,
        responseHeaders: [
            "Content-Type": "application/json",
            "WWW-Authenticate": "Bearer"
        ],
        icon: "lock.circle"
    )

    static let validationError = Template(
        id: "validation-error",
        name: "Validation Error",
        statusCode: 422,
        responseBody: """
        {
          "error" : "Validation Error",
          "errors" : [
            {
              "field" : "email",
              "message" : "Invalid email format"
            },
            {
              "field" : "name",
              "message" : "Name is required"
            }
          ]
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "exclamationmark.triangle"
    )

    static let serverError = Template(
        id: "server-error",
        name: "Server Error",
        statusCode: 500,
        responseBody: """
        {
          "error" : "Internal Server Error",
          "message" : "An unexpected error occurred"
        }
        """,
        responseHeaders: ["Content-Type": "application/json"],
        icon: "xmark.octagon"
    )

    static let rateLimited = Template(
        id: "rate-limited",
        name: "Rate Limited",
        statusCode: 429,
        responseBody: """
        {
          "error" : "Too Many Requests",
          "message" : "Rate limit exceeded",
          "retryAfter" : 60
        }
        """,
        responseHeaders: [
            "Content-Type": "application/json",
            "Retry-After": "60"
        ],
        icon: "gauge.with.needle"
    )

    static let all: [Template] = [
        success,
        userObject,
        userList,
        notFound,
        unauthorized,
        validationError,
        serverError,
        rateLimited
    ]
}
