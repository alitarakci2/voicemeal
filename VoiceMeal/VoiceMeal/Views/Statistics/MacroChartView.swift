//
//  MacroChartView.swift
//  VoiceMeal
//

import Charts
import SwiftUI

struct MacroChartView: View {
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let targetProtein: Int
    let targetCarbs: Int
    let targetFat: Int
    let todayProtein: Double
    let todayCarbs: Double
    let todayFat: Double

    private var todayTotal: Double {
        todayProtein * 4 + todayCarbs * 4 + todayFat * 9
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Makro Ortalamalar\u{0131}")
                .font(.headline)

            // Weekly average bars
            VStack(spacing: 10) {
                macroBar("Protein", avg: avgProtein, target: targetProtein, color: .blue)
                macroBar("Karb", avg: avgCarbs, target: targetCarbs, color: .orange)
                macroBar("Ya\u{011F}", avg: avgFat, target: targetFat, color: .yellow)
            }

            Divider()

            // Today's macro distribution
            Text("Bug\u{00FC}n\u{00FC}n Da\u{011F}\u{0131}l\u{0131}m\u{0131}")
                .font(.subheadline)
                .fontWeight(.medium)

            if todayTotal > 0 {
                let proteinPct = Int((todayProtein * 4 / todayTotal) * 100)
                let carbPct = Int((todayCarbs * 4 / todayTotal) * 100)
                let fatPct = 100 - proteinPct - carbPct

                HStack(spacing: 0) {
                    macroSegment("P", pct: proteinPct, color: .blue)
                    macroSegment("K", pct: carbPct, color: .orange)
                    macroSegment("Y", pct: fatPct, color: .yellow)
                }
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    legendDot("Protein %\(proteinPct)", color: .blue)
                    Spacer()
                    legendDot("Karb %\(carbPct)", color: .orange)
                    Spacer()
                    legendDot("Ya\u{011F} %\(fatPct)", color: .yellow)
                }
                .font(.caption)
            } else {
                Text("Hen\u{00FC}z veri yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func macroBar(_ name: String, avg: Double, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(avg / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(avg))g / \(target)g")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
    }

    private func macroSegment(_ label: String, pct: Int, color: Color) -> some View {
        GeometryReader { geo in
            let width = geo.size.width * Double(max(pct, 0)) / 100.0
            color
                .frame(width: width)
                .overlay {
                    if pct >= 15 {
                        Text("\(label) %\(pct)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                }
        }
    }

    private func legendDot(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}
