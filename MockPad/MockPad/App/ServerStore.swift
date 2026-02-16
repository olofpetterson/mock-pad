//
//  ServerStore.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation

@Observable
final class ServerStore {
    var isRunning: Bool = false

    var port: UInt16 {
        didSet { ServerConfiguration.port = port }
    }

    var corsEnabled: Bool {
        didSet { ServerConfiguration.corsEnabled = corsEnabled }
    }

    var autoStart: Bool {
        didSet { ServerConfiguration.autoStart = autoStart }
    }

    var serverURL: String {
        "http://localhost:\(port)"
    }

    init() {
        self.port = ServerConfiguration.port
        self.corsEnabled = ServerConfiguration.corsEnabled
        self.autoStart = ServerConfiguration.autoStart
    }
}
