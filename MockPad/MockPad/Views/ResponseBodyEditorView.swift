//
//  ResponseBodyEditorView.swift
//  MockPad
//

import SwiftUI

struct ResponseBodyEditorView: View {
    @Binding var text: String
    let onChanged: () -> Void

    private enum JSONValidationResult {
        case valid
        case invalid(String)
        case empty
    }

    private var validationResult: JSONValidationResult {
        validateJSON(text)
    }

    private var isFormatEnabled: Bool {
        if case .valid = validationResult { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MockPadMetrics.paddingSmall) {
            // Toolbar: section label, format button, validation badge
            HStack {
                Text("> RESPONSE BODY_")
                    .mockSectionTitleStyle()

                Spacer()

                Button {
                    if let formatted = prettyPrintJSON(text) {
                        text = formatted
                        onChanged()
                    }
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                        .font(MockPadTypography.buttonSmall)
                        .foregroundColor(MockPadColors.accent)
                }
                .disabled(!isFormatEnabled)
                .opacity(isFormatEnabled ? 1.0 : 0.4)
                .buttonStyle(.plain)

                validationBadge
            }

            // Text editor
            TextEditor(text: $text)
                .font(MockPadTypography.codeEditor)
                .foregroundColor(MockPadColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(MockPadMetrics.editorPadding)
                .frame(minHeight: MockPadMetrics.editorMinHeight, maxHeight: .infinity)
                .background(MockPadColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                        .stroke(MockPadColors.border, lineWidth: 1)
                )
                .cornerRadius(MockPadMetrics.cornerRadiusSmall)
                .onChange(of: text) {
                    onChanged()
                }
        }
    }

    @ViewBuilder
    private var validationBadge: some View {
        switch validationResult {
        case .valid:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Valid JSON")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(MockPadColors.status2xx)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("JSON validation: valid")

        case .invalid:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                Text("Invalid JSON")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(MockPadColors.status5xx)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("JSON validation: invalid")

        case .empty:
            EmptyView()
        }
    }

    // MARK: - JSON Validation

    private func validateJSON(_ text: String) -> JSONValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }

        guard let data = text.data(using: .utf8) else {
            return .invalid("Invalid UTF-8 encoding")
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return .valid
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    // MARK: - Pretty Print

    private func prettyPrintJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let result = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return result
    }
}
