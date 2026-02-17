//
//  SampleEndpointGenerator.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum SampleEndpointGenerator {
    static func createSampleEndpoints() -> [MockEndpoint] {
        [
            MockEndpoint(
                path: "/api/users",
                httpMethod: "GET",
                responseStatusCode: 200,
                responseBody: """
                [
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
                ]
                """,
                sortOrder: 0
            ),
            MockEndpoint(
                path: "/api/users/:id",
                httpMethod: "GET",
                responseStatusCode: 200,
                responseBody: """
                {
                  "email" : "jane@example.com",
                  "id" : 1,
                  "name" : "Jane Smith"
                }
                """,
                sortOrder: 1
            ),
            MockEndpoint(
                path: "/api/users",
                httpMethod: "POST",
                responseStatusCode: 201,
                responseBody: """
                {
                  "id" : 3,
                  "message" : "User created"
                }
                """,
                sortOrder: 2
            ),
            MockEndpoint(
                path: "/api/users/:id",
                httpMethod: "DELETE",
                responseStatusCode: 204,
                responseBody: "",
                sortOrder: 3
            )
        ]
    }
}
