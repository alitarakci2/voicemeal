//
//  BestDayCard.swift
//  VoiceMeal
//

import SwiftUI

struct BestDayCard: View {
    let stats: [DayStat]
    @EnvironmentObject var themeManager: ThemeManager
    var appLanguage: String

    var bestDay: DayStat? {
        stats.filter { $0.hasData && $0.deficit > 0 }
            .max { $0.deficit < $1.deficit }
    }

    var mostConsistentStreak: Int {
        var maxStreak = 0
        var currentStreak = 0
        for stat in stats.sorted(by: { $0.date < $1.date }) {
            if stat.hasData {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        return maxStreak
    }

    var highestProteinDay: DayStat? {
        stats.filter { $0.hasData }
            .max { $0.protein < $1.protein }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(8)
                Text(appLanguage == "en"
                     ? "Best of the Period" : "En İyi Günler")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }

            Divider().opacity(0.2)

            // Best deficit day
            if let best = bestDay {
                HighlightRow(
                    emoji: "🔥",
                    title: appLanguage == "en"
                        ? "Best Deficit Day" : "En Yüksek Açık",
                    value: "\(Int(best.deficit)) kcal",
                    subtitle: formatDate(best.date),
                    valueColor: .orange
                )
            }

            // Longest streak in period
            if mostConsistentStreak > 1 {
                HighlightRow(
                    emoji: "⚡",
                    title: appLanguage == "en"
                        ? "Longest Streak" : "En Uzun Seri",
                    value: "\(mostConsistentStreak) " +
                        (appLanguage == "en" ? "days" : "gün"),
                    subtitle: appLanguage == "en"
                        ? "consecutive days logged"
                        : "ardışık gün kayıt",
                    valueColor: themeManager.current.accent
                )
            }

            // Highest protein day
            if let protDay = highestProteinDay {
                HighlightRow(
                    emoji: "💪",
                    title: appLanguage == "en"
                        ? "Best Protein Day" : "En İyi Protein Günü",
                    value: "\(Int(protDay.protein))g",
                    subtitle: formatDate(protDay.date),
                    valueColor: Color(hex: "5E9FFF")
                )
            }
        }
        .padding(14)
        .background(themeManager.current.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier:
                                    appLanguage == "en" ? "en_US" : "tr_TR")
        return formatter.string(from: date)
    }
}

struct HighlightRow: View {
    let emoji: String
    let title: String
    let value: String
    let subtitle: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}
