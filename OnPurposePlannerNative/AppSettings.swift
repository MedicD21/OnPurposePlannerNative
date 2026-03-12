import SwiftUI

// MARK: - Theme mode

enum ThemeMode: String, CaseIterable, Codable {
    case auto  = "Auto"
    case light = "Light"
    case dark  = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }

    var icon: String {
        switch self {
        case .auto:  return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark:  return "moon"
        }
    }
}

// MARK: - Planner style (extensible for future styles)

enum PlannerStyle: String, CaseIterable, Codable {
    case classic = "Classic"

    var description: String {
        switch self {
        case .classic: return "Timeless month & week layout"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "calendar"
        }
    }
}

// MARK: - AppSettings observable

class AppSettings: ObservableObject {
    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }

    @Published var plannerStyle: PlannerStyle {
        didSet { UserDefaults.standard.set(plannerStyle.rawValue, forKey: "plannerStyle") }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "themeMode") ?? "Auto"
        themeMode = ThemeMode(rawValue: savedTheme) ?? .auto

        let savedStyle = UserDefaults.standard.string(forKey: "plannerStyle") ?? "Classic"
        plannerStyle = PlannerStyle(rawValue: savedStyle) ?? .classic
    }
}
