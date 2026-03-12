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

// MARK: - AppSettings observable

class AppSettings: ObservableObject {
    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode") ?? "Auto"
        themeMode = ThemeMode(rawValue: saved) ?? .auto
    }
}
