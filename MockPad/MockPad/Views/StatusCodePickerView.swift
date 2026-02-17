//
//  StatusCodePickerView.swift
//  MockPad
//

import SwiftUI

struct StatusCodePickerView: View {
    @Binding var selectedCode: Int
    @State private var customCode: String = ""
    @State private var showCustom: Bool = false

    private let quickCodes = [200, 201, 204, 400, 401, 403, 404, 500]
    private let columns = [GridItem(.adaptive(minimum: 60))]

    var body: some View {
        VStack(alignment: .leading, spacing: MockPadMetrics.paddingSmall) {
            LazyVGrid(columns: columns, spacing: MockPadMetrics.paddingSmall) {
                ForEach(quickCodes, id: \.self) { code in
                    Button {
                        selectedCode = code
                        showCustom = false
                    } label: {
                        Text("\(code)")
                            .font(.system(.callout, design: .monospaced).weight(.bold))
                            .foregroundColor(
                                selectedCode == code
                                    ? MockPadColors.statusCodeColor(code: code)
                                    : MockPadColors.textMuted
                            )
                            .frame(minWidth: 56, minHeight: MockPadMetrics.minTouchHeight)
                            .background(
                                selectedCode == code
                                    ? MockPadColors.accent.opacity(0.15)
                                    : MockPadColors.panel2
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selectedCode == code
                                            ? MockPadColors.accent
                                            : MockPadColors.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Status \(code)")
                    .accessibilityAddTraits(selectedCode == code ? .isSelected : [])
                    .accessibilityRemoveTraits(selectedCode == code ? [] : .isSelected)
                }

                // Custom code button
                Button {
                    showCustom = true
                    if !quickCodes.contains(selectedCode) {
                        customCode = "\(selectedCode)"
                    } else {
                        customCode = ""
                    }
                } label: {
                    Text("...")
                        .font(.system(.callout, design: .monospaced).weight(.bold))
                        .foregroundColor(
                            showCustom
                                ? MockPadColors.accent
                                : MockPadColors.textMuted
                        )
                        .frame(minWidth: 56, minHeight: MockPadMetrics.minTouchHeight)
                        .background(
                            showCustom
                                ? MockPadColors.accent.opacity(0.15)
                                : MockPadColors.panel2
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    showCustom
                                        ? MockPadColors.accent
                                        : MockPadColors.border,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Custom status code")
                .accessibilityAddTraits(showCustom ? .isSelected : [])
                .accessibilityRemoveTraits(showCustom ? [] : .isSelected)
            }

            if showCustom {
                TextField("Custom code", text: $customCode)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
                    .padding(MockPadMetrics.paddingSmall)
                    .background(MockPadColors.panel2)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MockPadColors.border, lineWidth: 1)
                    )
                    .onChange(of: customCode) { _, newValue in
                        if let code = Int(newValue), (100...599).contains(code) {
                            selectedCode = code
                        }
                    }
            }
        }
    }
}
