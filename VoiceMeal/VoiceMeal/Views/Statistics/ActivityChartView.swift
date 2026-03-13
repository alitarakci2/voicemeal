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
            case "weights": emoji = "\u{1F3CB}\u{FE0F}"; label = "A\u{011F}\u{0131}rl\u{0131}k"
            case "running": emoji = "\u{1F3C3}"; label = "Ko\u{015F}u"
            case "cycling": emoji = "\u{1F6B4}"; label = "Bisiklet"
            case "walking": emoji = "\u{1F6B6}"; label = "Y\u{00FC}r\u{00FC}y\u{00FC}\u{015F}"
            case "rest": emoji = "\u{1F4A4}"; label = "Dinlenme"
            default: emoji = "\u{2753}"; label = activity
            }
            return (activity, count, emoji, label)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktivite Da\u{011F}\u{0131}l\u{0131}m\u{0131}")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            if activityCounts.isEmpty {
                Text("Hen\u{00FC}z veri yok")
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

                        Text("\(item.count) g\u{00FC}n")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .themeCard()
    }
}
