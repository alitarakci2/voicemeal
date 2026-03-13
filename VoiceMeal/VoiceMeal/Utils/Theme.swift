//
//  Theme.swift
//  VoiceMeal
//

import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Colors

enum Theme {
    static let background = Color(hex: "0A0A0F")
    static let cardBackground = Color(hex: "1C1C24")
    static let cardBorder = Color(hex: "2A2A38")
    static let accent = Color(hex: "6C63FF")
    static let green = Color(hex: "34C759")
    static let orange = Color(hex: "FF9F0A")
    static let red = Color(hex: "FF453A")
    static let blue = Color(hex: "0A84FF")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8EA0")
    static let textTertiary = Color(hex: "48485A")

    // Progress bar track
    static let trackBackground = Color(hex: "2A2A38")

    // Gradients
    static let greenGradient = LinearGradient(colors: [Color(hex: "34C759"), Color(hex: "30D158")], startPoint: .leading, endPoint: .trailing)
    static let orangeGradient = LinearGradient(colors: [Color(hex: "FF9F0A"), Color(hex: "FF6B2C")], startPoint: .leading, endPoint: .trailing)
    static let accentGradient = LinearGradient(colors: [Color(hex: "6C63FF"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
    static let fireGradient = LinearGradient(colors: [Color(hex: "FF453A"), Color(hex: "FF9F0A")], startPoint: .topLeading, endPoint: .bottomTrailing)

    // Typography
    static let largeTitleFont = Font.system(size: 34, weight: .bold)
    static let titleFont = Font.system(size: 22, weight: .bold)
    static let headlineFont = Font.system(size: 17, weight: .semibold)
    static let bodyFont = Font.system(size: 15, weight: .regular)
    static let captionFont = Font.system(size: 13, weight: .regular)
    static let microFont = Font.system(size: 11, weight: .medium)
}

// MARK: - Card Modifier

struct ThemeCard: ViewModifier {
    var hasBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(hasBorder ? Theme.cardBorder : .clear, lineWidth: 1)
            )
    }
}

extension View {
    func themeCard(border: Bool = true) -> some View {
        modifier(ThemeCard(hasBorder: border))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headlineFont)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? Theme.accent.opacity(0.8) : Theme.accent)
            .cornerRadius(14)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headlineFont)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.15 : 0.1))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            )
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headlineFont)
            .foregroundStyle(Theme.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.red.opacity(configuration.isPressed ? 0.15 : 0.1))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.red.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Pill Badge

struct PillBadge: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text)
            .font(Theme.microFont)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }
}
