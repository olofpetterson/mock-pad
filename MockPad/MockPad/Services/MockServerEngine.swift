//
//  MockServerEngine.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-16.
//

import Foundation
import Network

/// Core server engine actor. Owns NWListener, manages TCP connections,
/// and wires together HTTPRequestParser, EndpointMatcher, and
/// HTTPResponseBuilder for the complete request/response cycle.
///
/// Uses a custom actor (not MainActor) to avoid blocking UI during
/// NWListener callbacks. All NWListener/NWConnection callbacks bridge
/// to actor isolation via `Task { [weak self] in await self?.method() }`.
///
/// CRITICAL: NWListener cannot be restarted after cancellation (SR-13918).
/// A new NWListener instance is created on every start() call.
actor MockServerEngine {

    // MARK: - Properties

    private var listener: NWListener?
    private var connectionMap: [ObjectIdentifier: NWConnection] = [:]
    private var endpoints: [EndpointSnapshot] = []
    private var corsEnabled: Bool = true
    private var localhostOnly: Bool = true
    private let maxConnections = 50
    private let maxRequestSize = 64 * 1024  // 64KB

    /// Callback for reporting request log data to MainActor.
    /// Must be @Sendable for safe cross-actor transfer.
    var onRequestLogged: (@Sendable (RequestLogData) -> Void)?

    /// Whether the server is currently listening for connections.
    private(set) var isListening: Bool = false

    /// Whether the listener has reached a terminal state (ready, failed, or cancelled).
    private var listenerSettled: Bool = false

    /// The actual port the server is listening on (may differ from requested port).
    private(set) var actualPort: UInt16 = 0

    /// Set the request log callback from outside the actor.
    func setOnRequestLogged(_ callback: (@Sendable (RequestLogData) -> Void)?) {
        onRequestLogged = callback
    }

    // MARK: - Public API

    /// Start the server on the specified port with the given endpoint configuration.
    ///
    /// Creates a new NWListener each time (cannot reuse cancelled listener per SR-13918).
    /// Configures acceptLocalOnly and allowLocalEndpointReuse for localhost-only operation.
    ///
    /// - Parameters:
    ///   - port: TCP port to listen on
    ///   - endpoints: Snapshot of endpoint configurations for request matching
    ///   - corsEnabled: Whether to include CORS headers in responses
    ///   - localhostOnly: Whether to bind to loopback address only (127.0.0.1)
    /// - Throws: MockServerError if already running or port is invalid
    func start(port: UInt16, endpoints: [EndpointSnapshot], corsEnabled: Bool, localhostOnly: Bool) throws {
        guard !isListening else {
            throw MockServerError.alreadyRunning
        }

        self.localhostOnly = localhostOnly

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MockServerError.invalidPort
        }

        // Configure TCP parameters
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = localhostOnly
        parameters.allowLocalEndpointReuse = true

        // When localhost-only, bind to loopback address (127.0.0.1) to reject
        // connections from other devices on the same network
        if localhostOnly {
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host.ipv4(.loopback),
                port: nwPort
            )
        }

        // MUST create new NWListener each time -- cannot restart cancelled listener
        let newListener = try NWListener(using: parameters, on: nwPort)

        // Bridge NWListener state changes to actor isolation
        newListener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }

        // Bridge new connection events to actor isolation
        newListener.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleNewConnection(connection) }
        }

        let queue = DispatchQueue(label: "com.mockpad.server")
        self.listenerSettled = false
        newListener.start(queue: queue)

        self.listener = newListener
        self.endpoints = endpoints
        self.corsEnabled = corsEnabled
    }

    /// Wait until the listener reaches a definitive state (.ready or .failed).
    /// Returns true if the server is listening, false if it failed or timed out.
    func awaitReady(timeout: Duration = .seconds(2)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if listenerSettled { return isListening }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return isListening
    }

    /// Stop the server, cancelling the listener and all active connections.
    func stop() {
        listener?.cancel()
        listener = nil

        for (_, connection) in connectionMap {
            connection.cancel()
        }
        connectionMap.removeAll()

        isListening = false
        actualPort = 0
    }

    /// Update the endpoint configuration while the server is running.
    /// Called from ServerStore when the user adds, edits, or deletes endpoints.
    ///
    /// - Parameter endpoints: New snapshot of endpoint configurations
    func updateEndpoints(_ endpoints: [EndpointSnapshot]) {
        self.endpoints = endpoints
    }

    // MARK: - Listener State Handling

    /// Handle NWListener state transitions.
    /// Called from stateUpdateHandler via Task bridging.
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            actualPort = listener?.port?.rawValue ?? 0
            listenerSettled = true
        case .failed:
            listenerSettled = true
            stop()
        case .cancelled:
            isListening = false
            listenerSettled = true
        default:
            break
        }
    }

    // MARK: - Connection Handling

    /// Handle a new incoming TCP connection.
    /// Enforces the maximum connection limit and sets up connection lifecycle.
    private func handleNewConnection(_ connection: NWConnection) {
        // Enforce connection limit
        guard connectionMap.count < maxConnections else {
            let response = HTTPResponseBuilder.build(
                statusCode: 503,
                headers: ["Content-Type": "application/json"],
                body: "{\"error\":\"Service Unavailable\"}",
                corsEnabled: corsEnabled
            )
            connection.send(content: response, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
            return
        }

        let id = ObjectIdentifier(connection)
        connectionMap[id] = connection

        // Monitor connection state for cleanup
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                Task { await self?.removeConnection(id) }
            default:
                break
            }
        }

        let queue = DispatchQueue(label: "com.mockpad.connection.\(id.hashValue)")
        connection.start(queue: queue)

        receiveRequest(connection: connection, id: id)
    }

    /// Remove a connection from the tracking map.
    private func removeConnection(_ id: ObjectIdentifier) {
        connectionMap.removeValue(forKey: id)
    }

    // MARK: - Request Receiving

    /// Begin receiving data from a connection.
    private func receiveRequest(connection: NWConnection, id: ObjectIdentifier) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: maxRequestSize
        ) { [weak self] data, _, _, _ in
            Task { await self?.handleReceivedData(data: data, connection: connection, id: id) }
        }
    }

    // MARK: - Request Processing

    /// Process received data: parse, match, build response, apply delay, send, log, close.
    private func handleReceivedData(data: Data?, connection: NWConnection, id: ObjectIdentifier) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Guard: data must exist and be non-empty
        guard let data, !data.isEmpty else {
            sendResponse(
                HTTPResponseBuilder.build(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: "{\"error\":\"Bad Request\"}",
                    corsEnabled: corsEnabled
                ),
                on: connection,
                id: id
            )
            return
        }

        // Parse HTTP request
        guard let parsed = HTTPRequestParser.parse(data: data) else {
            sendResponse(
                HTTPResponseBuilder.build(
                    statusCode: 400,
                    headers: ["Content-Type": "application/json"],
                    body: "{\"error\":\"Bad Request\"}",
                    corsEnabled: corsEnabled
                ),
                on: connection,
                id: id
            )
            return
        }

        // Handle CORS preflight
        if parsed.method == "OPTIONS" {
            let preflightResponse = HTTPResponseBuilder.buildPreflightResponse(corsEnabled: corsEnabled)
            let responseTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            let logData = RequestLogData(
                timestamp: Date(),
                method: parsed.method,
                path: parsed.path,
                queryParameters: HTTPRequestParser.parseQueryString(parsed.queryString),
                requestHeaders: parsed.headers,
                requestBody: parsed.body,
                responseStatusCode: 204,
                responseBody: nil,
                responseHeaders: [:],
                matchedEndpointPath: nil,
                responseTimeMs: responseTimeMs
            )
            onRequestLogged?(logData)
            sendResponse(preflightResponse, on: connection, id: id)
            return
        }

        // Convert EndpointSnapshot array to EndpointMatcher.EndpointData tuples
        let endpointData: [EndpointMatcher.EndpointData] = endpoints.map { snapshot in
            (path: snapshot.path,
             method: snapshot.method,
             statusCode: snapshot.statusCode,
             responseBody: snapshot.responseBody,
             responseHeaders: snapshot.responseHeaders,
             isEnabled: snapshot.isEnabled,
             responseDelayMs: snapshot.responseDelayMs)
        }

        // Match request to endpoint
        let matchResult = EndpointMatcher.match(
            method: parsed.method,
            path: parsed.path,
            endpoints: endpointData
        )

        // Build response based on match result
        let responseData: Data
        let responseStatusCode: Int
        let responseBody: String?
        let logResponseHeaders: [String: String]
        let matchedEndpointPath: String?
        var delayMs: Int = 0

        switch matchResult {
        case .matched(let path, _, let statusCode, let body, let headers, let matchedDelayMs, let pathParams):
            delayMs = matchedDelayMs
            responseStatusCode = statusCode
            let resolvedBody = PathParamReplacer.replace(in: body, with: pathParams)
            responseBody = resolvedBody
            matchedEndpointPath = path
            var responseHeaders = headers
            responseHeaders["Content-Type"] = responseHeaders["Content-Type"] ?? "application/json"
            logResponseHeaders = responseHeaders
            responseData = HTTPResponseBuilder.build(
                statusCode: statusCode,
                headers: responseHeaders,
                body: resolvedBody,
                corsEnabled: corsEnabled
            )

        case .notFound:
            responseStatusCode = 404
            let errorBody = "{\"error\":\"Not Found\",\"path\":\"\(parsed.path)\"}"
            responseBody = errorBody
            matchedEndpointPath = nil
            logResponseHeaders = ["Content-Type": "application/json"]
            responseData = HTTPResponseBuilder.build(
                statusCode: 404,
                headers: ["Content-Type": "application/json"],
                body: errorBody,
                corsEnabled: corsEnabled
            )

        case .methodNotAllowed(let allowedMethods):
            responseStatusCode = 405
            let methodsJson = allowedMethods.map { "\"\($0)\"" }.joined(separator: ",")
            let errorBody = "{\"error\":\"Method Not Allowed\",\"allowed\":[\(methodsJson)]}"
            responseBody = errorBody
            matchedEndpointPath = nil
            let allowHeader = allowedMethods.joined(separator: ", ")
            logResponseHeaders = ["Content-Type": "application/json", "Allow": allowHeader]
            responseData = HTTPResponseBuilder.build(
                statusCode: 405,
                headers: [
                    "Content-Type": "application/json",
                    "Allow": allowHeader
                ],
                body: errorBody,
                corsEnabled: corsEnabled
            )
        }

        // Apply configured response delay for matched endpoints only.
        // Non-blocking: actor reentrancy allows other connections to proceed during sleep.
        if delayMs > 0 {
            try? await Task.sleep(for: .milliseconds(delayMs))
        }

        // Calculate response time (includes delay -- correct per success criteria)
        let responseTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let logData = RequestLogData(
            timestamp: Date(),
            method: parsed.method,
            path: parsed.path,
            queryParameters: HTTPRequestParser.parseQueryString(parsed.queryString),
            requestHeaders: parsed.headers,
            requestBody: parsed.body,
            responseStatusCode: responseStatusCode,
            responseBody: responseBody,
            responseHeaders: logResponseHeaders,
            matchedEndpointPath: matchedEndpointPath,
            responseTimeMs: responseTimeMs
        )
        onRequestLogged?(logData)

        // Send response and close connection
        sendResponse(responseData, on: connection, id: id)
    }

    // MARK: - Response Sending

    /// Send response data on a connection, then cancel and remove the connection.
    /// HTTP/1.0 close-after-response pattern.
    private func sendResponse(_ data: Data, on connection: NWConnection, id: ObjectIdentifier) {
        connection.send(content: data, completion: .contentProcessed({ [weak self] _ in
            connection.cancel()
            Task { await self?.removeConnection(id) }
        }))
    }
}
