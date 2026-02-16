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
    private let maxConnections = 50
    private let maxRequestSize = 64 * 1024  // 64KB

    /// Callback for reporting request log data to MainActor.
    /// Must be @Sendable for safe cross-actor transfer.
    var onRequestLogged: (@Sendable (RequestLogData) -> Void)?

    /// Whether the server is currently listening for connections.
    private(set) var isListening: Bool = false

    /// The actual port the server is listening on (may differ from requested port).
    private(set) var actualPort: UInt16 = 0

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
    /// - Throws: MockServerError if already running or port is invalid
    func start(port: UInt16, endpoints: [EndpointSnapshot], corsEnabled: Bool) throws {
        guard !isListening else {
            throw MockServerError.alreadyRunning
        }

        // Configure TCP parameters for localhost-only operation
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = true
        parameters.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MockServerError.invalidPort
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
        newListener.start(queue: queue)

        self.listener = newListener
        self.endpoints = endpoints
        self.corsEnabled = corsEnabled
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
        case .failed:
            stop()
        case .cancelled:
            isListening = false
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

    /// Process received data: parse, match, build response, send, log, close.
    private func handleReceivedData(data: Data?, connection: NWConnection, id: ObjectIdentifier) {
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
             isEnabled: snapshot.isEnabled)
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

        switch matchResult {
        case .matched(_, _, let statusCode, let body, let headers):
            responseStatusCode = statusCode
            responseBody = body
            var responseHeaders = headers
            responseHeaders["Content-Type"] = responseHeaders["Content-Type"] ?? "application/json"
            responseData = HTTPResponseBuilder.build(
                statusCode: statusCode,
                headers: responseHeaders,
                body: body,
                corsEnabled: corsEnabled
            )

        case .notFound:
            responseStatusCode = 404
            let errorBody = "{\"error\":\"Not Found\",\"path\":\"\(parsed.path)\"}"
            responseBody = errorBody
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
            let allowHeader = allowedMethods.joined(separator: ", ")
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

        // Calculate response time and log
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
