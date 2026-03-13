//
//  CalorieChartView.swift
//  VoiceMeal
//

import Charts
import SwiftUI

struct CalorieChartView: View {
    let stats: [DayStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kalori Takibi")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            if stats.isEmpty || stats.allSatisfy({ !$0.hasData }) {
                Text("Hen\u{00FC}z yeterli veri yok")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart {
                    ForEach(stats) { stat in
                        if stat.hasData {
                            BarMark(
                                x: .value("Tarih", stat.date, unit: .day),
                                y: .value("Kalori", stat.consumedCalories)
                            )
                            .foregroundStyle(stat.consumedCalories > stat.targetCalories ? Theme.orange : Theme.green)
                            .cornerRadius(4)

                            if stat.targetCalories > 0 {
                                RuleMark(y: .value("Hedef", stat.targetCalories))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
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
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .themeCard()
    }
}
