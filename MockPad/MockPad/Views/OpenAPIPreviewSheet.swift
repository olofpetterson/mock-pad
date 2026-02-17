//
//  OpenAPIPreviewSheet.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI

struct OpenAPIPreviewSheet: View {
    let parseResult: OpenAPIParser.ParseResult

    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager
    @Environment(\.dismiss) private var dismiss

    @State private var selections: [Bool]
    @State private var showDuplicateResolution = false
    @State private var duplicateCount = 0
    @State private var showLimitAlert = false

    init(parseResult: OpenAPIParser.ParseResult) {
        self.parseResult = parseResult
        self._selections = State(initialValue: parseResult.endpoints.map(\.isSelected))
    }

    private var selectedCount: Int {
        selections.filter { $0 }.count
    }

    private var selectedEndpoints: [OpenAPIParser.DiscoveredEndpoint] {
        zip(selections, parseResult.endpoints)
            .filter { $0.0 }
            .map { $0.1 }
    }

    private var allSelected: Bool {
        selections.allSatisfy { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Header Section
                Section {
                    LabeledContent("Specification", value: parseResult.title)
                    LabeledContent("Version", value: parseResult.version)
                    LabeledContent("Endpoints", value: "\(selectedCount) of \(parseResult.endpoints.count) selected")
                }
                .listRowBackground(MockPadColors.panel)

                // MARK: - Global Warnings Section
                if !parseResult.globalWarnings.isEmpty {
                    Section("Warnings") {
                        ForEach(Array(parseResult.globalWarnings.enumerated()), id: \.offset) { _, warning in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(warning)
                                    .font(MockPadTypography.body)
                            }
                        }
                    }
                    .listRowBackground(MockPadColors.panel)
                }

                // MARK: - Endpoints Section
                Section("Endpoints") {
                    ForEach(Array(parseResult.endpoints.enumerated()), id: \.offset) { index, endpoint in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                Button {
                                    selections[index].toggle()
                                } label: {
                                    Image(systemName: selections[index] ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selections[index] ? MockPadColors.accent : MockPadColors.textMuted)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(selections[index] ? "Deselect \(endpoint.httpMethod) \(endpoint.path)" : "Select \(endpoint.httpMethod) \(endpoint.path)")

                                Text(endpoint.httpMethod)
                                    .methodBadgeStyle(color: MockPadColors.methodColor(for: endpoint.httpMethod))
                                    .frame(width: MockPadMetrics.methodBadgeWidth)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(endpoint.path)
                                        .font(MockPadTypography.endpointPathCompact)
                                        .foregroundColor(MockPadColors.textPrimary)
                                        .lineLimit(1)

                                    if let summary = endpoint.summary {
                                        Text(summary)
                                            .font(MockPadTypography.bodySmall)
                                            .foregroundColor(MockPadColors.textMuted)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text("\(endpoint.responseStatusCode)")
                                    .font(MockPadTypography.statusCode)
                                    .foregroundColor(MockPadColors.statusCodeColor(code: endpoint.responseStatusCode))
                            }

                            if !endpoint.warnings.isEmpty {
                                ForEach(Array(endpoint.warnings.enumerated()), id: \.offset) { _, warning in
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text(warning)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.leading, 36)
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                }
                .listRowBackground(MockPadColors.panel)

                // MARK: - Actions Section
                Section {
                    Button {
                        if allSelected {
                            selections = Array(repeating: false, count: selections.count)
                        } else {
                            selections = Array(repeating: true, count: selections.count)
                        }
                    } label: {
                        Label(
                            allSelected ? "Deselect All" : "Select All",
                            systemImage: allSelected ? "square" : "checkmark.square.fill"
                        )
                    }

                    Button {
                        importSelectedEndpoints()
                    } label: {
                        Text("Import \(selectedCount) Endpoint\(selectedCount == 1 ? "" : "s")")
                            .frame(maxWidth: .infinity)
                            .font(MockPadTypography.button)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MockPadColors.accent)
                    .disabled(selectedCount == 0)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MockPadColors.background)
            .navigationTitle("OpenAPI Import")
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
                    let exported = convertToExported(selectedEndpoints)
                    endpointStore.importEndpoints(exported, collectionName: parseResult.title, resolution: .skip)
                    dismiss()
                }
                Button("Replace Existing") {
                    let exported = convertToExported(selectedEndpoints)
                    endpointStore.importEndpoints(exported, collectionName: parseResult.title, resolution: .replace)
                    dismiss()
                }
                Button("Import as New") {
                    let exported = convertToExported(selectedEndpoints)
                    endpointStore.importEndpoints(exported, collectionName: parseResult.title, resolution: .importAsNew)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(duplicateCount) of \(selectedEndpoints.count) endpoint\(selectedEndpoints.count == 1 ? "" : "s") already exist.")
            }
            .alert("Endpoint Limit", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Importing \(selectedCount) endpoint\(selectedCount == 1 ? "" : "s") would exceed the free limit of \(ProManager.freeEndpointLimit) endpoints. Upgrade to PRO for unlimited endpoints.")
            }
        }
    }

    // MARK: - Import Logic

    private func importSelectedEndpoints() {
        let selected = selectedEndpoints

        guard proManager.canImportEndpoints(
            currentCount: endpointStore.endpointCount,
            importCount: selected.count
        ) else {
            showLimitAlert = true
            return
        }

        let exported = convertToExported(selected)

        let duplicates = CollectionImporter.findDuplicates(
            imported: exported,
            existing: endpointStore.endpoints
        )

        if duplicates.isEmpty {
            endpointStore.importEndpoints(exported, collectionName: parseResult.title, resolution: .importAsNew)
            dismiss()
        } else {
            duplicateCount = duplicates.count
            showDuplicateResolution = true
        }
    }

    private func convertToExported(_ endpoints: [OpenAPIParser.DiscoveredEndpoint]) -> [ExportedEndpoint] {
        endpoints.map { endpoint in
            ExportedEndpoint(
                path: endpoint.path,
                httpMethod: endpoint.httpMethod,
                responseStatusCode: endpoint.responseStatusCode,
                responseBody: endpoint.responseBody,
                responseHeaders: endpoint.responseHeaders,
                isEnabled: true,
                responseDelayMs: 0
            )
        }
    }
}
