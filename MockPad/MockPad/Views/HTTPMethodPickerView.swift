//
//  HTTPMethodPickerView.swift
//  MockPad
//

import SwiftUI

struct HTTPMethodPickerView: View {
    @Binding var selectedMethod: String

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]
    private let columns = [GridItem(.adaptive(minimum: 60))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: MockPadMetrics.paddingSmall) {
            ForEach(methods, id: \.self) { method in
                let methodColor = MockPadColors.methodColor(for: method)
                let isSelected = selectedMethod == method

                Button {
                    selectedMethod = method
                } label: {
                    Text(method)
                        .font(MockPadTypography.methodBadge)
                        .textCase(.uppercase)
                        .foregroundColor(
                            isSelected
                                ? MockPadColors.background
                                : methodColor
                        )
                        .frame(maxWidth: .infinity, minHeight: MockPadMetrics.minTouchHeight)
                        .background(
                            isSelected
                                ? methodColor
                                : MockPadColors.panel2
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(method) method")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
            }
        }
    }
}
