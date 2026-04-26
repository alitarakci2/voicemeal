import SwiftUI

// MARK: - Theme Colors

enum Theme {
    // Surface
    static var background: Color       { BrandColors.black }
    static var cardBackground: Color   { BrandColors.surface }
    static var cardBorder: Color       { BrandColors.border }

    // Accents — INDIO ORANGE IS NOW PRIMARY
    static var accent: Color           { BrandColors.indioOrange }
    static var accentLight: Color      { BrandColors.indioOrangeSoft }
    static var accentDim: Color        { BrandColors.indioOrangeDim }

    // Indio orange (kept under explicit name for brand-attribution moments — same value as accent)
    static var indioOrange: Color      { BrandColors.indioOrange }
    static var indioOrangeSoft: Color  { BrandColors.indioOrangeSoft }

    // Emerald — DEMOTED to success semantics only
    static var success: Color          { BrandColors.vmEmerald }
    static var successSoft: Color      { BrandColors.vmEmeraldSoft }

    // Atmospheric background — black + warm orange undertone + purple touches
    static var gradientTop: Color      { Color(hex: "#1A0A05") }
    static var gradientMid: Color      { Color(hex: "#0F0612") }
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMid, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Atmospheric purple — Indio brand family, used in gradient halos
    static var atmospherePurple: Color { Color(hex: "#3D2552") }

    // Text
    static var textPrimary: Color      { BrandColors.text }
    static var textSecondary: Color    { BrandColors.textMuted }
    static var textTertiary: Color     { BrandColors.textDim }

    // Semantic — macro colors preserved
    static var macroCarb: Color        { BrandColors.macroCarb }
    static var warning: Color          { BrandColors.warning }
    static var danger: Color           { BrandColors.danger }
    static var protein: Color          { BrandColors.macroProtein }
    static var fat: Color              { BrandColors.macroFat }
    static var trackBackground: Color  { BrandColors.trackBg }

    // Aliases — green now maps to vmEmerald (success semantics)
    static var green: Color            { BrandColors.vmEmerald }
    static var blue: Color             { BrandColors.macroProtein }
    static var red: Color              { BrandColors.danger }
    static var fatColor: Color         { BrandColors.macroFat }
    static var trackBg: Color          { BrandColors.trackBg }

    // Gradients
    static let greenGradient = LinearGradient(colors: [Color(hex: "#1D9E75"), Color(hex: "#2EBC8E")], startPoint: .leading, endPoint: .trailing)
    static let orangeGradient = LinearGradient(colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF6B2C")], startPoint: .leading, endPoint: .trailing)
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [BrandColors.indioOrange, BrandColors.indioOrangeSoft], startPoint: .leading, endPoint: .trailing)
    }
    static let fireGradient = LinearGradient(colors: [Color(hex: "#FF453A"), Color(hex: "#FF9F0A")], startPoint: .topLeading, endPoint: .bottomTrailing)

    // Typography — keep existing API for backwards compat
    static let largeTitleFont = Font.system(size: 34, weight: .bold)
    static let titleFont      = Font.system(size: 22, weight: .bold)
    static let headlineFont   = Font.system(size: 17, weight: .semibold)
    static let bodyFont       = Font.system(size: 15, weight: .regular)
    static let captionFont    = Font.system(size: 13, weight: .regular)
    static let microFont      = Font.system(size: 11, weight: .medium)
}

// MARK: - Card Modifier

struct ThemeCard: ViewModifier {
    var hasBorder: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
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

// MARK: - Macro Total Pill

struct MacroTotalPill: View {
    let label: String
    let value: Int
    let color: Color

    init(_ label: String, value: Int, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(value)g")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
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
