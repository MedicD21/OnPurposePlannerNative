import SwiftUI
import UIKit

enum PlannerTheme {
    // MARK: - Adaptive colors (auto-switch light ↔ dark)

    static let paper    = Color(l: "#fbfaf7", d: "#1a1918")
    static let ink      = Color(l: "#2d2928", d: "#e8e4df")
    static let line     = Color(l: "#9f9a94", d: "#6b6560")
    static let hairline = Color(l: "#d2cdc5", d: "#3a3530")
    static let dot      = Color(l: "#cfc8bf", d: "#363028")
    static let cover    = Color(l: "#412f33", d: "#5c4048")
    static let accent   = Color(l: "#b7828e", d: "#c4909a")
    static let tab      = Color(l: "#f3eee8", d: "#252220")

    // MARK: - Drawing palette (fixed — drawing colours don't flip with theme)

    static let defaultPalette: [Color] = [
        Color(hex: "#2f2b2a"),
        Color(hex: "#1f3a64"),
        Color(hex: "#0f6f67"),
        Color(hex: "#0f8f43"),
        Color(hex: "#a05f13"),
        Color(hex: "#8d2525"),
        Color(hex: "#7f3c9a"),
        Color(hex: "#5f5f63")
    ]

    // MARK: - Paper size

    static let spreadWidth:  CGFloat = 1600
    static let spreadHeight: CGFloat = 1200

    static let leftRatio:  CGFloat = 1.55 / (1.55 + 1.0)
    static let rightRatio: CGFloat = 1.0  / (1.55 + 1.0)

    static var leftPaperWidth:  CGFloat { spreadWidth * leftRatio  }
    static var rightPaperWidth: CGFloat { spreadWidth * rightRatio }

    // MARK: - Typography

    static let monthNumberFont  = Font.system(size: 72, weight: .bold)
    static let yearFont         = Font.system(size: 20, weight: .regular)
    static let dayNumberFont    = Font.system(size: 14, weight: .regular)
    static let weekdayFont      = Font.system(size: 11, weight: .semibold)
    static let headerLabelFont  = Font.system(size: 13, weight: .semibold)
    static let sectionLabelFont = Font.system(size: 11, weight: .medium)
}

// MARK: - Color extensions

extension Color {
    /// Adaptive light/dark colour without requiring hex: label.
    init(l lightHex: String, d darkHex: String) {
        let lightUI = UIColor(Color(hex: lightHex))
        let darkUI  = UIColor(Color(hex: darkHex))
        self.init(UIColor { tc in
            tc.userInterfaceStyle == .dark ? darkUI : lightUI
        })
    }

    /// Hex-only (fixed) colour — unchanged from before.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:(r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
