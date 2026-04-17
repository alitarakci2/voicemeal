//
//  AppTheme.swift
//  VoiceMeal
//

import Combine
import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case purple = "purple"
    case blue   = "blue"

    var displayName: String {
        switch self {
        case .purple: return "Mor"
        case .blue:   return "Mavi"
        }
    }

    var displayNameEn: String {
        switch self {
        case .purple: return "Purple"
        case .blue:   return "Blue"
        }
    }

    var gradientTop: Color {
        switch self {
        case .purple: return Color(hex: "2D0A4E")
        case .blue:   return Color(hex: "0A1A2D")
        }
    }

    var gradientMid: Color {
        switch self {
        case .purple: return Color(hex: "150828")
        case .blue:   return Color(hex: "060D18")
        }
    }

    var cardBackground: Color {
        switch self {
        case .purple: return Color(hex: "1A0A2E")
        case .blue:   return Color(hex: "0A1020")
        }
    }

    var cardBorder: Color {
        switch self {
        case .purple: return Color(hex: "2A1A3E")
        case .blue:   return Color(hex: "1A2030")
        }
    }

    var accent: Color {
        switch self {
        case .purple: return Color(hex: "6C63FF")
        case .blue:   return Color(hex: "3498DB")
        }
    }

    var accentLight: Color {
        switch self {
        case .purple: return Color(hex: "9D95FF")
        case .blue:   return Color(hex: "5DADE2")
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMid, Color(hex: "0A0A0F")],
            startPoint: .top, endPoint: .bottom
        )
    }

    var insightBorder: Color {
        accent.opacity(0.3)
    }
}

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .purple

    static let shared = ThemeManager()

    init() {
        load()
    }

    func apply(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }

    func load() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? "purple"
        current = AppTheme(rawValue: saved) ?? .purple
    }
}
