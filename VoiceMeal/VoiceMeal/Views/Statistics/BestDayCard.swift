//
//  BestDayCard.swift
//  VoiceMeal
//

import SwiftUI

struct BestDayCard: View {
    let stats: [DayStat]
    let gapKind: CalorieGapKind
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
        case .observe:
            return nil
        }
    }

    var bestDayTitle: String {
        switch gapKind {
        case .deficit:  return L.bestDeficitDay.localized
        case .surplus:  return L.bestSurplusDay.localized
        case .maintain: return L.bestBalanceDay.localized
        case .observe:  return ""
        }
    }

    var bestDayEmoji: String {
        switch gapKind {
        case .deficit:  return "🔥"
        case .surplus:  return "💪"
        case .maintain: return "⚖️"
        case .observe:  return ""
        }
    }

    var bestDayValueColor: Color {
        switch gapKind {
        case .deficit:  return Theme.indioOrange
        case .surplus:  return Theme.protein
        case .maintain: return Theme.green
        case .observe:  return .white
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
                    .foregroundStyle(Theme.indioOrange)
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .background(Theme.indioOrange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                Text(L.bestOfPeriod.localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
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
                    valueColor: Theme.accent
                )
            }

            // Highest protein day
            if let protDay = highestProteinDay {
                HighlightRow(
                    emoji: "💪",
                    title: L.bestProteinDay.localized,
                    value: "\(Int(protDay.protein))g",
                    subtitle: formatDate(protDay.date),
                    valueColor: Theme.protein
                )
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Theme.indioOrange.opacity(0.30), lineWidth: 0.5)
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
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.textMuted)
            }

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 4)
    }
}
