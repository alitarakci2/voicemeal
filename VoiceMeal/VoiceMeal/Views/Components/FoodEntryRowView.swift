//
//  FoodEntryRowView.swift
//  VoiceMeal
//

import SwiftUI

struct FoodEntryRowView: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 10) {
            // Emoji
            Text(foodEmoji(entry.name))
                .font(.system(size: 18))
                .frame(width: 34, height: 34)
                .background(BrandColors.surface2)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                // Name + time
                HStack {
                    Text(entry.name)
                        .font(BrandTypography.bodyMedium())
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(entry.date, style: .time)
                        .font(BrandTypography.monoCaption())
                        .foregroundStyle(BrandColors.textDim)
                }

                // Amount + macros + calories
                HStack(spacing: 4) {
                    if !entry.amount.isEmpty {
                        Text(entry.amount)
                            .font(BrandTypography.monoMicro())
                            .foregroundStyle(BrandColors.textMuted)
                    }

                    macroLabel("P", value: Int(entry.protein), color: Theme.blue)
                    macroLabel("K", value: Int(entry.carbs), color: Theme.macroCarb)
                    macroLabel("Y", value: Int(entry.fat), color: Theme.fatColor)

                    Spacer(minLength: 4)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(entry.calories)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BrandColors.text)
                        Text("kcal")
                            .font(BrandTypography.monoMicro())
                            .foregroundStyle(BrandColors.textDim)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func macroLabel(_ label: String, value: Int, color: Color) -> some View {
        Text("\(label) \(value)g")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
    }

    private func foodEmoji(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("tavuk") || lower.contains("chicken") { return "\u{1F357}" }
        if lower.contains("dana") || lower.contains("k\u{0131}yma") || lower.contains("biftek") || lower.contains("kuzu") { return "\u{1F969}" }
        if lower.contains("bal\u{0131}k") || lower.contains("somon") || lower.contains("ton") { return "\u{1F41F}" }
        if lower.contains("yumurta") { return "\u{1F95A}" }
        if lower.contains("s\u{00FC}t") || lower.contains("yo\u{011F}urt") || lower.contains("kefir") { return "\u{1F95B}" }
        if lower.contains("peynir") { return "\u{1F9C0}" }
        if lower.contains("ekmek") || lower.contains("tost") { return "\u{1F35E}" }
        if lower.contains("pirin\u{00E7}") || lower.contains("bulgur") || lower.contains("makarna") || lower.contains("noodle") || lower.contains("pilav") { return "\u{1F35A}" }
        if lower.contains("salata") { return "\u{1F957}" }
        if lower.contains("sebze") || lower.contains("brokoli") || lower.contains("biber") || lower.contains("\u{0131}spanak") { return "\u{1F966}" }
        if lower.contains("ya\u{011F}") || lower.contains("zeytinya\u{011F}\u{0131}") || lower.contains("zeytin") { return "\u{1FAD2}" }
        if lower.contains("meyve") || lower.contains("elma") || lower.contains("muz") || lower.contains("portakal") { return "\u{1F34E}" }
        if lower.contains("yulaf") { return "\u{1F963}" }
        if lower.contains("kahve") || lower.contains("coffee") { return "\u{2615}" }
        if lower.contains("\u{00E7}ay") || lower.contains("tea") { return "\u{1FAD6}" }
        if lower.contains("patates") || lower.contains("k\u{0131}zartma") { return "\u{1F35F}" }
        if lower.contains("pizza") { return "\u{1F355}" }
        if lower.contains("hamburger") || lower.contains("burger") { return "\u{1F354}" }
        if lower.contains("\u{00E7}orba") || lower.contains("corba") { return "\u{1F372}" }
        if lower.contains(" et ") || lower.contains(" et,") || lower == "et" || lower.hasSuffix(" et") { return "\u{1F969}" }
        return "\u{1F37D}\u{FE0F}"
    }
}
