//
//  ProgramSummaryView.swift
//  VoiceMeal
//

import SwiftUI

struct ProgramSummaryView: View {
    let summary: ProgramSummary
    let targetProtein: Int
    let targetCarbs: Int
    let targetFat: Int
    let realWeightDate: Date?

    @State private var insightText: String?
    @State private var insightLoading = false

    @Environment(GroqService.self) private var groqService

    var body: some View {
        if summary.totalDays < 3 {
            VStack(spacing: 12) {
                Text("Henüz yeterli veri yok")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("3 gün sonra program özeti görünür")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 16) {
                // Program start
                programStartCard

                // Weight goal
                weightGoalCard

                // Total stats grid
                totalStatsGrid

                // Best / worst day
                bestWorstCard

                // Streak
                streakCard

                // Macro averages
                macroAveragesCard

                // Groq program insight
                programInsightCard

                Spacer(minLength: 20)
            }
            .task {
                await loadProgramInsight()
            }
        }
    }

    // MARK: - Program Start

    private var programStartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📅 Program Başlangıcı")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            Text("Başlangıç: \(summary.startDate.formatted(.dateTime.day().month(.wide).year()))")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            Text("⏱ \(summary.totalDays) gün / \(summary.totalDays + summary.daysRemaining) gün (%\(programCompletionPercent))")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            // Progress bar
            GeometryReader { geo in
                let progress = min(Double(programCompletionPercent) / 100.0, 1.0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .themeCard()
    }

    private var comparisonText: String {
        let changeText = String(format: "%.2f", abs(summary.estimatedWeightChangeKg))
        let expectedText = String(format: "%.2f", summary.expectedChangeByNow)
        switch summary.goalDirection {
        case .losing: return "Tahmini: -\(changeText) kg / Beklenen: -\(expectedText) kg"
        case .gaining: return "Tahmini: +\(changeText) kg / Beklenen: +\(expectedText) kg"
        case .maintenance: return "Değişim: \(changeText) kg (hedef: stabil)"
        }
    }

    private var onTrackText: String {
        switch summary.onTrackLevel {
        case 2: return "✅ Hedefte gidiyorsun!"
        case 1: return "👌 Hedefe yakın gidiyorsun"
        default:
            switch summary.goalDirection {
            case .losing: return "⚠️ Biraz geride — açığı artır"
            case .gaining: return "⚠️ Biraz geride — kaloriyi artır"
            case .maintenance: return "⚠️ Hedeften sapma var"
            }
        }
    }

    private var onTrackColor: Color {
        summary.onTrackLevel >= 1 ? Theme.green : Theme.orange
    }

    private var programCompletionPercent: Int {
        let total = summary.totalDays + summary.daysRemaining
        guard total > 0 else { return 0 }
        return min(100, (summary.totalDays * 100) / total)
    }

    // MARK: - Weight Goal

    private var weightGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚖️ Kilo Hedefi")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            // Weight labels
            HStack {
                VStack(spacing: 2) {
                    Text("Başlangıç")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(String(format: "%.1f", summary.startWeight)) kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Tahmini")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    let estimated = summary.startWeight - summary.estimatedWeightChangeKg
                    Text("\(String(format: "%.1f", estimated)) kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Hedef")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(String(format: "%.1f", summary.goalWeight)) kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }

            // Progress bar
            GeometryReader { geo in
                let progress = min(Double(summary.progressPercent) / 100.0, 1.0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(onTrackColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("%\(summary.progressPercent) tamamlandı")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)

            // Comparison
            Text(comparisonText)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)

            // On track indicator
            Text(onTrackText)
                .font(Theme.bodyFont)
                .foregroundStyle(onTrackColor)

            // Real weight comparison
            if summary.currentWeight != summary.startWeight {
                Divider()
                    .background(Theme.cardBorder)

                let realWeight = summary.currentWeight
                let dateStr = realWeightDate?.formatted(.dateTime.day().month(.abbreviated)) ?? ""
                let healthNote = dateStr.isEmpty ? "" : " (\(dateStr), Health'ten)"

                Text("⚖️ Gerçek Kilo: \(String(format: "%.1f", realWeight)) kg\(healthNote)")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)

                let estimatedWeight = summary.startWeight - (Double(summary.totalDeficitKcal) / 7700.0)
                let diff = estimatedWeight - realWeight
                let _ = {
                    print("📊 startWeight: \(summary.startWeight)")
                    print("📊 totalDeficitKcal: \(summary.totalDeficitKcal)")
                    print("📊 estimatedWeight: \(estimatedWeight)")
                    print("📊 realWeight (summary.currentWeight): \(realWeight)")
                    print("📊 diff (estimated - real): \(diff)")
                    print("📊 label: \(diff > 0.1 ? "fazla verdin" : diff < -0.1 ? "geride" : "ortusuyor")")
                }()

                if diff > 0.1 {
                    Text("✅ Beklenenden \(String(format: "%.1f", diff)) kg fazla verdin!")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.green)
                } else if diff < -0.1 {
                    Text("⚠️ Tahminden \(String(format: "%.1f", abs(diff))) kg geride")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.orange)
                } else {
                    Text("👌 Tahminle örtüşüyor")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding()
        .themeCard()
    }

    // MARK: - Total Stats Grid

    private var totalStatsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            statCell(
                icon: "🔥",
                title: summary.goalDirection == .gaining ? "Toplam Fazla" : "Toplam Açık",
                value: "\(abs(summary.totalDeficitKcal))",
                unit: "kcal"
            )
            statCell(icon: "📊", title: "Ort. Günlük Kalori", value: "\(summary.avgDailyCalories)", unit: "kcal")
            statCell(icon: "💪", title: "Antrenman Günleri", value: "\(summary.totalWorkoutDays) / \(summary.totalDays)", unit: "gün")
            statCell(icon: "📅", title: "Takip Oranı", value: "%\(summary.adherencePercent)", unit: "")
        }
    }

    private func statCell(icon: String, title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 24))
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            if !unit.isEmpty {
                Text(unit)
                    .font(Theme.microFont)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .themeCard()
    }

    // MARK: - Best / Worst Day

    private func bestDayLabel(date: Date, value: Int) -> String {
        let dateStr = date.formatted(.dateTime.day().month(.abbreviated))
        switch summary.goalDirection {
        case .losing: return "🏆 En iyi gün: \(dateStr) — \(value) kcal açık"
        case .gaining: return "🏆 En iyi gün: \(dateStr) — \(value) kcal fazla"
        case .maintenance: return "🏆 En iyi gün: \(dateStr) — \(value) kcal sapma"
        }
    }

    private func worstDayLabel(date: Date, value: Int) -> String {
        let dateStr = date.formatted(.dateTime.day().month(.abbreviated))
        switch summary.goalDirection {
        case .losing:
            return value >= 0
                ? "😬 En zor gün: \(dateStr) — \(value) kcal açık"
                : "😬 En zor gün: \(dateStr) — \(abs(value)) kcal fazla"
        case .gaining:
            return value >= 0
                ? "😬 En zor gün: \(dateStr) — \(value) kcal fazla"
                : "😬 En zor gün: \(dateStr) — \(abs(value)) kcal eksik"
        case .maintenance:
            return "😬 En zor gün: \(dateStr) — \(value) kcal sapma"
        }
    }

    private var bestWorstCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let best = summary.bestDay {
                Text(bestDayLabel(date: best.date, value: best.value))
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.green)
            }

            if let worst = summary.worstDay {
                Text(worstDayLabel(date: worst.date, value: worst.value))
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.orange)
            }
        }
        .padding()
        .themeCard()
    }

    // MARK: - Streak

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 Mevcut seri: \(summary.currentStreak) gün")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("⭐ En iyi seri: \(summary.bestStreak) gün")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .themeCard()
    }

    // MARK: - Macro Averages

    private var macroAveragesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Makro Ortalaması")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            macroBar("Protein", avg: Int(summary.avgDailyProtein), target: targetProtein, color: Theme.blue)
            macroBar("Karb", avg: Int(summary.avgDailyCarbs), target: targetCarbs, color: Theme.orange)
            macroBar("Yağ", avg: Int(summary.avgDailyFat), target: targetFat, color: .yellow)
        }
        .padding()
        .themeCard()
    }

    private func macroBar(_ name: String, avg: Int, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(Double(avg) / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("\(avg)g / \(target)g")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 90, alignment: .trailing)
        }
    }

    // MARK: - Program Insight

    private var programInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🧠 Program Koçu")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            if insightLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if let insight = insightText {
                Text(insight)
                    .font(Theme.bodyFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            } else {
                Text("Değerlendirme yükleniyor...")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .themeCard()
    }

    private func loadProgramInsight() async {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)
        let cacheKey = "programInsight_\(year)_\(weekOfYear)"

        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            insightText = cached
            return
        }

        guard summary.totalDays >= 3 else { return }

        insightLoading = true
        do {
            let insight = try await groqService.generateProgramInsight(summary: summary)
            insightText = insight
            UserDefaults.standard.set(insight, forKey: cacheKey)
        } catch {
            // Program insight error
            insightText = "Değerlendirme yüklenemedi."
        }
        insightLoading = false
    }
}
