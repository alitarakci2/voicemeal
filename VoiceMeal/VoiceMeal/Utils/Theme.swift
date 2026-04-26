import SwiftUI

// MARK: - Theme Colors

enum Theme {
    // Surface
    static var background: Color       { BrandColors.black }
    static var cardBackground: Color   { BrandColors.surface }
    static var cardBorder: Color       { BrandColors.border }

    // Accents — locked to VoiceMeal emerald
    static var accent: Color           { BrandColors.vmEmerald }
    static var accentLight: Color      { BrandColors.vmEmeraldSoft }
    static var accentDim: Color        { BrandColors.vmEmeraldDim }

    // Indio brand orange (flame / streak / AI insight / attribution)
    static var indioOrange: Color      { BrandColors.indioOrange }
    static var indioOrangeSoft: Color  { BrandColors.indioOrangeSoft }

    // Background gradient — green-tinted dark for VoiceMeal
    static var gradientTop: Color      { Color(hex: "#0A2218") }
    static var gradientMid: Color      { Color(hex: "#061410") }
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMid, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Text
    static var textPrimary: Color      { BrandColors.text }
    static var textSecondary: Color    { BrandColors.textMuted }
    static var textTertiary: Color     { BrandColors.textDim }

    // Semantic split from old Theme.orange
    static var macroCarb: Color        { BrandColors.macroCarb }   // #FF9F0A — carb macro charts/bars/pills
    static var warning: Color          { BrandColors.warning }     // #FFA533 — calorie warnings, alerts

    // Other semantic — preserved
    static var success: Color          { BrandColors.success }     // #34C759 — on-target, saved
    static var danger: Color           { BrandColors.danger }      // #FF453A — recording, errors, over-limit
    static var protein: Color          { BrandColors.macroProtein }// #0A84FF
    static var fat: Color              { BrandColors.macroFat }    // #FF6B9D
    static var trackBackground: Color  { BrandColors.trackBg }     // #2A2A38

    // Aliases for backwards compatibility with existing call sites
    static var green: Color            { BrandColors.success }
    static var blue: Color             { BrandColors.macroProtein }
    static var red: Color              { BrandColors.danger }
    static var fatColor: Color         { BrandColors.macroFat }
    static var trackBg: Color          { BrandColors.trackBg }

    // Gradients
    static let greenGradient = LinearGradient(colors: [Color(hex: "#34C759"), Color(hex: "#30D158")], startPoint: .leading, endPoint: .trailing)
    static let orangeGradient = LinearGradient(colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF6B2C")], startPoint: .leading, endPoint: .trailing)
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [BrandColors.vmEmerald, BrandColors.vmEmeraldSoft], startPoint: .leading, endPoint: .trailing)
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
