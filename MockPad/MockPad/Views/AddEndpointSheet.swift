//
//  AddEndpointSheet.swift
//  MockPad
//

import SwiftUI

struct AddEndpointSheet: View {
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(\.dismiss) private var dismiss

    @State private var path: String = "/api/"
    @State private var httpMethod: String = "GET"
    @State private var responseStatusCode: Int = 200

    private var canCreate: Bool {
        !path.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("/api/resource", text: $path)
                        .font(MockPadTypography.monoInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("> PATH_")
                        .blueprintLabelStyle()
                }
                .listRowBackground(MockPadColors.panel)

                Section {
                    HTTPMethodPickerView(selectedMethod: $httpMethod)
                } header: {
                    Text("> METHOD_")
                        .blueprintLabelStyle()
                }
                .listRowBackground(MockPadColors.panel)

                Section {
                    StatusCodePickerView(selectedCode: $responseStatusCode)
                } header: {
                    Text("> STATUS CODE_")
                        .blueprintLabelStyle()
                }
                .listRowBackground(MockPadColors.panel)
            }
            .scrollContentBackground(.hidden)
            .background(MockPadColors.background)
            .navigationTitle("New Endpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let endpoint = MockEndpoint(
                            path: path,
                            httpMethod: httpMethod,
                            responseStatusCode: responseStatusCode,
                            sortOrder: endpointStore.endpointCount
                        )
                        endpointStore.addEndpoint(endpoint)
                        Task {
                            await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
                        }
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }
}
