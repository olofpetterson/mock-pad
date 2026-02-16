//
//  MockPadMetrics.swift
//  MockPad
//

import Foundation

enum MockPadMetrics {
    // MARK: - Shared Metrics
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusLarge: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let panelContentPadding: CGFloat = 14
    static let paddingSmall: CGFloat = 8
    static let paddingXSmall: CGFloat = 4
    static let paddingLarge: CGFloat = 20
    static let panelSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 10
    static let formSpacing: CGFloat = 12
    static let spacingSmall: CGFloat = 6
    static let borderWidth: CGFloat = 1
    static let borderWidthThick: CGFloat = 2
    static let minTouchHeight: CGFloat = 44
    static let buttonHeight: CGFloat = 44

    // MARK: - Endpoint Card
    static let endpointCardHeight: CGFloat = 72
    static let endpointCardExpandedMin: CGFloat = 200
    static let methodBadgeWidth: CGFloat = 56
    static let methodBadgeHeight: CGFloat = 22
    static let statusCodeBadgeWidth: CGFloat = 40

    // MARK: - Server Status Bar
    static let serverStatusBarHeight: CGFloat = 52
    static let serverDotSize: CGFloat = 10
    static let portDisplaySize: CGFloat = 28

    // MARK: - Response Editor
    static let editorMinHeight: CGFloat = 200
    static let editorMaxHeight: CGFloat = 500
    static let lineNumberWidth: CGFloat = 40
    static let editorPadding: CGFloat = 12

    // MARK: - Request Log
    static let logRowHeight: CGFloat = 44
    static let logTimestampWidth: CGFloat = 80
    static let logMethodWidth: CGFloat = 56
    static let logMaxVisible: Int = 50

    // MARK: - OpenAPI Import
    static let importPreviewHeight: CGFloat = 300
    static let importEndpointRowHeight: CGFloat = 48

    // MARK: - Split View (iPad)
    static let sidebarWidth: CGFloat = 320
    static let detailMinWidth: CGFloat = 400

    // MARK: - PRO Overlay
    static let proOverlayBlur: CGFloat = 3
    static let lockIconSize: CGFloat = 32

    // MARK: - Toast
    static let toastHeight: CGFloat = 36
    static let toastCornerRadius: CGFloat = 18
    static let toastBottomOffset: CGFloat = 80
}
