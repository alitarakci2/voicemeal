//
//  BestDayCard.swift
//  VoiceMeal
//

import SwiftUI

struct BestDayCard: View {
    let stats: [DayStat]
    let gapKind: CalorieGapKind
    @EnvironmentObject var themeManager: ThemeManager
    var appLanguage: String

    var bestDay: DayStat? {
        let data = stats.filter { $0.hasData }
        switch gapKind {
        case .deficit:
            return data.filter { $0.deficit > 0 }.max { $0.deficit < $1.deficit }
        case .surplus:
            return data.filter { $0.deficit < 0 }.min { $0.deficit < $1.deficit }
        case .maintain:
            return data.min { abs($0.deficit) < abs($1.deficit) }
        }
    }

    var bestDayTitle: String {
        switch gapKind {
        case .deficit:  return L.bestDeficitDay.localized
        case .surplus:  return L.bestSurplusDay.localized
        case .maintain: return L.bestBalanceDay.localized
        }
    }

    var bestDayEmoji: String {
        switch gapKind {
        case .deficit:  return "🔥"
        case .surplus:  return "💪"
        case .maintain: return "⚖️"
        }
    }

    var bestDayValueColor: Color {
        switch gapKind {
        case .deficit:  return .orange
        case .surplus:  return Color(hex: "5E9FFF")
        case .maintain: return .green
        }
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
                Text(L.bestOfPeriod.localized)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }

            Divider().opacity(0.2)

            // Best day (mode-aware)
            if let best = bestDay {
                HighlightRow(
                    emoji: bestDayEmoji,
                    title: bestDayTitle,
                    value: "\(abs(Int(best.deficit))) kcal",
                    subtitle: formatDate(best.date),
                    valueColor: bestDayValueColor
                )
            }

            // Longest streak in period
            if mostConsistentStreak > 1 {
                HighlightRow(
                    emoji: "⚡",
                    title: L.longestStreak.localized,
                    value: "\(mostConsistentStreak) " + L.daysShort.localized,
                    subtitle: L.consecutiveDaysLogged.localized,
                    valueColor: themeManager.current.accent
                )
            }

            // Highest protein day
            if let protDay = highestProteinDay {
                HighlightRow(
                    emoji: "💪",
                    title: L.bestProteinDay.localized,
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
