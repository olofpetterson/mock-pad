//
//  MockPadColors.swift
//  MockPad
//

import SwiftUI

/// MockPad color tokens -- "Slate Blueprint" theme
/// Tron: Legacy (2010) construction/materialization sequences
enum MockPadColors {
    // MARK: - Backgrounds (slate-tinted)
    static let surface = Color(red: 0.02, green: 0.02, blue: 0.04)       // #06060A
    static let background = Color(red: 0.03, green: 0.03, blue: 0.05)    // #08080E
    static let panel = Color(red: 0.08, green: 0.07, blue: 0.12)         // #14121E
    static let panel2 = Color(red: 0.12, green: 0.10, blue: 0.16)        // #1E1A2A
    static let elevated = Color(red: 0.16, green: 0.14, blue: 0.21)      // #282436

    // MARK: - Accent (slate blue)
    static let accent = Color(red: 0.48, green: 0.41, blue: 0.93)        // #7B68EE
    static let accentSecondary = Color(red: 0.38, green: 0.31, blue: 0.80) // #6050CC
    static let accentMuted = accent.opacity(0.19)
    static let border = accent.opacity(0.25)
    static let borderActive = accent.opacity(0.50)
    static let borderFocused = accent.opacity(0.70)
    static let glow = accent.opacity(0.15)

    // MARK: - Text
    static let textPrimary = Color.white.opacity(0.92)
    static let textAccent = accent.opacity(0.85)
    static let textMuted = Color.white.opacity(0.65)
    static let textDisabled = Color.white.opacity(0.35)

    // MARK: - HTTP Methods
    static let methodGet = Color(red: 0.0, green: 1.0, blue: 0.4)        // #00FF66
    static let methodPost = Color(red: 1.0, green: 0.69, blue: 0.0)      // #FFB000
    static let methodPut = Color(red: 0.0, green: 0.75, blue: 1.0)       // #00BFFF
    static let methodPatch = accent                                        // #7B68EE
    static let methodDelete = Color(red: 1.0, green: 0.42, blue: 0.42)   // #FF6B6B
    static let methodOther = Color.white.opacity(0.40)

    // MARK: - Server Status
    static let serverRunning = Color(red: 0.0, green: 1.0, blue: 0.4)    // #00FF66
    static let serverStopped = Color(red: 1.0, green: 0.42, blue: 0.42)  // #FF6B6B
    static let serverStarting = Color(red: 1.0, green: 0.69, blue: 0.0)  // #FFB000

    // MARK: - Response Status Codes
    static let status2xx = Color(red: 0.0, green: 1.0, blue: 0.4)        // #00FF66
    static let status3xx = Color(red: 0.0, green: 0.75, blue: 1.0)       // #00BFFF
    static let status4xx = Color(red: 1.0, green: 0.69, blue: 0.0)       // #FFB000
    static let status5xx = Color(red: 1.0, green: 0.42, blue: 0.42)      // #FF6B6B

    // MARK: - PRO
    static let proGradientStart = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let proGradientEnd = panel
    static let proBorder = accent.opacity(0.30)
    static let proBadge = accent.opacity(0.10)
    static let lockOverlay = surface.opacity(0.80)

    // MARK: - Method Color Lookup
    static func methodColor(for method: String) -> Color {
        switch method.uppercased() {
        case "GET":     return methodGet
        case "POST":    return methodPost
        case "PUT":     return methodPut
        case "PATCH":   return methodPatch
        case "DELETE":  return methodDelete
        default:        return methodOther
        }
    }

    // MARK: - Status Code Color Lookup
    static func statusCodeColor(code: Int) -> Color {
        switch code {
        case 200..<300: return status2xx
        case 300..<400: return status3xx
        case 400..<500: return status4xx
        case 500..<600: return status5xx
        default:        return textMuted
        }
    }
}
