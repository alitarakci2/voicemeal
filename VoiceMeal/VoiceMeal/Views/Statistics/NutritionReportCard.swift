//
//  NutritionReportCard.swift
//  VoiceMeal
//

import SwiftUI

struct NutritionReportCard: View {
    let report: NutritionReport?
    let period: ReportPeriod
    let kind: ReportPeriodKind
    let daysOfData: Int
    let programDay: Int
    let programTotalDays: Int
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let isLoading: Bool
    let onTap: () -> Void

    private var isEN: Bool {
        if let r = report { return r.language == "en" }
        return Locale.current.language.languageCode?.identifier == "en"
    }

    private var periodLabel: String {
        switch period {
        case .week:
            switch kind {
            case .current:    return isEN ? "This Week" : "Bu Hafta"
            case .previous:   return isEN ? "Last Week" : "Geçen Hafta"
            case .inProgress: return isEN ? "This Week (in progress)" : "Bu Hafta (devam ediyor)"
            default:          return isEN ? "This Week" : "Bu Hafta"
            }
        case .month:
            switch kind {
            case .current:    return isEN ? "This Month" : "Bu Ay"
            case .previous:   return isEN ? "Last Month" : "Geçen Ay"
            case .inProgress: return isEN ? "This Month (in progress)" : "Bu Ay (devam ediyor)"
            default:          return isEN ? "This Month" : "Bu Ay"
            }
        case .program:
            switch kind {
            case .programNotStarted: return isEN ? "Program — Not Started" : "Program — Başlamadı"
            case .programCompleted:  return isEN ? "Program — Completed" : "Program Tamamlandı"
            default:
                if programTotalDays > 0 {
                    return isEN
                        ? "Program — Day \(programDay) of \(programTotalDays)"
                        : "Program — Gün \(programDay)/\(programTotalDays)"
                }
                return isEN ? "Program" : "Program"
            }
        }
    }

    private var cardTitle: String {
        isEN ? "Nutrition Report Card" : "Beslenme Karnesi"
    }

    private var minimumDays: Int {
        NutritionReportService.minimumDays(for: period)
    }

    private var hasValid: Bool {
        (report?.hasValidScore ?? false) && !isLoading
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                header

                if kind == .programNotStarted {
                    programNotStartedState
                } else if isLoading {
                    loadingState
                } else if let r = report, r.hasValidScore {
                    scoreRow(report: r)
                    summaryText(r.summary)
                    macroBar
                } else {
                    insufficientState
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasValid)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(Theme.accent)
                .font(.system(size: 14))
            Text(cardTitle)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Spacer()
            Text(periodLabel)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
    }

    private func scoreRow(report: NutritionReport) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: CGFloat(report.score) / 10.0)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(report.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/10")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(scoreHeaderLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(scoreLabel(report.score))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textTertiary)
                .font(.system(size: 12, weight: .semibold))
        }
    }

    private var scoreHeaderLabel: String {
        switch period {
        case .week:    return isEN ? "Weekly Score" : "Haftalık Skor"
        case .month:   return isEN ? "Monthly Score" : "Aylık Skor"
        case .program:
            if kind == .programCompleted {
                return isEN ? "Program — Final Score" : "Program — Final Skor"
            }
            return isEN ? "Program Score" : "Program Skoru"
        }
    }

    private func summaryText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var macroBar: some View {
        let proteinKcal = avgProtein * 4
        let carbsKcal = avgCarbs * 4
        let fatKcal = avgFat * 9
        let total = max(1, proteinKcal + carbsKcal + fatKcal)
        let pP = proteinKcal / total
        let pC = carbsKcal / total
        let pF = fatKcal / total

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.danger)
                        .frame(width: geo.size.width * pP)
                    Rectangle()
                        .fill(Theme.macroCarb)
                        .frame(width: geo.size.width * pC)
                    Rectangle()
                        .fill(Theme.success)
                        .frame(width: geo.size.width * pF)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                macroLabel(color: Theme.danger, text: "P \(Int((pP * 100).rounded()))%")
                macroLabel(color: Theme.macroCarb, text: "\(isEN ? "C" : "K") \(Int((pC * 100).rounded()))%")
                macroLabel(color: Theme.success, text: "\(isEN ? "F" : "Y") \(Int((pF * 100).rounded()))%")
            }
        }
    }

    private func macroLabel(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().tint(Theme.accent)
            Text(isEN ? "Analyzing…" : "Analiz ediliyor…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var insufficientState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(Theme.textTertiary)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 3) {
                Text(isEN ? "More data needed" : "Daha fazla kayıt gerekli")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(insufficientSubtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var insufficientSubtitle: String {
        let need = minimumDays
        switch period {
        case .week:
            return isEN
                ? "Log at least \(need) days this week to get a score (\(daysOfData)/\(need))."
                : "Skor için bu hafta en az \(need) gün kayıt gerekli (\(daysOfData)/\(need))."
        case .month:
            return isEN
                ? "Log at least \(need) days this month to get a score (\(daysOfData)/\(need))."
                : "Skor için bu ay en az \(need) gün kayıt gerekli (\(daysOfData)/\(need))."
        case .program:
            return isEN
                ? "Log at least \(need) days in your program to get a score (\(daysOfData)/\(need))."
                : "Skor için programda en az \(need) gün kayıt gerekli (\(daysOfData)/\(need))."
        }
    }

    private var programNotStartedState: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(Theme.textTertiary)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 3) {
                Text(isEN ? "No active program" : "Aktif program yok")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(isEN ? "Create a program to get a program report." : "Rapor için önce bir program oluştur.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 9...10: return isEN ? "Excellent" : "Mükemmel"
        case 7...8:  return isEN ? "Strong" : "Güçlü"
        case 5...6:  return isEN ? "Mixed" : "Dalgalı"
        case 3...4:  return isEN ? "Off track" : "Hedeften uzak"
        default:     return isEN ? "Rough" : "Zorlu"
        }
    }
}
