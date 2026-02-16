//
//  ProManagerTests.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct ProManagerTests {
    @Test func canAddEndpointWhenPro() {
        let manager = ProManager.shared
        manager.setPro(true)

        #expect(manager.canAddEndpoint(currentCount: 5) == true)

        manager.setPro(false)
    }

    @Test func canAddEndpointFreeUnderLimit() {
        let manager = ProManager.shared
        manager.setPro(false)

        #expect(manager.canAddEndpoint(currentCount: 0) == true)
        #expect(manager.canAddEndpoint(currentCount: 1) == true)
        #expect(manager.canAddEndpoint(currentCount: 2) == true)
    }

    @Test func cannotAddEndpointFreeAtLimit() {
        let manager = ProManager.shared
        manager.setPro(false)

        #expect(manager.canAddEndpoint(currentCount: 3) == false)
        #expect(manager.canAddEndpoint(currentCount: 10) == false)
    }

    @Test func canImportEndpointsFreeWithinLimit() {
        let manager = ProManager.shared
        manager.setPro(false)

        #expect(manager.canImportEndpoints(currentCount: 1, importCount: 2) == true)
    }

    @Test func cannotImportEndpointsFreeExceedsLimit() {
        let manager = ProManager.shared
        manager.setPro(false)

        #expect(manager.canImportEndpoints(currentCount: 2, importCount: 2) == false)
    }

    @Test func canImportEndpointsWhenPro() {
        let manager = ProManager.shared
        manager.setPro(true)

        #expect(manager.canImportEndpoints(currentCount: 100, importCount: 50) == true)

        manager.setPro(false)
    }

    @Test func freeEndpointLimitConstant() {
        #expect(ProManager.freeEndpointLimit == 3)
    }
}
