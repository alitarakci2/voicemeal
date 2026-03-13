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
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            // Weekly average bars
            VStack(spacing: 10) {
                macroBar("Protein", avg: avgProtein, target: targetProtein, color: Theme.blue)
                macroBar("Karb", avg: avgCarbs, target: targetCarbs, color: Theme.orange)
                macroBar("Ya\u{011F}", avg: avgFat, target: targetFat, color: .yellow)
            }

            Divider()
                .overlay(Theme.cardBorder)

            // Today's macro distribution
            Text("Bug\u{00FC}n\u{00FC}n Da\u{011F}\u{0131}l\u{0131}m\u{0131}")
                .font(Theme.bodyFont)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)

            if todayTotal > 0 {
                let proteinPct = Int((todayProtein * 4 / todayTotal) * 100)
                let carbPct = Int((todayCarbs * 4 / todayTotal) * 100)
                let fatPct = 100 - proteinPct - carbPct

                HStack(spacing: 0) {
                    macroSegment("P", pct: proteinPct, color: Theme.blue)
                    macroSegment("K", pct: carbPct, color: Theme.orange)
                    macroSegment("Y", pct: fatPct, color: .yellow)
                }
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    legendDot("Protein %\(proteinPct)", color: Theme.blue)
                    Spacer()
                    legendDot("Karb %\(carbPct)", color: Theme.orange)
                    Spacer()
                    legendDot("Ya\u{011F} %\(fatPct)", color: .yellow)
                }
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Hen\u{00FC}z veri yok")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .themeCard()
    }

    private func macroBar(_ name: String, avg: Double, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(avg / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(avg))g / \(target)g")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
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
                            .font(Theme.microFont)
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
