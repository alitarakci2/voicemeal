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
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("calorie_tracking".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            if stats.isEmpty || stats.allSatisfy({ !$0.hasData }) {
                Text("no_data_yet".localized)
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
                            .foregroundStyle(stat.consumedCalories > stat.targetCalories ? Theme.warning : Theme.green)
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
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
