//
//  SaveTemplateSheet.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI
import SwiftData

struct SaveTemplateSheet: View {
    let endpoint: MockEndpoint

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var templateName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template name", text: $templateName)
                        .font(MockPadTypography.monoInput)
                        .autocorrectionDisabled()
                } header: {
                    Text("> TEMPLATE NAME_")
                        .blueprintLabelStyle()
                }
                .listRowBackground(MockPadColors.panel)

                Section {
                    HStack {
                        Text("Status Code")
                            .font(MockPadTypography.monoSmall)
                        Spacer()
                        Text("\(endpoint.responseStatusCode)")
                            .font(MockPadTypography.badge)
                            .foregroundStyle(MockPadColors.statusCodeColor(code: endpoint.responseStatusCode))
                    }

                    VStack(alignment: .leading, spacing: MockPadMetrics.paddingXSmall) {
                        Text("Response Body")
                            .font(MockPadTypography.monoSmall)
                        Text(previewBody)
                            .font(MockPadTypography.codeEditor)
                            .foregroundStyle(MockPadColors.textMuted)
                            .lineLimit(3)
                    }

                    HStack {
                        Text("Headers")
                            .font(MockPadTypography.monoSmall)
                        Spacer()
                        Text("\(endpoint.responseHeaders.count)")
                            .font(MockPadTypography.badge)
                            .foregroundStyle(MockPadColors.textMuted)
                    }
                } header: {
                    Text("> PREVIEW_")
                        .blueprintLabelStyle()
                }
                .listRowBackground(MockPadColors.panel)
            }
            .scrollContentBackground(.hidden)
            .background(MockPadColors.background)
            .navigationTitle("Save Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                templateName = endpoint.path
            }
        }
    }

    // MARK: - Computed

    private var previewBody: String {
        let lines = endpoint.responseBody.components(separatedBy: .newlines)
        let preview = lines.prefix(3).joined(separator: "\n")
        if lines.count > 3 {
            return preview + "\n..."
        }
        return preview
    }

    // MARK: - Actions

    private func saveTemplate() {
        let template = ResponseTemplate(
            name: templateName.trimmingCharacters(in: .whitespaces),
            statusCode: endpoint.responseStatusCode,
            responseBody: endpoint.responseBody,
            responseHeaders: endpoint.responseHeaders
        )
        modelContext.insert(template)
        try? modelContext.save()
        dismiss()
    }
}
