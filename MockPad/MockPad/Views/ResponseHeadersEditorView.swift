//
//  ResponseHeadersEditorView.swift
//  MockPad
//

import SwiftUI

struct ResponseHeadersEditorView: View {
    let endpoint: MockEndpoint
    let onChanged: () -> Void

    @State private var headerPairs: [(id: UUID, key: String, value: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: MockPadMetrics.rowSpacing) {
            // Section header with add button
            HStack {
                Text("> RESPONSE HEADERS_")
                    .mockSectionTitleStyle()

                Spacer()

                Button {
                    headerPairs.append((id: UUID(), key: "", value: ""))
                } label: {
                    Label("Add Header", systemImage: "plus.circle.fill")
                        .font(MockPadTypography.buttonSmall)
                        .foregroundColor(MockPadColors.accent)
                }
                .buttonStyle(.plain)
            }

            // Header rows
            ForEach(Array(headerPairs.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: MockPadMetrics.paddingSmall) {
                    TextField("Key", text: Binding(
                        get: { headerPairs[safe: index]?.key ?? "" },
                        set: { newValue in
                            guard headerPairs.indices.contains(index) else { return }
                            headerPairs[index].key = newValue
                        }
                    ))
                    .font(MockPadTypography.monoSmall)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(MockPadMetrics.paddingSmall)
                    .background(MockPadColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                            .stroke(MockPadColors.border, lineWidth: 1)
                    )
                    .cornerRadius(MockPadMetrics.cornerRadiusSmall)

                    TextField("Value", text: Binding(
                        get: { headerPairs[safe: index]?.value ?? "" },
                        set: { newValue in
                            guard headerPairs.indices.contains(index) else { return }
                            headerPairs[index].value = newValue
                        }
                    ))
                    .font(MockPadTypography.monoSmall)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(MockPadMetrics.paddingSmall)
                    .background(MockPadColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                            .stroke(MockPadColors.border, lineWidth: 1)
                    )
                    .cornerRadius(MockPadMetrics.cornerRadiusSmall)

                    Button {
                        headerPairs.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(MockPadColors.status5xx)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            loadHeaders()
        }
        .onChange(of: headerPairs.map { "\($0.key):\($0.value)" }) {
            saveHeaders()
        }
    }

    private func loadHeaders() {
        let sorted = endpoint.responseHeaders.sorted { $0.key < $1.key }
        headerPairs = sorted.map { (id: UUID(), key: $0.key, value: $0.value) }
    }

    private func saveHeaders() {
        let filtered = headerPairs.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
        var dict: [String: String] = [:]
        for pair in filtered {
            dict[pair.key] = pair.value
        }
        endpoint.responseHeaders = dict
        onChanged()
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
