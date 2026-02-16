//
//  LogFilterChipsView.swift
//  MockPad
//

import SwiftUI

struct LogFilterChipsView: View {
    @Binding var activeMethodFilters: Set<String>
    @Binding var activeStatusFilters: Set<String>

    private let methods = ["GET", "POST", "PUT", "DELETE"]
    private let statuses: [(label: String, color: Color)] = [
        ("2xx", MockPadColors.status2xx),
        ("4xx", MockPadColors.status4xx),
        ("5xx", MockPadColors.status5xx)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Method chips
                ForEach(methods, id: \.self) { method in
                    chipButton(
                        label: method,
                        color: MockPadColors.methodColor(for: method),
                        isActive: activeMethodFilters.contains(method)
                    ) {
                        if activeMethodFilters.contains(method) {
                            activeMethodFilters.remove(method)
                        } else {
                            activeMethodFilters.insert(method)
                        }
                    }
                }

                // Divider
                Divider()
                    .frame(height: 20)
                    .overlay(MockPadColors.accent.opacity(0.3))

                // Status chips
                ForEach(statuses, id: \.label) { status in
                    chipButton(
                        label: status.label,
                        color: status.color,
                        isActive: activeStatusFilters.contains(status.label)
                    ) {
                        if activeStatusFilters.contains(status.label) {
                            activeStatusFilters.remove(status.label)
                        } else {
                            activeStatusFilters.insert(status.label)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MockPadMetrics.panelPadding)
    }

    private func chipButton(
        label: String,
        color: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(MockPadTypography.badge)
                .foregroundColor(isActive ? MockPadColors.background : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? color : MockPadColors.panel2)
                .cornerRadius(MockPadMetrics.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                        .stroke(isActive ? color : MockPadColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
