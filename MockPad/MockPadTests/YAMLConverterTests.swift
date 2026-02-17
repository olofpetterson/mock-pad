//
//  YAMLConverterTests.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
@testable import MockPad

struct YAMLConverterTests {

    // MARK: - Helpers

    private func parseJSON(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private func dict(_ data: Data) throws -> [String: Any] {
        let obj = try parseJSON(data)
        guard let dict = obj as? [String: Any] else {
            throw YAMLConverter.ConversionError.invalidYAML("Expected dictionary")
        }
        return dict
    }

    private func array(_ data: Data) throws -> [Any] {
        let obj = try parseJSON(data)
        guard let arr = obj as? [Any] else {
            throw YAMLConverter.ConversionError.invalidYAML("Expected array")
        }
        return arr
    }

    // MARK: - Test 1: Simple key-value

    @Test func simpleKeyValue() throws {
        let yaml = "name: Petstore"
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["name"] as? String == "Petstore")
    }

    // MARK: - Test 2: Nested mapping (2 levels)

    @Test func nestedMappingTwoLevels() throws {
        let yaml = """
        info:
          title: API
          version: "1.0"
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let info = result["info"] as? [String: Any]
        #expect(info?["title"] as? String == "API")
        #expect(info?["version"] as? String == "1.0")
    }

    // MARK: - Test 3: Nested mapping (3+ levels)

    @Test func nestedMappingDeep() throws {
        let yaml = """
        paths:
          /users:
            get:
              summary: List users
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let paths = result["paths"] as? [String: Any]
        let users = paths?["/users"] as? [String: Any]
        let get = users?["get"] as? [String: Any]
        #expect(get?["summary"] as? String == "List users")
    }

    // MARK: - Test 4: Block sequence (top-level array)

    @Test func blockSequence() throws {
        let yaml = """
        - item1
        - item2
        - item3
        """
        let result = try array(YAMLConverter.toJSON(yaml))

        #expect(result.count == 3)
        #expect(result[0] as? String == "item1")
        #expect(result[1] as? String == "item2")
        #expect(result[2] as? String == "item3")
    }

    // MARK: - Test 5: Sequence of mappings

