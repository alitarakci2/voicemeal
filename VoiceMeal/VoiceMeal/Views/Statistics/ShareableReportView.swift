//
//  ShareableReportView.swift
//  VoiceMeal
//

import SwiftUI

struct ShareableReportView: View {
    let report: NutritionReport
    let periodTitle: String       // e.g. "Nutrition Report Card" / "Beslenme Karnesi"
    let periodSubtitle: String    // period + range, e.g. "This Week · 14 Apr – 20 Apr"
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double

    private var isEN: Bool { report.language == "en" }

    private var scoreSubtitle: String {
        switch report.periodType {
        case .week:    return isEN ? "Weekly Score" : "Haftalık Skor"
        case .month:   return isEN ? "Monthly Score" : "Aylık Skor"
        case .program: return isEN ? "Program Score" : "Program Skoru"
        }
    }

    private var proteinKcal: Double { avgProtein * 4 }
    private var carbsKcal: Double { avgCarbs * 4 }
    private var fatKcal: Double { avgFat * 9 }
    private var totalKcal: Double { max(1, proteinKcal + carbsKcal + fatKcal) }

    private var proteinPct: Double { proteinKcal / totalKcal }
    private var carbsPct: Double { carbsKcal / totalKcal }
    private var fatPct: Double { fatKcal / totalKcal }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.gradientTop, Theme.gradientMid, Color(hex: "0A0A0F")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer().frame(height: 60)

                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("VoiceMeal")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 16) {
                    Text(periodTitle)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(periodSubtitle)
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 22)
                        .frame(width: 340, height: 340)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.score) / 10.0)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.accent, Theme.accentLight, Theme.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round)
                        )
                        .frame(width: 340, height: 340)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(report.score)")
                                .font(.system(size: 140, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("/10")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Text(scoreSubtitle)
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Text(report.summary)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 60)
                    .fixedSize(horizontal: false, vertical: true)

                macroBar
                    .padding(.horizontal, 60)

                Spacer()

                VStack(spacing: 8) {
                    Text(isEN
                         ? "Micronutrient analysis is an AI estimate. Not medical advice."
                         : "Mikrobesin analizi AI tahminidir. Medikal öneri yerine geçmez.")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)

                    Text("voicemeal.app")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    private var macroBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEN ? "Macro Distribution" : "Makro Dağılımı")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.danger)
                        .frame(width: geo.size.width * proteinPct)
                    Rectangle()
                        .fill(Theme.macroCarb)
                        .frame(width: geo.size.width * carbsPct)
                    Rectangle()
                        .fill(Theme.success)
                        .frame(width: geo.size.width * fatPct)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 36)

            HStack(spacing: 24) {
                macroLegend(color: Theme.danger, label: isEN ? "Protein" : "Protein", pct: proteinPct)
                macroLegend(color: Theme.macroCarb, label: isEN ? "Carbs" : "Karb.", pct: carbsPct)
                macroLegend(color: Theme.success, label: isEN ? "Fat" : "Yağ", pct: fatPct)
            }
        }
    }

    private func macroLegend(color: Color, label: String, pct: Double) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 16, height: 16)
            Text("\(label) \(Int((pct * 100).rounded()))%")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
