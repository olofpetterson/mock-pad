//
//  ServerStore.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation
import Network

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

    var localhostOnly: Bool {
        didSet { ServerConfiguration.localhostOnly = localhostOnly }
    }

    private var engine: MockServerEngine?
    var errorMessage: String?
    var actualPort: UInt16 = 0

    var serverURL: String {
        isRunning ? "http://localhost:\(actualPort)" : "http://localhost:\(port)"
    }

    init() {
        self.port = ServerConfiguration.port
        self.corsEnabled = ServerConfiguration.corsEnabled
        self.autoStart = ServerConfiguration.autoStart
        self.localhostOnly = ServerConfiguration.localhostOnly
    }

    func startServer(endpointStore: EndpointStore) async {
        guard !isRunning else { return }
        errorMessage = nil

        let snapshots = endpointStore.endpointSnapshots
        let basePort = port
        let maxPort = min(basePort + 10, UInt16.max)

        for tryPort in basePort...maxPort {
            let newEngine = MockServerEngine()

            // Set up log callback -- captures endpointStore for SwiftData persistence
            let store = endpointStore
            await newEngine.setOnRequestLogged { [weak store] logData in
                guard let store else { return }
                Task { @MainActor in
                    let log = RequestLog(
                        timestamp: logData.timestamp,
                        method: logData.method,
                        path: logData.path,
                        queryParameters: logData.queryParameters,
                        requestHeaders: logData.requestHeaders,
                        requestBody: logData.requestBody,
                        responseStatusCode: logData.responseStatusCode,
                        responseBody: logData.responseBody,
                        responseHeaders: logData.responseHeaders,
                        matchedEndpointPath: logData.matchedEndpointPath,
                        responseTimeMs: logData.responseTimeMs
                    )
                    store.addLogEntry(log)
                }
            }

            do {
                try await newEngine.start(port: tryPort, endpoints: snapshots, corsEnabled: corsEnabled, localhostOnly: localhostOnly)
                let listening = await newEngine.awaitReady()
                if listening {
                    self.engine = newEngine
                    self.actualPort = await newEngine.actualPort
                    self.isRunning = true
                    return
                } else {
                    await newEngine.stop()
                }
            } catch {
                continue // Try next port
            }
        }

        errorMessage = "Could not start server on ports \(basePort)-\(maxPort)"
    }

    func stopServer() async {
        await engine?.stop()
        engine = nil
        isRunning = false
        actualPort = 0
    }

    func updateEngineEndpoints(endpointStore: EndpointStore) async {
        guard isRunning else { return }
        let snapshots = endpointStore.endpointSnapshots
        await engine?.updateEndpoints(snapshots)
    }
}
