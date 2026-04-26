//
//  NutritionReportSheet.swift
//  VoiceMeal
//

import SwiftUI
import UIKit

struct NutritionReportSheet: View {
    let report: NutritionReport
    let period: ReportPeriod
    let kind: ReportPeriodKind
    let programDay: Int
    let programTotalDays: Int
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let isCooldownActive: Bool
    let cooldownSecondsRemaining: Int
    let isRefreshing: Bool
    let canRefresh: Bool
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var shareURL: URL?
    @State private var showShare = false

    private var isEN: Bool { report.language == "en" }

    private var periodLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: isEN ? "en_US" : "tr_TR")
        switch period {
        case .week:
            fmt.dateFormat = "d MMM"
            let s = fmt.string(from: report.effectivePeriodStart)
            let e = fmt.string(from: report.effectivePeriodEnd)
            return "\(s) – \(e)"
        case .month:
            fmt.dateFormat = "LLLL yyyy"
            return fmt.string(from: report.effectivePeriodStart).capitalized
        case .program:
            if kind == .programCompleted {
                return isEN ? "Program — Completed" : "Program Tamamlandı"
            }
            let day = programDay > 0 ? programDay : report.programDay
            let total = programTotalDays > 0 ? programTotalDays : report.programTotalDays
            if total > 0 {
                return isEN ? "Day \(day) of \(total)" : "Gün \(day)/\(total)"
            }
            return isEN ? "Program" : "Program"
        }
    }

    // Back-compat for call sites / internal use.
    private var weekLabel: String { periodLabel }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scoreHeader
                    summarySection

                    if !report.strengths.isEmpty {
                        listSection(
                            title: isEN ? "Strengths" : "Güçlü Yanlar",
                            icon: "checkmark.seal.fill",
                            iconColor: Theme.success,
                            items: report.strengths
                        )
                    }

                    if !report.improvements.isEmpty {
                        listSection(
                            title: isEN ? "Areas to Improve" : "Gelişim Alanları",
                            icon: "target",
                            iconColor: Theme.macroCarb,
                            items: report.improvements
                        )
                    }

                    if !report.microInsights.isEmpty {
                        microInsightsSection
                    }

                    if !report.weeklyPattern.isEmpty {
                        patternSection
                    }

                    macroBarSection

                    actionButtons
                    generatedAtLine
                    disclaimer

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(isEN ? "Nutrition Report" : "Beslenme Karnesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEN ? "Close" : "Kapat") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: CGFloat(report.score) / 10.0)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent, Theme.accentLight, Theme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(report.score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/10")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(periodLabel)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(daysLoggedLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var summarySection: some View {
        Text(report.summary)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .lineSpacing(4)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func listSection(title: String, icon: String, iconColor: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Theme.textSecondary)
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var microInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(hex: "5DADE2"))
                Text(isEN ? "Micronutrient Notes" : "Mikrobesin Notları")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Text(report.microInsights)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var patternSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.accent)
                Text(patternSectionTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Text(report.weeklyPattern)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var macroBarSection: some View {
        let proteinKcal = avgProtein * 4
        let carbsKcal = avgCarbs * 4
        let fatKcal = avgFat * 9
        let total = max(1, proteinKcal + carbsKcal + fatKcal)
        let pP = proteinKcal / total
        let pC = carbsKcal / total
        let pF = fatKcal / total

        return VStack(alignment: .leading, spacing: 10) {
            Text(isEN ? "Avg Macro Distribution" : "Ortalama Makro Dağılımı")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
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
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 14)

            HStack(spacing: 14) {
                legend(color: Theme.danger, label: isEN ? "Protein \(Int(avgProtein))g" : "Protein \(Int(avgProtein))g")
                legend(color: Theme.macroCarb, label: isEN ? "Carbs \(Int(avgCarbs))g" : "Karb. \(Int(avgCarbs))g")
                legend(color: Theme.success, label: isEN ? "Fat \(Int(avgFat))g" : "Yağ \(Int(avgFat))g")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onRefresh) {
                HStack(spacing: 6) {
                    if isRefreshing {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(refreshButtonLabel)
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canRefresh ? Theme.accent : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canRefresh || isRefreshing)

            Button(action: prepareShare) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(isEN ? "Share" : "Paylaş")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var refreshButtonLabel: String {
        if isRefreshing {
            return isEN ? "Refreshing…" : "Yenileniyor…"
        }
        if isCooldownActive {
            let m = cooldownSecondsRemaining / 60
            let s = cooldownSecondsRemaining % 60
            return String(format: "%@ %02d:%02d", isEN ? "Cooldown" : "Bekleme", m, s)
        }
        return isEN ? "Refresh" : "Yenile"
    }

    private var generatedAtLine: some View {
        HStack {
            Spacer()
            Text(
                isEN
                ? "Generated \(report.generatedAt.formatted(.dateTime.weekday(.wide).hour().minute()))"
                : "Üretildi: \(report.generatedAt.formatted(.dateTime.weekday(.wide).hour().minute()))"
            )
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
    }

    private var disclaimer: some View {
        Text(
            isEN
            ? "Micronutrient analysis is an AI estimate. Not medical advice."
            : "Mikrobesin analizi AI tahminidir. Medikal öneri yerine geçmez."
        )
        .font(.caption2)
        .foregroundStyle(Theme.textTertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var kindLabel: String {
        switch period {
        case .week:
            switch kind {
            case .current:    return isEN ? "This week" : "Bu hafta"
            case .previous:   return isEN ? "Last week" : "Geçen hafta"
            case .inProgress: return isEN ? "In progress" : "Devam ediyor"
            default:          return isEN ? "This week" : "Bu hafta"
            }
        case .month:
            switch kind {
            case .current:    return isEN ? "This month" : "Bu ay"
            case .previous:   return isEN ? "Last month" : "Geçen ay"
            case .inProgress: return isEN ? "In progress" : "Devam ediyor"
            default:          return isEN ? "This month" : "Bu ay"
            }
        case .program:
            switch kind {
            case .programNotStarted: return isEN ? "No active program" : "Aktif program yok"
            case .programCompleted:  return isEN ? "Program completed" : "Program tamamlandı"
            default:                 return isEN ? "In progress" : "Devam ediyor"
            }
        }
    }

    private var daysLoggedLabel: String {
        switch period {
        case .week:
            return isEN ? "\(report.daysOfData)/7 days logged" : "\(report.daysOfData)/7 gün kayıtlı"
        case .month:
            let totalDays = max(1, daysInMonth(for: report.effectivePeriodStart))
            return isEN ? "\(report.daysOfData)/\(totalDays) days logged" : "\(report.daysOfData)/\(totalDays) gün kayıtlı"
        case .program:
            let total = programTotalDays > 0 ? programTotalDays : report.programTotalDays
            if total > 0 {
                return isEN
                    ? "\(report.daysOfData) of \(total) program days logged"
                    : "Program boyunca \(report.daysOfData)/\(total) gün kayıtlı"
            }
            return isEN ? "\(report.daysOfData) days logged" : "\(report.daysOfData) gün kayıtlı"
        }
    }

    private func daysInMonth(for date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private var patternSectionTitle: String {
        switch period {
        case .week:    return isEN ? "Weekly Pattern" : "Haftalık Örüntü"
        case .month:   return isEN ? "Monthly Pattern" : "Aylık Örüntü"
        case .program: return isEN ? "Program Pattern" : "Program Örüntüsü"
        }
    }

    private func prepareShare() {
        let view = ShareableReportView(
            report: report,
            periodTitle: cardHeaderTitle,
            periodSubtitle: periodLabel,
            avgProtein: avgProtein,
            avgCarbs: avgCarbs,
            avgFat: avgFat
        )
        guard let image = ImageExporter.render(view, size: CGSize(width: 1080, height: 1920), scale: 1.0) else {
            return
        }
        let filename = NutritionReportService.shareFilename(
            for: period,
            periodStart: report.effectivePeriodStart,
            programDay: programDay > 0 ? programDay : report.programDay
        )
        guard let url = ImageExporter.writePNG(image, filename: filename) else { return }
        shareURL = url
        FeedbackService.shared.addLog("nutrition_report_shared: period=\(period.rawValue) lang=\(report.language)")
        showShare = true
    }

    private var cardHeaderTitle: String {
        isEN ? "Nutrition Report Card" : "Beslenme Karnesi"
    }
}

// MARK: - UIKit Share Sheet bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
