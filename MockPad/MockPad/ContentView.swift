//
//  ContentView.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore

    var body: some View {
        NavigationStack {
            EndpointListView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if serverStore.autoStart && !serverStore.isRunning {
                    Task {
                        await serverStore.startServer(endpointStore: endpointStore)
                    }
                }
            case .background:
                Task {
                    await serverStore.stopServer()
                }
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(ServerStore())
}
