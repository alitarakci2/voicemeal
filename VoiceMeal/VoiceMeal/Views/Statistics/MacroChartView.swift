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
    @EnvironmentObject private var themeManager: ThemeManager

    private var todayTotal: Double {
        todayProtein * 4 + todayCarbs * 4 + todayFat * 9
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("macro_averages_title".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            // Weekly average bars
            VStack(spacing: 10) {
                macroBar("protein_label".localized, avg: avgProtein, target: targetProtein, color: Theme.blue)
                macroBar("carb_label".localized, avg: avgCarbs, target: targetCarbs, color: Theme.orange)
                macroBar("fat_label".localized, avg: avgFat, target: targetFat, color: Theme.fatColor)
            }

            Divider()
                .overlay(Theme.cardBorder)

            // Today's macro distribution
            Text("todays_distribution".localized)
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
                    macroSegment("Y", pct: fatPct, color: Theme.fatColor)
                }
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    legendDot("\("protein_label".localized) %\(proteinPct)", color: Theme.blue)
                    Spacer()
                    legendDot("\("carb_label".localized) %\(carbPct)", color: Theme.orange)
                    Spacer()
                    legendDot("\("fat_label".localized) %\(fatPct)", color: Theme.fatColor)
                }
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
            } else {
                Text("no_data_yet".localized)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
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
