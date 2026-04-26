//
//  ConsistencyCard.swift
//  VoiceMeal
//

import SwiftUI

struct ConsistencyCard: View {
    let stats: [DayStat]           // current period days
    let previousStats: [DayStat]   // previous period for comparison
    var appLanguage: String

    var daysWithData: Int {
        stats.filter { $0.hasData }.count
    }
    var totalDays: Int { stats.count }
    var consistencyPct: Int {
        totalDays > 0 ? Int(Double(daysWithData) / Double(totalDays) * 100) : 0
    }
    var previousPct: Int {
        let prev = previousStats.filter { $0.hasData }.count
        return previousStats.count > 0
            ? Int(Double(prev) / Double(previousStats.count) * 100) : 0
    }
    var trend: Int { consistencyPct - previousPct }
    var consistencyColor: Color {
        consistencyPct >= 80 ? Theme.green
            : consistencyPct >= 50 ? Theme.warning
            : Theme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(consistencyColor)
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .background(consistencyColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                Text(appLanguage == "en"
                     ? "Consistency" : "Tutarlılık")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                // Trend vs last period
                if trend != 0 {
                    HStack(spacing: 3) {
                        Image(systemName: trend > 0
                              ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text("\(abs(trend))%")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(trend > 0 ? Theme.green : Theme.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (trend > 0 ? Theme.green : Theme.danger)
                            .opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                }
            }

            // Main score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(consistencyPct)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(consistencyColor)
                    .contentTransition(.numericText())
                Text("%")
                    .font(.title2)
                    .foregroundStyle(consistencyColor.opacity(0.7))
                Spacer()
                Text("\(daysWithData)/\(totalDays) " +
                     L.daysLogged.localized)
                    .font(.caption)
                    .foregroundStyle(BrandColors.textMuted)
            }

            // Day dots visualization
            HStack(spacing: 4) {
                ForEach(stats.indices, id: \.self) { i in
                    let stat = stats[i]
                    Circle()
                        .fill(stat.hasData
                              ? consistencyColor
                              : BrandColors.surface2)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(
                                    stat.hasData
                                        ? consistencyColor
                                        : BrandColors.border,
                                    lineWidth: 1)
                        )
                }
                Spacer()
            }

            // Message
            Text(consistencyMessage)
                .font(.caption)
                .foregroundStyle(BrandColors.textMuted)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(BrandColors.border, lineWidth: 0.5)
        )
    }

    var consistencyMessage: String {
        if appLanguage == "en" {
            switch consistencyPct {
            case 90...100: return "🔥 Outstanding! Keep it up!"
            case 70..<90:  return "💪 Great work, almost perfect!"
            case 50..<70:  return "📈 Good progress, aim for more days"
            default:       return "🎯 Try to log every day for best results"
            }
        } else {
            switch consistencyPct {
            case 90...100: return "🔥 Mükemmel! Böyle devam et!"
            case 70..<90:  return "💪 Harika gidiyorsun, neredeyse mükemmel!"
            case 50..<70:  return "📈 İyi ilerleme, daha fazla gün hedefle"
            default:       return "🎯 En iyi sonuç için her gün kayıt yapmaya çalış"
            }
        }
    }
}
