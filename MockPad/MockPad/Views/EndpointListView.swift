//
//  EndpointListView.swift
//  MockPad
//

import SwiftUI

struct EndpointListView: View {
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(ProManager.self) private var proManager
    @State private var showAddSheet = false
    @State private var showProAlert = false
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        List {
            ForEach(endpointStore.endpoints) { endpoint in
                EndpointRowView(endpoint: endpoint) { newValue in
                    endpoint.isEnabled = newValue
                    endpointStore.updateEndpoint()
                    debouncedSyncEngine()
                }
                .swipeActions(edge: .leading) {
                    Button {
                        duplicateEndpoint(endpoint)
                    } label: {
                        Label("Duplicate", systemImage: "square.on.square")
                    }
                    .tint(MockPadColors.accent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        endpointStore.deleteEndpoint(endpoint)
                        debouncedSyncEngine()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(MockPadColors.background)
                .listRowSeparator(.hidden)
            }
            .onMove(perform: moveEndpoints)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MockPadColors.background)
        .navigationTitle("Endpoints")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if proManager.canAddEndpoint(currentCount: endpointStore.endpointCount) {
                        showAddSheet = true
                    } else {
                        showProAlert = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            Text("Add Endpoint")
        }
        .alert("PRO Required", isPresented: $showProAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Upgrade to PRO to add more than \(ProManager.freeEndpointLimit) endpoints.")
        }
    }

    private func duplicateEndpoint(_ source: MockEndpoint) {
        let maxSortOrder = endpointStore.endpoints.map(\.sortOrder).max() ?? 0
        let copy = MockEndpoint(
            path: source.path,
            httpMethod: source.httpMethod,
            responseStatusCode: source.responseStatusCode,
            responseBody: source.responseBody,
            responseHeaders: source.responseHeaders,
            isEnabled: source.isEnabled,
            sortOrder: maxSortOrder + 1
        )
        endpointStore.addEndpoint(copy)
        debouncedSyncEngine()
    }

    private func moveEndpoints(from source: IndexSet, to destination: Int) {
        var items = endpointStore.endpoints
        items.move(fromOffsets: source, toOffset: destination)
        for (index, endpoint) in items.enumerated() {
            endpoint.sortOrder = index
        }
        endpointStore.updateEndpoint()
        debouncedSyncEngine()
    }

    private func debouncedSyncEngine() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
        }
    }
}
