//
//  AppTheme.swift
//  VoiceMeal
//

import Combine
import SwiftUI

enum AppTheme: String, CaseIterable, Codable {
    case purple = "purple"
    case green  = "green"
    case blue   = "blue"
    case red    = "red"

    var displayName: String {
        switch self {
        case .purple: return "Mor"
        case .green:  return "Yeşil"
        case .blue:   return "Mavi"
        case .red:    return "Kırmızı"
        }
    }

    var displayNameEn: String {
        switch self {
        case .purple: return "Purple"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .red:    return "Red"
        }
    }

    var gradientTop: Color {
        switch self {
        case .purple: return Color(hex: "2D0A4E")
        case .green:  return Color(hex: "0A2D1A")
        case .blue:   return Color(hex: "0A1A2D")
        case .red:    return Color(hex: "2D0A0A")
        }
    }

    var gradientMid: Color {
        switch self {
        case .purple: return Color(hex: "150828")
        case .green:  return Color(hex: "06180D")
        case .blue:   return Color(hex: "060D18")
        case .red:    return Color(hex: "180606")
        }
    }

    var cardBackground: Color {
        switch self {
        case .purple: return Color(hex: "1A0A2E")
        case .green:  return Color(hex: "0A1F0F")
        case .blue:   return Color(hex: "0A1020")
        case .red:    return Color(hex: "1F0A0A")
        }
    }

    var cardBorder: Color {
        switch self {
        case .purple: return Color(hex: "2A1A3E")
        case .green:  return Color(hex: "1A2F1F")
        case .blue:   return Color(hex: "1A2030")
        case .red:    return Color(hex: "2F1A1A")
        }
    }

    var accent: Color {
        switch self {
        case .purple: return Color(hex: "6C63FF")
        case .green:  return Color(hex: "2ECC71")
        case .blue:   return Color(hex: "3498DB")
        case .red:    return Color(hex: "E74C3C")
        }
    }

    var accentLight: Color {
        switch self {
        case .purple: return Color(hex: "9D95FF")
        case .green:  return Color(hex: "58D68D")
        case .blue:   return Color(hex: "5DADE2")
        case .red:    return Color(hex: "EC7063")
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
