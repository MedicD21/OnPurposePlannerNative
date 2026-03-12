import SwiftUI

// MARK: - TabColor

enum TabColor: String, Codable, CaseIterable {
    case mint, sky, pink, lavender, peach, lemon

    var fill: Color {
        switch self {
        case .mint:     return Color(hex: "#b5e8d8")
        case .sky:      return Color(hex: "#b8dff5")
        case .pink:     return Color(hex: "#f9c6d0")
        case .lavender: return Color(hex: "#d4c8f0")
        case .peach:    return Color(hex: "#fdd5b1")
        case .lemon:    return Color(hex: "#f5f0a8")
        }
    }

    var border: Color {
        switch self {
        case .mint:     return Color(hex: "#88d4be")
        case .sky:      return Color(hex: "#88c4e8")
        case .pink:     return Color(hex: "#f0a0b8")
        case .lavender: return Color(hex: "#b8a8e0")
        case .peach:    return Color(hex: "#f0b888")
        case .lemon:    return Color(hex: "#d8d458")
        }
    }
}

// MARK: - TabMarker

struct TabMarker: Identifiable, Codable {
    var id: UUID
    var pageId: String
    var x: CGFloat
    var y: CGFloat
    var colorKey: TabColor

    static let width:  CGFloat = 200
    static let height: CGFloat = 54

    var drawingPageId: String { "tab-\(id.uuidString)" }

    init(id: UUID = UUID(), pageId: String,
         x: CGFloat = 200, y: CGFloat = 200,
         colorKey: TabColor = .mint) {
        self.id       = id
        self.pageId   = pageId
        self.x        = x
        self.y        = y
        self.colorKey = colorKey
    }
}
