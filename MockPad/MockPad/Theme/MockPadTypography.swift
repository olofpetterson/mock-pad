//
//  MockPadTypography.swift
//  MockPad
//

import SwiftUI

enum MockPadTypography {
    // MARK: - Inherited from ProbePad (via shared design system)
    static let title = Font.system(.title2).weight(.semibold)
    static let sectionTitle = Font.system(.caption, design: .monospaced).weight(.semibold)
    static let body = Font.system(.body)
    static let bodySmall = Font.system(.callout)
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.callout, design: .monospaced)
    static let badge = Font.system(.caption, design: .monospaced).weight(.medium)
    static let badgeLarge = Font.system(.caption, design: .monospaced).weight(.bold)
    static let button = Font.system(.body, design: .default).weight(.semibold)
    static let buttonSmall = Font.system(.callout, design: .default).weight(.medium)
    static let input = Font.system(.body, design: .default)
    static let monoInput = Font.system(.body, design: .monospaced)

    // MARK: - MockPad-Specific

    /// Blueprint label: "> ENDPOINTS:", "> SERVER:", "> LOGS:"
    /// Usage: .textCase(.uppercase), .tracking(2), .foregroundColor(accent)
    static let blueprintLabel = Font.system(.caption, design: .monospaced).weight(.bold)

    /// HTTP method badge text: "GET", "POST", "DELETE"
    static let methodBadge = Font.system(.caption2, design: .monospaced).weight(.bold)

    /// Endpoint path display: "/api/users/:id"
    static let endpointPath = Font.system(.body, design: .monospaced).weight(.medium)

    /// Endpoint path in compact list: "/api/users/:id"
    static let endpointPathCompact = Font.system(.callout, design: .monospaced)

    /// Status code display: "200", "404", "500"
    static let statusCode = Font.system(.callout, design: .monospaced).weight(.bold)

    /// Response body in editor (JSON)
    static let codeEditor = Font.system(.callout, design: .monospaced)

    /// Code editor line numbers
    static let lineNumber = Font.system(.caption2, design: .monospaced)

    /// Server port display: ":8080"
    static let portNumber = Font.system(.title3, design: .monospaced).weight(.bold)

    /// Request log timestamp: "14:30:22.456"
    static let logTimestamp = Font.system(.caption2, design: .monospaced)

    /// Request log method + path: "GET /api/users"
    static let logEntry = Font.system(.caption, design: .monospaced).weight(.medium)

    /// Server status display: "RUNNING", "STOPPED"
    static let serverStatus = Font.system(.caption, design: .monospaced).weight(.bold)

    /// OpenAPI import summary text
    static let importSummary = Font.system(.callout)

    /// PRO overlay text: "UNLOCK WITH PRO"
    static let proLabel = Font.system(.subheadline, design: .monospaced).weight(.bold)

    /// Toast text: "SERVER STARTED", "ENDPOINT ADDED"
    static let toastLabel = Font.system(.caption, design: .monospaced).weight(.bold)
}

// MARK: - Typography View Extensions

extension View {
    /// Blueprint label style: "> LABEL_" in slate blue accent
    func blueprintLabelStyle() -> some View {
        self.font(MockPadTypography.blueprintLabel)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundColor(MockPadColors.accent)
    }

    /// Method badge style (compact, colored)
    func methodBadgeStyle(color: Color) -> some View {
        self.font(MockPadTypography.methodBadge)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundColor(MockPadColors.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(4)
    }

    /// Section title style: "> SECTION_" in slate blue
    func mockSectionTitleStyle() -> some View {
        self.font(MockPadTypography.sectionTitle)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundColor(MockPadColors.accent)
    }

    /// Endpoint path style
    func endpointPathStyle() -> some View {
        self.font(MockPadTypography.endpointPath)
            .foregroundColor(MockPadColors.textPrimary)
    }

    /// Code editor style
    func codeEditorStyle() -> some View {
        self.font(MockPadTypography.codeEditor)
            .foregroundColor(MockPadColors.textPrimary)
    }
}
