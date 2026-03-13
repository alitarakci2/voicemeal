//
//  DeficitChartView.swift
//  VoiceMeal
//

import Charts
import SwiftUI

struct DeficitChartView: View {
    let stats: [DayStat]
    let goalDays: Int
    let totalNeededDeficit: Double

    private var snapshotStats: [(date: Date, cumulativeDeficit: Int)] {
        let filtered = stats.filter { $0.hasData && $0.hasSnapshot }
        var cumulative = 0
        return filtered.map { stat in
            cumulative += stat.deficit
            return (date: stat.date, cumulativeDeficit: cumulative)
        }
    }

    private var targetCumulativeForToday: Double {
        guard goalDays > 0 else { return 0 }
        let daysPassed = Double(snapshotStats.count)
        return totalNeededDeficit / Double(goalDays) * daysPassed
    }

    private var isAhead: Bool {
        guard let last = snapshotStats.last else { return true }
        return Double(last.cumulativeDeficit) >= targetCumulativeForToday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Birikimli A\u{00E7}\u{0131}k")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            if snapshotStats.isEmpty {
                Text("Hen\u{00FC}z yeterli veri yok")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart {
                    ForEach(snapshotStats, id: \.date) { item in
                        LineMark(
                            x: .value("Tarih", item.date, unit: .day),
                            y: .value("Birikimli", item.cumulativeDeficit)
                        )
                        .foregroundStyle(isAhead ? Theme.green : Theme.orange)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Tarih", item.date, unit: .day),
                            y: .value("Birikimli", item.cumulativeDeficit)
                        )
                        .foregroundStyle(
                            (isAhead ? Theme.green : Theme.orange).opacity(0.15)
                        )
                    }
                }
                .chartYAxisLabel("kcal")
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.cardBorder)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 180)

                if let last = snapshotStats.last {
                    Text("Toplam: \(last.cumulativeDeficit) kcal")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding()
        .themeCard()
    }
}
