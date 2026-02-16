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
            await newEngine.setOnRequestLogged { [weak endpointStore] logData in
                Task { @MainActor in
                    guard let endpointStore else { return }
                    let log = RequestLog(
                        timestamp: logData.timestamp,
                        method: logData.method,
                        path: logData.path,
                        queryParameters: logData.queryParameters,
                        requestHeaders: logData.requestHeaders,
                        requestBody: logData.requestBody,
                        responseStatusCode: logData.responseStatusCode,
                        responseBody: logData.responseBody,
                        responseTimeMs: logData.responseTimeMs
                    )
                    endpointStore.addLogEntry(log)
                }
            }

            do {
                try await newEngine.start(port: tryPort, endpoints: snapshots, corsEnabled: corsEnabled)
                // Brief delay for listener state to settle
                try? await Task.sleep(for: .milliseconds(50))
                let listening = await newEngine.isListening
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
