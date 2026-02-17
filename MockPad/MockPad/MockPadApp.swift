//
//  MockPadApp.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import SwiftUI
import SwiftData

@main
struct MockPadApp: App {
    let modelContainer: ModelContainer

    @State private var endpointStore: EndpointStore
    @State private var serverStore: ServerStore
    @State private var proManager = ProManager.shared

    init() {
        UserDefaults.standard.register(defaults: [
            "serverPort": 8080,
            "corsEnabled": true,
            "autoStart": true
        ])

        do {
            let container = try ModelContainer(
                for: MockEndpoint.self, RequestLog.self, ResponseTemplate.self
            )
            self.modelContainer = container
            let context = ModelContext(container)
            self._endpointStore = State(initialValue: EndpointStore(modelContext: context))
            self._serverStore = State(initialValue: ServerStore())
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(endpointStore)
                .environment(serverStore)
                .environment(proManager)
        }
        .modelContainer(modelContainer)
    }
}
