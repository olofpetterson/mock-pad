//
//  PathParamReplacerTests.swift
//  MockPadTests
//
//  Created with GSD workflow on 2026-02-17.
//

import Testing
import Foundation
@testable import MockPad

struct PathParamReplacerTests {

    // MARK: - Single Token

    @Test func singleToken_replaced() {
        let result = PathParamReplacer.replace(in: "{\"id\": {id}}", with: ["id": "42"])
        #expect(result == "{\"id\": 42}")
    }

    // MARK: - Multiple Tokens

    @Test func multipleTokens_allReplaced() {
        let result = PathParamReplacer.replace(
            in: "{\"userId\": {userId}, \"postId\": {postId}}",
            with: ["userId": "42", "postId": "7"]
        )
        #expect(result == "{\"userId\": 42, \"postId\": 7}")
    }

    // MARK: - No Params (Empty Dict)

    @Test func emptyParams_returnsUnchanged() {
        let body = "{\"id\": {id}}"
        let result = PathParamReplacer.replace(in: body, with: [:])
        #expect(result == body)
    }

    // MARK: - No Matching Tokens

    @Test func noMatchingTokens_returnsUnchanged() {
        let body = "no tokens here"
        let result = PathParamReplacer.replace(in: body, with: ["id": "42"])
        #expect(result == body)
    }

    // MARK: - Case-Sensitive Mismatch

    @Test func caseSensitiveMismatch_noReplacement() {
        let result = PathParamReplacer.replace(in: "{ID}", with: ["id": "42"])
        #expect(result == "{ID}")
    }

    // MARK: - Token Inside Quoted String

    @Test func tokenInsideQuotedString_replaced() {
        let result = PathParamReplacer.replace(
            in: "{\"name\": \"User {id}\"}",
            with: ["id": "42"]
        )
        #expect(result == "{\"name\": \"User 42\"}")
    }
}
