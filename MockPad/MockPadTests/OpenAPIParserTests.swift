//
//  OpenAPIParserTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
@testable import MockPad

struct OpenAPIParserTests {

    // MARK: - Helpers

    /// Create minimal valid OpenAPI 3.0 JSON data
    private func minimalSpec(
        title: String = "Test API",
        version: String = "1.0.0",
        paths: [String: Any] = [
            "/pets": [
                "get": [
                    "summary": "List pets",
                    "responses": [
                        "200": [
                            "description": "OK",
                            "content": [
                                "application/json": [
                                    "schema": [
                                        "type": "array",
                                        "items": ["type": "string"] as [String: Any]
                                    ] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
    ) -> Data {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": [
                "title": title,
                "version": version
            ] as [String: Any],
            "paths": paths
        ]
        return try! JSONSerialization.data(withJSONObject: spec)
    }

    // MARK: - Test 1: Valid minimal OpenAPI 3.0 JSON

    @Test func validMinimalSpec() throws {
        let data = minimalSpec()
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.title == "Test API")
        #expect(result.version == "1.0.0")
        #expect(result.endpoints.count == 1)
        #expect(result.endpoints.first?.path == "/pets")
        #expect(result.endpoints.first?.httpMethod == "GET")
    }

    // MARK: - Test 2: Multiple paths and methods

    @Test func multiplePathsAndMethods() throws {
        let paths: [String: Any] = [
            "/pets": [
                "get": [
                    "summary": "List pets",
                    "responses": [
                        "200": [
                            "description": "OK"
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any],
                "post": [
                    "summary": "Create pet",
                    "responses": [
                        "201": [
                            "description": "Created"
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any],
            "/users": [
                "get": [
                    "summary": "List users",
                    "responses": [
                        "200": [
                            "description": "OK"
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.count == 3)
        let methods = result.endpoints.map { $0.httpMethod }.sorted()
        #expect(methods.contains("GET"))
        #expect(methods.contains("POST"))
    }

    // MARK: - Test 3: Missing openapi field throws notOpenAPI

    @Test func missingOpenAPIFieldThrowsNotOpenAPI() {
        let spec: [String: Any] = [
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": ["/test": ["get": ["responses": ["200": ["description": "OK"]]]]] as [String: Any]
        ]
        let data = try! JSONSerialization.data(withJSONObject: spec)

        #expect(throws: OpenAPIParser.ParseError.notOpenAPI) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 4: Swagger 2.0 throws unsupportedVersion

    @Test func swagger20ThrowsUnsupportedVersion() {
        let spec: [String: Any] = [
            "swagger": "2.0",
            "info": ["title": "Old API", "version": "1.0"] as [String: Any],
            "paths": ["/test": ["get": ["responses": ["200": ["description": "OK"]]]]] as [String: Any]
        ]
        let data = try! JSONSerialization.data(withJSONObject: spec)

        #expect(throws: OpenAPIParser.ParseError.unsupportedVersion("2.0 (Swagger)")) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 5: Unsupported openapi version

    @Test func unsupportedOpenAPIVersion() {
        let spec: [String: Any] = [
            "openapi": "2.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": ["/test": [:] as [String: Any]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: spec)

        #expect(throws: OpenAPIParser.ParseError.unsupportedVersion("2.0")) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 6: Missing paths throws noPaths

    @Test func missingPathsThrowsNoPaths() {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any]
        ]
        let data = try! JSONSerialization.data(withJSONObject: spec)

        #expect(throws: OpenAPIParser.ParseError.noPaths) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 7: Empty paths throws noPaths

    @Test func emptyPathsThrowsNoPaths() {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": [:] as [String: Any]
        ]
        let data = try! JSONSerialization.data(withJSONObject: spec)

        #expect(throws: OpenAPIParser.ParseError.noPaths) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 8: Path parameter conversion

    @Test func pathParameterConversion() throws {
        let paths: [String: Any] = [
            "/users/{userId}/posts/{postId}": [
                "get": [
                    "summary": "Get post",
                    "responses": [
                        "200": ["description": "OK"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.path == "/users/:userId/posts/:postId")
    }

    // MARK: - Test 9: Path with no parameters unchanged

    @Test func pathNoParametersUnchanged() throws {
        let data = minimalSpec()
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.path == "/pets")
    }

    // MARK: - Test 10: Response status code selection 200

    @Test func responseStatusCode200() throws {
        let paths: [String: Any] = [
            "/test": [
                "get": [
                    "responses": [
                        "200": [
                            "description": "OK",
                            "content": [
                                "application/json": [
                                    "schema": ["type": "string"] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any],
                        "404": ["description": "Not found"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.responseStatusCode == 200)
    }

    // MARK: - Test 11: Response status code selection 201 only

    @Test func responseStatusCode201Only() throws {
        let paths: [String: Any] = [
            "/test": [
                "post": [
                    "summary": "Create",
                    "responses": [
                        "201": [
                            "description": "Created",
                            "content": [
                                "application/json": [
                                    "schema": ["type": "object"] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.responseStatusCode == 201)
    }

    // MARK: - Test 12: Response fallback to default

    @Test func responseFallbackToDefault() throws {
        let paths: [String: Any] = [
            "/test": [
                "get": [
                    "responses": [
                        "404": ["description": "Not found"] as [String: Any],
                        "default": [
                            "description": "Default response",
                            "content": [
                                "application/json": [
                                    "schema": ["type": "object"] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        // default maps to status 200
        #expect(result.endpoints.first?.responseStatusCode == 200)
    }

    // MARK: - Test 13: $ref in response object

    @Test func refInResponseObject() throws {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": [
                "/pets": [
                    "get": [
                        "responses": [
                            "200": ["$ref": "#/components/responses/PetList"] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any],
            "components": [
                "responses": [
                    "PetList": [
                        "description": "Pet list",
                        "content": [
                            "application/json": [
                                "schema": [
                                    "type": "array",
                                    "items": ["type": "string"] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.responseStatusCode == 200)
        #expect(!result.endpoints.first!.responseBody.isEmpty)
    }

    // MARK: - Test 14: Operation summary extracted

    @Test func operationSummaryExtracted() throws {
        let data = minimalSpec()
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.summary == "List pets")
    }

    // MARK: - Test 15: No summary, has description -> uses description

    @Test func descriptionAsSummaryFallback() throws {
        let paths: [String: Any] = [
            "/test": [
                "get": [
                    "description": "This is a description",
                    "responses": [
                        "200": ["description": "OK"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.summary == "This is a description")
    }

    // MARK: - Test 16: Global warnings for webhooks and securitySchemes

    @Test func globalWarnings() throws {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": [
                "/test": [
                    "get": [
                        "responses": ["200": ["description": "OK"] as [String: Any]] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any],
            "webhooks": ["newPet": [:] as [String: Any]] as [String: Any],
            "components": [
                "securitySchemes": [
                    "apiKey": ["type": "apiKey"] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.globalWarnings.contains { $0.contains("Webhooks") })
        #expect(result.globalWarnings.contains { $0.contains("Security") || $0.contains("security") })
    }

    // MARK: - Test 17: Per-endpoint warnings for callbacks

    @Test func perEndpointCallbackWarning() throws {
        let paths: [String: Any] = [
            "/test": [
                "post": [
                    "summary": "Create with callback",
                    "callbacks": [
                        "onEvent": ["/callback": [:] as [String: Any]] as [String: Any]
                    ] as [String: Any],
                    "responses": [
                        "200": ["description": "OK"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        let endpoint = result.endpoints.first
        #expect(endpoint?.warnings.contains { $0.contains("Callback") || $0.contains("callback") } == true)
    }

    // MARK: - Test 18: YAML input via YAMLConverter fallback

    @Test func yamlInputParsed() throws {
        let yaml = """
        openapi: "3.0.0"
        info:
          title: YAML API
          version: "2.0.0"
        paths:
          /items:
            get:
              summary: List items
              responses:
                200:
                  description: OK
        """
        let data = yaml.data(using: .utf8)!
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.title == "YAML API")
        #expect(result.version == "2.0.0")
        #expect(result.endpoints.count == 1)
        #expect(result.endpoints.first?.path == "/items")
    }

    // MARK: - Test 19: allOf in schema generates merged response

    @Test func allOfInSchemaGeneratesMergedResponse() throws {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": [
                "/test": [
                    "get": [
                        "responses": [
                            "200": [
                                "description": "OK",
                                "content": [
                                    "application/json": [
                                        "schema": [
                                            "allOf": [
                                                [
                                                    "type": "object",
                                                    "properties": [
                                                        "id": ["type": "integer"] as [String: Any]
                                                    ] as [String: Any]
                                                ] as [String: Any],
                                                [
                                                    "type": "object",
                                                    "properties": [
                                                        "name": ["type": "string"] as [String: Any]
                                                    ] as [String: Any]
                                                ] as [String: Any]
                                            ]
                                        ] as [String: Any]
                                    ] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        let body = result.endpoints.first?.responseBody ?? ""
        #expect(body.contains("id"))
        #expect(body.contains("name"))
    }

    // MARK: - Test 20: Invalid JSON throws invalidJSON

    @Test func invalidJSONThrows() {
        let data = "not json or yaml {{{".data(using: .utf8)!

        #expect(throws: OpenAPIParser.ParseError.self) {
            try OpenAPIParser.parse(data: data)
        }
    }

    // MARK: - Test 21: isSelected defaults to true

    @Test func isSelectedDefaultsToTrue() throws {
        let data = minimalSpec()
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.isSelected == true)
    }

    // MARK: - Test 22: responseHeaders has Content-Type

    @Test func responseHeadersContentType() throws {
        let data = minimalSpec()
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.endpoints.first?.responseHeaders["Content-Type"] == "application/json")
    }

    // MARK: - Test 23: Default title when info.title is missing

    @Test func defaultTitleWhenMissing() throws {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": [:] as [String: Any],
            "paths": [
                "/test": [
                    "get": [
                        "responses": ["200": ["description": "OK"] as [String: Any]] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.title == "Untitled API")
        #expect(result.version == "0.0.0")
    }

    // MARK: - Test 24: Schema component warnings for oneOf/anyOf

    @Test func schemaComponentWarnings() throws {
        let spec: [String: Any] = [
            "openapi": "3.0.0",
            "info": ["title": "Test", "version": "1.0"] as [String: Any],
            "paths": [
                "/test": [
                    "get": [
                        "responses": ["200": ["description": "OK"] as [String: Any]] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any],
            "components": [
                "schemas": [
                    "Mixed": [
                        "oneOf": [
                            ["type": "string"] as [String: Any],
                            ["type": "integer"] as [String: Any]
                        ]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.globalWarnings.contains { $0.contains("oneOf") })
    }

    // MARK: - Test 25: OpenAPI 3.1.x version accepted

    @Test func openAPI31Accepted() throws {
        let spec: [String: Any] = [
            "openapi": "3.1.0",
            "info": ["title": "Test 3.1", "version": "1.0"] as [String: Any],
            "paths": [
                "/test": [
                    "get": [
                        "responses": ["200": ["description": "OK"] as [String: Any]] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = try JSONSerialization.data(withJSONObject: spec)
        let result = try OpenAPIParser.parse(data: data)

        #expect(result.title == "Test 3.1")
    }

    // MARK: - Test 26: Per-endpoint security warning

    @Test func perEndpointSecurityWarning() throws {
        let paths: [String: Any] = [
            "/secure": [
                "get": [
                    "summary": "Secured endpoint",
                    "security": [
                        ["apiKey": []] as [String: Any]
                    ],
                    "responses": [
                        "200": ["description": "OK"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let data = minimalSpec(paths: paths)
        let result = try OpenAPIParser.parse(data: data)

        let endpoint = result.endpoints.first
        #expect(endpoint?.warnings.contains { $0.contains("Security") || $0.contains("security") } == true)
    }
}
