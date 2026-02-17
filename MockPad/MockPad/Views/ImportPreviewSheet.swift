//
//  ImportPreviewSheet.swift
//  MockPad
//

import SwiftUI

struct ImportPreviewSheet: View {
    let export: MockPadExport

    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDuplicateResolution = false
    @State private var duplicateCount = 0
    @State private var showLimitAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Collection", value: export.collectionName ?? "Ungrouped")
                    LabeledContent("Endpoints", value: "\(export.endpoints.count)")
                    LabeledContent("Exported", value: export.exportedAt.formatted(.dateTime))
                }
                .listRowBackground(MockPadColors.panel)

                Section("Endpoints") {
                    ForEach(export.endpoints, id: \.uniqueID) { endpoint in
                        HStack(spacing: 12) {
                            Text(endpoint.httpMethod)
                                .methodBadgeStyle(color: MockPadColors.methodColor(for: endpoint.httpMethod))
                                .frame(width: MockPadMetrics.methodBadgeWidth)

                            Text(endpoint.path)
                                .font(MockPadTypography.endpointPathCompact)
                                .foregroundColor(MockPadColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(endpoint.responseStatusCode)")
                                .font(MockPadTypography.statusCode)
                                .foregroundColor(MockPadColors.statusCodeColor(code: endpoint.responseStatusCode))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(endpoint.httpMethod) \(endpoint.path), status \(endpoint.responseStatusCode)")
                    }
                }
                .listRowBackground(MockPadColors.panel)

                Section {
                    Button {
                        importEndpoints()
                    } label: {
                        Text("Import \(export.endpoints.count) Endpoint\(export.endpoints.count == 1 ? "" : "s")")
                            .frame(maxWidth: .infinity)
                            .font(MockPadTypography.button)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MockPadColors.accent)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MockPadColors.background)
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Duplicates Found",
                isPresented: $showDuplicateResolution,
                titleVisibility: .visible
            ) {
                Button("Skip Duplicates") {
                    endpointStore.importEndpoints(export.endpoints, collectionName: export.collectionName, resolution: .skip)
                    dismiss()
                }
                Button("Replace Existing") {
                    endpointStore.importEndpoints(export.endpoints, collectionName: export.collectionName, resolution: .replace)
                    dismiss()
                }
                Button("Import as New") {
                    endpointStore.importEndpoints(export.endpoints, collectionName: export.collectionName, resolution: .importAsNew)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(duplicateCount) of \(export.endpoints.count) endpoint\(export.endpoints.count == 1 ? "" : "s") already exist.")
            }
            .alert("Endpoint Limit", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Importing \(export.endpoints.count) endpoint\(export.endpoints.count == 1 ? "" : "s") would exceed the free limit of \(ProManager.freeEndpointLimit) endpoints. Upgrade to PRO for unlimited endpoints.")
            }
        }
    }

    private func importEndpoints() {
        guard proManager.canImportEndpoints(
            currentCount: endpointStore.endpointCount,
            importCount: export.endpoints.count
        ) else {
            showLimitAlert = true
            return
        }

        let duplicates = CollectionImporter.findDuplicates(
            imported: export.endpoints,
            existing: endpointStore.endpoints
        )

        if duplicates.isEmpty {
            endpointStore.importEndpoints(
                export.endpoints,
                collectionName: export.collectionName,
                resolution: .importAsNew
            )
            dismiss()
        } else {
            duplicateCount = duplicates.count
            showDuplicateResolution = true
        }
    }
}

private extension ExportedEndpoint {
    var uniqueID: String {
        "\(httpMethod) \(path)"
    }
}
