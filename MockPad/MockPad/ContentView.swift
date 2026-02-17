//
//  ContentView.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager

    // iPad state
    @State private var selectedEndpointID: PersistentIdentifier?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // iPad settings sheet
    @State private var showSettings = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
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
        .task {
            await proManager.loadProduct()
            await proManager.checkEntitlements()
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedEndpointID: $selectedEndpointID)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        } content: {
            if let id = selectedEndpointID,
               let endpoint = endpointStore.endpoint(withID: id) {
                EndpointEditorView(endpoint: endpoint)
            } else {
                ContentUnavailableView(
                    "Select an Endpoint",
                    systemImage: "curlybraces",
                    description: Text("Choose an endpoint from the sidebar to edit its configuration")
                )
            }
        } detail: {
            NavigationStack {
                RequestLogListView()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            ServerStatusBarView()

            TabView {
                NavigationStack {
                    EndpointListView()
                }
                .tabItem {
                    Label("Endpoints", systemImage: "list.bullet")
                }

                NavigationStack {
                    RequestLogListView()
                }
                .tabItem {
                    Label("Log", systemImage: "scroll")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}
