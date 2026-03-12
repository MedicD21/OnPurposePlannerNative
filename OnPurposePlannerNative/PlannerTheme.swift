import SwiftUI

enum PlannerTheme {
    // MARK: - Colors
    static let paper    = Color(hex: "#fbfaf7")
    static let ink      = Color(hex: "#2d2928")
    static let line     = Color(hex: "#9f9a94")
    static let hairline = Color(hex: "#d2cdc5")
    static let dot      = Color(hex: "#cfc8bf")
    static let cover    = Color(hex: "#412f33")
    static let accent   = Color(hex: "#b7828e")
    static let tab      = Color(hex: "#f3eee8")

    // MARK: - Default Palette
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

    // MARK: - Paper Size
    static let spreadWidth: CGFloat  = 1600
    static let spreadHeight: CGFloat = 1200

    static let leftRatio: CGFloat  = 1.55 / (1.55 + 1.0)
    static let rightRatio: CGFloat = 1.0  / (1.55 + 1.0)

    static var leftPaperWidth: CGFloat  { spreadWidth * leftRatio }
    static var rightPaperWidth: CGFloat { spreadWidth * rightRatio }

    // MARK: - Typography helpers
    static let monthNumberFont  = Font.system(size: 72, weight: .bold)
    static let yearFont         = Font.system(size: 20, weight: .regular)
    static let dayNumberFont    = Font.system(size: 14, weight: .regular)
    static let weekdayFont      = Font.system(size: 11, weight: .semibold)
    static let headerLabelFont  = Font.system(size: 13, weight: .semibold)
    static let sectionLabelFont = Font.system(size: 11, weight: .medium)
}

// MARK: - Color hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}
