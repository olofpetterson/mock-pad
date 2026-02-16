//
//  ProManager.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation

@Observable
final class ProManager {
    static let shared = ProManager()
    static let freeEndpointLimit = 3

    private(set) var isPro: Bool

    private init() {
        self.isPro = KeychainService.loadBool(forKey: "isPro") ?? false
    }

    func setPro(_ value: Bool) {
        isPro = value
        KeychainService.saveBool(value, forKey: "isPro")
    }

    func canAddEndpoint(currentCount: Int) -> Bool {
        isPro || currentCount < 3
    }

    func canImportEndpoints(currentCount: Int, importCount: Int) -> Bool {
        isPro || (currentCount + importCount) <= 3
    }
}
