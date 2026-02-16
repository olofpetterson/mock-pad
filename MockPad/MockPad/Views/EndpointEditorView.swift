//
//  EndpointEditorView.swift
//  MockPad
//

import SwiftUI

struct EndpointEditorView: View {
    @Bindable var endpoint: MockEndpoint
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                TextField("/api/resource", text: $endpoint.path)
                    .font(MockPadTypography.monoInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("> PATH_")
                    .blueprintLabelStyle()
            }
            .listRowBackground(MockPadColors.panel)

            Section {
                HTTPMethodPickerView(selectedMethod: $endpoint.httpMethod)
            } header: {
                Text("> METHOD_")
                    .blueprintLabelStyle()
            }
            .listRowBackground(MockPadColors.panel)

            Section {
                StatusCodePickerView(selectedCode: $endpoint.responseStatusCode)
            } header: {
                Text("> STATUS CODE_")
                    .blueprintLabelStyle()
            }
            .listRowBackground(MockPadColors.panel)

            Section {
                ResponseBodyEditorView(text: $endpoint.responseBody, onChanged: {
                    saveAndSync()
                })
            }
            .listRowBackground(MockPadColors.panel)

            Section {
                ResponseHeadersEditorView(endpoint: endpoint, onChanged: {
                    saveAndSync()
                })
            }
            .listRowBackground(MockPadColors.panel)
        }
        .scrollContentBackground(.hidden)
        .background(MockPadColors.background)
        .navigationTitle(endpoint.path)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: endpoint.path) { _, _ in
            saveAndSync()
        }
        .onChange(of: endpoint.httpMethod) { _, _ in
            saveAndSync()
        }
        .onChange(of: endpoint.responseStatusCode) { _, _ in
            saveAndSync()
        }
    }

    private func saveAndSync() {
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
