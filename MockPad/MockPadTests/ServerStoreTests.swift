//
//  ServerStoreTests.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Testing
import Foundation
@testable import MockPad

struct ServerStoreTests {
    @Test func defaultValues() {
        let store = ServerStore()

        #expect(store.port == ServerConfiguration.port)
        #expect(store.corsEnabled == ServerConfiguration.corsEnabled)
        #expect(store.autoStart == ServerConfiguration.autoStart)
    }

    @Test func serverURL() {
        let store = ServerStore()

        #expect(store.serverURL == "http://localhost:\(store.port)")
    }

    @Test func isRunningDefaultsFalse() {
        let store = ServerStore()

        #expect(store.isRunning == false)
    }

    @Test func portWriteThrough() {
        let store = ServerStore()
        let originalPort = store.port

        store.port = 9090
        #expect(ServerConfiguration.port == 9090)

        // Reset to original value to avoid side effects
        store.port = originalPort
    }
}
