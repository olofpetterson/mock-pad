//
//  MockResponseGeneratorTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
@testable import MockPad

struct MockResponseGeneratorTests {

    // MARK: - Helpers

    private func jsonValue(from schema: [String: Any], in document: [String: Any] = [:]) -> Any {
        var visited = Set<String>()
        return MockResponseGenerator.generate(from: schema, in: document, visited: &visited, depth: 0)
    }

    private func jsonString(from schema: [String: Any], in document: [String: Any] = [:]) -> String {
        MockResponseGenerator.generateJSON(from: schema, in: document)
    }

    // MARK: - Test 1: String type

    @Test func stringType() {
        let result = jsonValue(from: ["type": "string"])
        #expect(result as? String == "string")
    }

    // MARK: - Test 2: String with date format

    @Test func stringDateFormat() {
        let result = jsonValue(from: ["type": "string", "format": "date"])
        #expect(result as? String == "2024-01-01")
    }

    // MARK: - Test 3: String with email format

    @Test func stringEmailFormat() {
        let result = jsonValue(from: ["type": "string", "format": "email"])
        #expect(result as? String == "user@example.com")
    }

    // MARK: - Test 4: String with date-time format

    @Test func stringDateTimeFormat() {
        let result = jsonValue(from: ["type": "string", "format": "date-time"])
        #expect(result as? String == "2024-01-01T00:00:00Z")
    }

    // MARK: - Test 5: String with uuid format

