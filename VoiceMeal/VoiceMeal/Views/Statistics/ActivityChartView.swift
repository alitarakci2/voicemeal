//
//  ActivityChartView.swift
//  VoiceMeal
//

import Charts
import SwiftUI

struct ActivityChartView: View {
    let stats: [DayStat]

    private var activityCounts: [(activity: String, count: Int, emoji: String, label: String)] {
        var counts: [String: Int] = [:]
        for stat in stats {
            for activity in stat.activities {
                counts[activity, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (activity, count) in
            let emoji: String
            let label: String
            switch activity {
            case "weights": emoji = "\u{1F3CB}\u{FE0F}"; label = "activity_weights".localized
            case "running": emoji = "\u{1F3C3}"; label = "activity_running".localized
            case "cycling": emoji = "\u{1F6B4}"; label = "activity_cycling".localized
            case "walking": emoji = "\u{1F6B6}"; label = "activity_walking".localized
            case "rest": emoji = "\u{1F4A4}"; label = "activity_rest".localized
            default: emoji = "\u{2753}"; label = activity
            }
            return (activity, count, emoji, label)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("activity_distribution".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            if activityCounts.isEmpty {
                Text("no_data_yet".localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                let maxCount = activityCounts.map(\.count).max() ?? 1

                ForEach(activityCounts, id: \.activity) { item in
                    HStack(spacing: 8) {
                        Text("\(item.emoji) \(item.label)")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            let width = geo.size.width * Double(item.count) / Double(maxCount)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.activity == "rest" ? Theme.textTertiary : Theme.blue)
                                .frame(width: max(width, 4))
                        }
                        .frame(height: 16)

                        Text("\(item.count) \("days_unit".localized)")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