    @Test func sequenceOfMappings() throws {
        let yaml = """
        items:
          - name: Alice
            age: 30
          - name: Bob
            age: 25
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let items = result["items"] as? [Any]
        #expect(items?.count == 2)

        let first = items?[0] as? [String: Any]
        #expect(first?["name"] as? String == "Alice")
        #expect(first?["age"] as? Int == 30)

        let second = items?[1] as? [String: Any]
        #expect(second?["name"] as? String == "Bob")
        #expect(second?["age"] as? Int == 25)
    }

    // MARK: - Test 6: Scalar types

    @Test func scalarTypes() throws {
        let yaml = """
        intVal: 42
        floatVal: 3.14
        boolTrue: true
        boolFalse: false
        boolTrueCapital: True
        boolFalseCapital: False
        nullVal: null
        tildeNull: ~
        nullCapital: Null
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["intVal"] as? Int == 42)
        #expect(result["floatVal"] as? Double == 3.14)
        #expect(result["boolTrue"] as? Bool == true)
        #expect(result["boolFalse"] as? Bool == false)
        #expect(result["boolTrueCapital"] as? Bool == true)
        #expect(result["boolFalseCapital"] as? Bool == false)
        #expect(result["nullVal"] is NSNull)
        #expect(result["tildeNull"] is NSNull)
        #expect(result["nullCapital"] is NSNull)
    }

    // MARK: - Test 7: Quoted strings (double quotes)

    @Test func doubleQuotedStrings() throws {
        let yaml = """
        title: "Hello: World"
        version: "1.0.0"
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["title"] as? String == "Hello: World")
        #expect(result["version"] as? String == "1.0.0")
    }

    // MARK: - Test 8: Quoted strings (single quotes)

    @Test func singleQuotedStrings() throws {
        let yaml = """
        title: 'Hello: World'
        note: 'it''s fine'
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["title"] as? String == "Hello: World")
        #expect(result["note"] as? String == "it''s fine")
    }

    // MARK: - Test 9: Flow collection array

    @Test func flowCollectionArray() throws {
        let yaml = """
        required: ["id", "name", "email"]
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let required = result["required"] as? [Any]
        #expect(required?.count == 3)
        #expect(required?[0] as? String == "id")
        #expect(required?[1] as? String == "name")
        #expect(required?[2] as? String == "email")
    }

    // MARK: - Test 10: Flow collection object

    @Test func flowCollectionObject() throws {
        let yaml = """
        example: {"id": 1, "name": "test"}
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let example = result["example"] as? [String: Any]
        #expect(example?["id"] as? Int == 1)
        #expect(example?["name"] as? String == "test")
    }

    // MARK: - Test 11: Inline comments

    @Test func inlineComments() throws {
        let yaml = """
        port: 8080 # server port
        host: localhost # the host
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["port"] as? Int == 8080)
        #expect(result["host"] as? String == "localhost")
    }

    // MARK: - Test 12: Empty values (nested object follows)

    @Test func emptyValueWithNestedChildren() throws {
        let yaml = """
        paths:
          /pets:
            get:
              summary: List pets
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let paths = result["paths"] as? [String: Any]
        #expect(paths != nil)
        let pets = paths?["/pets"] as? [String: Any]
        #expect(pets != nil)
        let get = pets?["get"] as? [String: Any]
        #expect(get?["summary"] as? String == "List pets")
    }

    // MARK: - Test 13: Mixed realistic OpenAPI snippet

    @Test func realisticOpenAPISnippet() throws {
        let yaml = """
        openapi: "3.0.0"
        info:
          title: Petstore
          version: "1.0.0"
        paths:
          /pets:
            get:
              summary: List all pets
              responses:
                200:
                  description: A list of pets
          /pets/{petId}:
            get:
              summary: Info for a specific pet
              parameters:
                - name: petId
                  in: path
                  required: true
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        #expect(result["openapi"] as? String == "3.0.0")
        let info = result["info"] as? [String: Any]
        #expect(info?["title"] as? String == "Petstore")

        let paths = result["paths"] as? [String: Any]
        let pets = paths?["/pets"] as? [String: Any]
        let get = pets?["get"] as? [String: Any]
        #expect(get?["summary"] as? String == "List all pets")

        let petId = paths?["/pets/{petId}"] as? [String: Any]
        let petIdGet = petId?["get"] as? [String: Any]
        #expect(petIdGet?["summary"] as? String == "Info for a specific pet")

        let params = petIdGet?["parameters"] as? [Any]
        #expect(params?.count == 1)
        let firstParam = params?[0] as? [String: Any]
        #expect(firstParam?["name"] as? String == "petId")
        #expect(firstParam?["in"] as? String == "path")
        #expect(firstParam?["required"] as? Bool == true)
    }

    // MARK: - Test 14: Multiline literal block (|)

    @Test func multilineLiteralBlock() throws {
        let yaml = """
        description: |
          This is a multi-line
          description field
          for an API endpoint
        title: Test
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let description = result["description"] as? String
        #expect(description?.contains("This is a multi-line") == true)
        #expect(description?.contains("description field") == true)
        #expect(description?.contains("for an API endpoint") == true)
        #expect(result["title"] as? String == "Test")
    }

    // MARK: - Test 15: Error case (invalid YAML)

    @Test func invalidYAMLThrowsError() {
        // Empty input should throw
        #expect(throws: YAMLConverter.ConversionError.self) {
            try YAMLConverter.toJSON("")
        }
    }

    // MARK: - Additional: Folded block (>)

    @Test func foldedBlock() throws {
        let yaml = """
        description: >
          This is a folded
          description that joins
          with spaces
        title: Folded
        """
        let result = try dict(YAMLConverter.toJSON(yaml))

        let description = result["description"] as? String
        #expect(description?.contains("This is a folded") == true)
        #expect(description?.contains("with spaces") == true)
        #expect(result["title"] as? String == "Folded")
    }
}
