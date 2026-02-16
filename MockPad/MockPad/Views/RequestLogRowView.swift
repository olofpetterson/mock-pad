//
//  RequestLogRowView.swift
//  MockPad
//

import SwiftUI

struct RequestLogRowView: View {
    let log: RequestLog

    var body: some View {
        HStack(spacing: 8) {
            // Timestamp
            Text(log.timestamp, format: .dateTime.hour().minute().second())
                .font(MockPadTypography.logTimestamp)
                .foregroundColor(MockPadColors.textMuted)
                .frame(width: MockPadMetrics.logTimestampWidth, alignment: .leading)

            // Method badge
            Text(log.method)
                .methodBadgeStyle(color: MockPadColors.methodColor(for: log.method))
                .frame(width: MockPadMetrics.logMethodWidth)

            // Path
            Text(log.path)
                .font(MockPadTypography.logEntry)
                .foregroundColor(MockPadColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Status code
            Text("\(log.responseStatusCode)")
                .font(MockPadTypography.statusCode)
                .foregroundColor(MockPadColors.statusCodeColor(code: log.responseStatusCode))

            // Response time
            Text(String(format: "%.0fms", log.responseTimeMs))
                .font(MockPadTypography.badge)
                .foregroundColor(MockPadColors.textMuted)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: MockPadMetrics.logRowHeight)
    }
}
