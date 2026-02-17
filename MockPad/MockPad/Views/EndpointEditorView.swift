//
//  EndpointEditorView.swift
//  MockPad
//

import SwiftUI

struct EndpointEditorView: View {
    @Bindable var endpoint: MockEndpoint
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(ProManager.self) private var proManager
    @State private var syncTask: Task<Void, Never>?
    @State private var newCollectionName = ""
    @State private var showNewCollectionField = false
    @State private var showPaywall = false

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
                Group {
                    Picker("Collection", selection: $endpoint.collectionName) {
                        Text("None").tag(String?.none)
                        ForEach(endpointStore.collectionNames, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                        if !newCollectionName.isEmpty,
                           !endpointStore.collectionNames.contains(newCollectionName) {
                            Text(newCollectionName).tag(String?.some(newCollectionName))
                        }
                    }
                    .pickerStyle(.menu)

                    if showNewCollectionField {
                        HStack {
                            TextField("Collection name", text: $newCollectionName)
                                .font(MockPadTypography.monoInput)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Button("Create") {
                                guard !newCollectionName.isEmpty else { return }
                                endpoint.collectionName = newCollectionName
                                showNewCollectionField = false
                                newCollectionName = ""
                                saveAndSync()
                            }
                            .disabled(newCollectionName.isEmpty)
                        }
                    } else {
                        Button("New Collection") {
                            showNewCollectionField = true
                        }
                    }
                }
                .opacity(proManager.isPro ? 1 : 0.4)
                .allowsHitTesting(proManager.isPro)
                .overlay {
                    if !proManager.isPro {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { showPaywall = true }
                            .accessibilityLabel("PRO feature, locked")
                            .accessibilityHint("Double tap to view PRO upgrade")
                    }
                }
            } header: {
                Text("> COLLECTION_")
                    .blueprintLabelStyle()
            }
            .listRowBackground(MockPadColors.panel)

            TemplatePickerView(endpoint: endpoint, onApplied: {
                saveAndSync()
            })

            Section {
                Group {
                    VStack(alignment: .leading, spacing: MockPadMetrics.paddingSmall) {
                        HStack {
                            Text("Delay")
                                .font(MockPadTypography.monoSmall)
                            Spacer()
                            Text("\(endpoint.responseDelayMs)ms")
                                .font(MockPadTypography.monoSmall)
                                .foregroundStyle(MockPadColors.accent)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(endpoint.responseDelayMs) },
                                set: { endpoint.responseDelayMs = Int($0) }
                            ),
                            in: 0...10000,
                            step: 100
                        )
                        .tint(MockPadColors.accent)
                        .accessibilityLabel("Response delay, \(endpoint.responseDelayMs) milliseconds")
                        .accessibilityValue("\(endpoint.responseDelayMs) milliseconds")

                        HStack {
                            Text("0ms")
                                .font(MockPadTypography.logTimestamp)
                                .foregroundStyle(MockPadColors.textMuted)
                            Spacer()
                            Text("10,000ms")
                                .font(MockPadTypography.logTimestamp)
                                .foregroundStyle(MockPadColors.textMuted)
                        }
                    }
                }
                .opacity(proManager.isPro ? 1 : 0.4)
                .allowsHitTesting(proManager.isPro)
                .overlay {
                    if !proManager.isPro {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { showPaywall = true }
                            .accessibilityLabel("PRO feature, locked")
                            .accessibilityHint("Double tap to view PRO upgrade")
                    }
                }
            } header: {
                Text("> RESPONSE DELAY_")
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
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
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
        .onChange(of: endpoint.responseDelayMs) { _, _ in
            saveAndSync()
        }
        .onChange(of: endpoint.collectionName) { _, _ in
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
