//
//  FoodEntryRowView.swift
//  VoiceMeal
//

import SwiftUI

struct FoodEntryRowView: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            // Emoji circle
            Text(foodEmoji(entry.name))
                .font(.title3)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                // Name + calories
                HStack(alignment: .top) {
                    Text(entry.name)
                        .font(Theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Text("\(entry.calories)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    + Text(" kcal")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                // Amount + Macro pills
                HStack(spacing: 6) {
                    if !entry.amount.isEmpty {
                        Text(entry.amount)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.textTertiary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    macroPill("P", value: Int(entry.protein), color: Theme.blue)
                    macroPill("K", value: Int(entry.carbs), color: Theme.orange)
                    macroPill("Y", value: Int(entry.fat), color: Color(hex: "FF6B9D"))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func macroPill(_ label: String, value: Int, color: Color) -> some View {
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
