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
                .font(.headline)

            if snapshotStats.isEmpty {
                Text("Hen\u{00FC}z yeterli veri yok")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart {
                    ForEach(snapshotStats, id: \.date) { item in
                        LineMark(
                            x: .value("Tarih", item.date, unit: .day),
                            y: .value("Birikimli", item.cumulativeDeficit)
                        )
                        .foregroundStyle(isAhead ? .green : .orange)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Tarih", item.date, unit: .day),
                            y: .value("Birikimli", item.cumulativeDeficit)
                        )
                        .foregroundStyle(
                            (isAhead ? Color.green : Color.orange).opacity(0.1)
                        )
                    }
                }
                .chartYAxisLabel("kcal")
                .frame(height: 180)

                if let last = snapshotStats.last {
                    Text("Toplam: \(last.cumulativeDeficit) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
