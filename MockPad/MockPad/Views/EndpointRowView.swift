//
//  EndpointRowView.swift
//  MockPad
//

import SwiftUI

struct EndpointRowView: View {
    let endpoint: MockEndpoint
    let onToggle: (Bool) -> Void

    private var methodColor: Color {
        MockPadColors.methodColor(for: endpoint.httpMethod)
    }

    private var statusColor: Color {
        MockPadColors.statusCodeColor(code: endpoint.responseStatusCode)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Method badge
            Text(endpoint.httpMethod)
                .methodBadgeStyle(color: methodColor)
                .frame(width: MockPadMetrics.methodBadgeWidth)
                .accessibilityHidden(true)

            // Path
            Text(endpoint.path)
                .endpointPathStyle()
                .lineLimit(1)
                .accessibilityHidden(true)

            Spacer()

            // Status code
            Text("\(endpoint.responseStatusCode)")
                .font(MockPadTypography.statusCode)
                .foregroundColor(statusColor)
                .accessibilityHidden(true)

            // Enable/disable toggle
            Toggle(isOn: Binding(
                get: { endpoint.isEnabled },
                set: { onToggle($0) }
            )) {
                EmptyView()
            }
            .labelsHidden()
            .tint(MockPadColors.accent)
            .accessibilityLabel("\(endpoint.httpMethod) endpoint enabled")
            .accessibilityValue(endpoint.isEnabled ? "On" : "Off")
        }
        .padding(.horizontal, MockPadMetrics.panelPadding)
        .frame(minHeight: MockPadMetrics.endpointCardHeight)
        .background(MockPadColors.panel)
        .cornerRadius(MockPadMetrics.cornerRadius)
        .opacity(endpoint.isEnabled ? 1.0 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(endpoint.httpMethod) \(endpoint.path), status \(endpoint.responseStatusCode)")
    }
}
