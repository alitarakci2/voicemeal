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
                .font(.headline)

            if stats.isEmpty || stats.allSatisfy({ !$0.hasData }) {
                Text("Hen\u{00FC}z yeterli veri yok")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart {
                    ForEach(stats) { stat in
                        if stat.hasData {
                            BarMark(
                                x: .value("Tarih", stat.date, unit: .day),
                                y: .value("Kalori", stat.consumedCalories)
                            )
                            .foregroundStyle(stat.consumedCalories > stat.targetCalories ? .orange : .green)

                            if stat.targetCalories > 0 {
                                RuleMark(y: .value("Hedef", stat.targetCalories))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
                .chartYAxisLabel("kcal")
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
