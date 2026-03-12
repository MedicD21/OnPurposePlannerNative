import SwiftUI

// MARK: - StickyColor

enum StickyColor: String, Codable, CaseIterable {
    case yellow, pink, blue, green, orange, white

    /// Pastel face color
    var face: Color {
        switch self {
        case .yellow: return Color(hex: "#fef9c3")
        case .pink:   return Color(hex: "#fce7f3")
        case .blue:   return Color(hex: "#dbeafe")
        case .green:  return Color(hex: "#dcfce7")
        case .orange: return Color(hex: "#ffedd5")
        case .white:  return Color(hex: "#f8f8f8")
        }
    }

    /// Saturated header color
    var header: Color {
        switch self {
        case .yellow: return Color(hex: "#eab308")
        case .pink:   return Color(hex: "#ec4899")
        case .blue:   return Color(hex: "#3b82f6")
        case .green:  return Color(hex: "#22c55e")
        case .orange: return Color(hex: "#f97316")
        case .white:  return Color(hex: "#9ca3af")
        }
    }
}

// MARK: - StickyNote

struct StickyNote: Identifiable, Codable {
    var id: UUID
    var pageId: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var colorKey: StickyColor
    var isCollapsed: Bool

    static let headerHeight: CGFloat = 36

    var drawingPageId: String { "sticky-\(id.uuidString)" }

    init(id: UUID = UUID(), pageId: String, x: CGFloat = 100, y: CGFloat = 100,
         width: CGFloat = 240, height: CGFloat = 280,
         colorKey: StickyColor = .yellow, isCollapsed: Bool = false) {
        self.id = id
        self.pageId = pageId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorKey = colorKey
        self.isCollapsed = isCollapsed
    }
}