    @Test func stringUUIDFormat() {
        let result = jsonValue(from: ["type": "string", "format": "uuid"])
        #expect(result as? String == "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - Test 6: String with uri format

    @Test func stringURIFormat() {
        let result = jsonValue(from: ["type": "string", "format": "uri"])
        #expect(result as? String == "https://example.com")
    }

    // MARK: - Test 7: Integer type

    @Test func integerType() {
        let result = jsonValue(from: ["type": "integer"])
        #expect(result as? Int == 0)
    }

    // MARK: - Test 8: Number type

    @Test func numberType() {
        let result = jsonValue(from: ["type": "number"])
        #expect(result as? Double == 0.0)
    }

    // MARK: - Test 9: Boolean type

    @Test func booleanType() {
        let result = jsonValue(from: ["type": "boolean"])
        #expect(result as? Bool == true)
    }

    // MARK: - Test 10: Object with properties

    @Test func objectWithProperties() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"] as [String: Any],
                "age": ["type": "integer"] as [String: Any]
            ] as [String: Any]
        ]
        let result = jsonValue(from: schema) as? [String: Any]
        #expect(result?["name"] as? String == "string")
        #expect(result?["age"] as? Int == 0)
    }

    // MARK: - Test 11: Array with items

    @Test func arrayWithItems() {
        let schema: [String: Any] = [
            "type": "array",
            "items": ["type": "string"] as [String: Any]
        ]
        let result = jsonValue(from: schema) as? [Any]
        #expect(result?.count == 1)
        #expect(result?.first as? String == "string")
    }

    // MARK: - Test 12: Schema with example field (priority over type)

    @Test func exampleFieldPriority() {
        let schema: [String: Any] = [
            "type": "string",
            "example": "Fido"
        ]
        let result = jsonValue(from: schema)
        #expect(result as? String == "Fido")
    }

    // MARK: - Test 13: Schema with enum field (returns first value)

    @Test func enumFieldReturnsFirst() {
        let schema: [String: Any] = [
            "type": "string",
            "enum": ["active", "inactive", "deleted"]
        ]
        let result = jsonValue(from: schema)
        #expect(result as? String == "active")
    }

    // MARK: - Test 14: $ref resolution

    @Test func refResolution() {
        let document: [String: Any] = [
            "components": [
                "schemas": [
                    "Pet": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let schema: [String: Any] = ["$ref": "#/components/schemas/Pet"]
        let result = jsonValue(from: schema, in: document) as? [String: Any]
        #expect(result?["name"] as? String == "string")
    }

    // MARK: - Test 15: Circular $ref protection

    @Test func circularRefProtection() {
        let document: [String: Any] = [
            "components": [
                "schemas": [
                    "Node": [
                        "type": "object",
                        "properties": [
                            "value": ["type": "string"] as [String: Any],
                            "child": ["$ref": "#/components/schemas/Node"] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let schema: [String: Any] = ["$ref": "#/components/schemas/Node"]
        // Should not crash or hang -- circular ref returns placeholder
        let result = jsonValue(from: schema, in: document) as? [String: Any]
        #expect(result != nil)
        #expect(result?["value"] as? String == "string")
    }

    // MARK: - Test 16: allOf merges properties

    @Test func allOfMergesProperties() {
        let schema: [String: Any] = [
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
        ]
        let result = jsonValue(from: schema) as? [String: Any]
        #expect(result?["id"] as? Int == 0)
        #expect(result?["name"] as? String == "string")
    }

    // MARK: - Test 17: oneOf uses first option

    @Test func oneOfUsesFirstOption() {
        let schema: [String: Any] = [
            "oneOf": [
                ["type": "string"] as [String: Any],
                ["type": "integer"] as [String: Any]
            ]
        ]
        let result = jsonValue(from: schema)
        #expect(result as? String == "string")
    }

    // MARK: - Test 18: anyOf uses first option

    @Test func anyOfUsesFirstOption() {
        let schema: [String: Any] = [
            "anyOf": [
                ["type": "integer"] as [String: Any],
                ["type": "string"] as [String: Any]
            ]
        ]
        let result = jsonValue(from: schema)
        #expect(result as? Int == 0)
    }

    // MARK: - Test 19: Empty array (no items schema)

    @Test func emptyArrayNoItems() {
        let schema: [String: Any] = ["type": "array"]
        let result = jsonValue(from: schema) as? [Any]
        #expect(result?.count == 0)
    }

    // MARK: - Test 20: Empty object (no properties)

    @Test func emptyObjectNoProperties() {
        let schema: [String: Any] = ["type": "object"]
        let result = jsonValue(from: schema) as? [String: Any]
        #expect(result?.isEmpty == true)
    }

    // MARK: - Test 21: No type field defaults to object

    @Test func noTypeDefaultsToObject() {
        let schema: [String: Any] = [
            "properties": [
                "id": ["type": "integer"] as [String: Any]
            ] as [String: Any]
        ]
        let result = jsonValue(from: schema) as? [String: Any]
        #expect(result?["id"] as? Int == 0)
    }

    // MARK: - Test 22: generateJSON produces valid JSON string

    @Test func generateJSONProducesValidString() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"] as [String: Any]
            ] as [String: Any]
        ]
        let json = jsonString(from: schema)
        // Should be parseable JSON
        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["name"] as? String == "string")
    }

    // MARK: - Test 23: allOf with $ref

    @Test func allOfWithRef() {
        let document: [String: Any] = [
            "components": [
                "schemas": [
                    "Base": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "integer"] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        let schema: [String: Any] = [
            "allOf": [
                ["$ref": "#/components/schemas/Base"] as [String: Any],
                [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"] as [String: Any]
                    ] as [String: Any]
                ] as [String: Any]
            ]
        ]
        let result = jsonValue(from: schema, in: document) as? [String: Any]
        #expect(result?["id"] as? Int == 0)
        #expect(result?["name"] as? String == "string")
    }

    // MARK: - Test 24: String with url format

    @Test func stringURLFormat() {
        let result = jsonValue(from: ["type": "string", "format": "url"])
        #expect(result as? String == "https://example.com")
    }

    // MARK: - Test 25: External ref returns placeholder

    @Test func externalRefReturnsPlaceholder() {
        let schema: [String: Any] = ["$ref": "./external.yaml#/Pet"]
        let result = jsonValue(from: schema)
        #expect(result as? String == "...")
    }
}
