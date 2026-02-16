//
//  HTTPMethod.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation

enum HTTPMethod {
    static let get = "GET"
    static let post = "POST"
    static let put = "PUT"
    static let patch = "PATCH"
    static let delete = "DELETE"
    static let head = "HEAD"
    static let options = "OPTIONS"

    static let allMethods: [String] = [get, post, put, patch, delete, head, options]
}
