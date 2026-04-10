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
    @EnvironmentObject private var themeManager: ThemeManager

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
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("cumulative_deficit".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            if snapshotStats.isEmpty {
                Text("no_data_yet".localized)
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
                    Text("\("total_colon".localized) \(last.cumulativeDeficit) kcal")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
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
