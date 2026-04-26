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
    var coachStyle: CoachStyle = .supportive
    var personalContext: String = ""

    @State private var insightText: String?
    @State private var insightLoading = false

    @Environment(GroqService.self) private var groqService

    private var isEN: Bool { groqService.appLanguage == "en" }

    var body: some View {
        if summary.totalDays < 3 {
            VStack(spacing: 12) {
                Text(L.notEnoughData.localized)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("program_summary_min_days".localized)
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
        let completionProgress = min(Double(programCompletionPercent) / 100.0, 1.0)
        return HStack(spacing: 14) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: completionProgress)
                    .stroke(Theme.accent,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(programCompletionPercent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(L.doneLower.localized)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 13))
                    Text(L.programStartDate.localized)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                Text(summary.startDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)

                Text(String(format: "day_progress_format".localized, summary.totalDays, summary.totalDays + summary.daysRemaining, programCompletionPercent))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
    }

    private var comparisonText: String {
        let changeText = String(format: "%.2f", abs(summary.estimatedWeightChangeKg))
        let expectedText = String(format: "%.2f", summary.expectedChangeByNow)
        switch summary.goalDirection {
        case .losing: return String(format: "estimated_change_losing".localized, changeText, expectedText)
        case .gaining: return String(format: "estimated_change_gaining".localized, changeText, expectedText)
        case .maintenance: return String(format: "change_maintenance".localized, changeText)
        }
    }

    private var onTrackText: String {
        switch summary.onTrackLevel {
        case 2: return "✅ \("on_track".localized)"
        case 1: return "👌 \("near_track".localized)"
        default:
            switch summary.goalDirection {
            case .losing: return "⚠️ \("behind_increase_deficit".localized)"
            case .gaining: return "⚠️ \("behind_increase_calories".localized)"
            case .maintenance: return "⚠️ \("off_target".localized)"
            }
        }
    }

    private var onTrackColor: Color {
        summary.onTrackLevel >= 1 ? Theme.green : Theme.warning
    }

    private var programCompletionPercent: Int {
        let total = summary.totalDays + summary.daysRemaining
        guard total > 0 else { return 0 }
        return min(100, (summary.totalDays * 100) / total)
    }

    // MARK: - Weight Goal

    private var weightGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("weight_goal".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            // Weight labels
            HStack {
                VStack(spacing: 2) {
                    Text("start_weight".localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(String(format: "%.2f", summary.startWeight)) kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text(L.estimated.localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    let estimated = summary.startWeight - summary.estimatedWeightChangeKg
                    Text("\(String(format: "%.2f", estimated)) kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text(L.goal.localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(String(format: "%.2f", summary.goalWeight)) kg")
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

            Text(String(format: "percent_completed".localized, summary.progressPercent))
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
                let healthNote = dateStr.isEmpty ? "" : String(format: "health_source".localized, dateStr)

                Text(String(format: "real_weight_detail".localized, String(format: "%.2f", realWeight), healthNote))
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)

                let estimatedWeight = summary.startWeight - (Double(summary.totalDeficitKcal) / 7700.0)
                let diff = estimatedWeight - realWeight

                if diff > 0.1 {
                    Text("✅ \(String(format: "ahead_kg".localized, String(format: "%.2f", diff)))")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.green)
                } else if diff < -0.1 {
                    Text("⚠️ \(String(format: "behind_kg".localized, String(format: "%.2f", abs(diff))))")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.warning)
                } else {
                    Text("👌 \("matches_estimate".localized)")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
    }

    // MARK: - Total Stats Grid

    private var totalStatsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            statCell(
                icon: "🔥",
                title: summary.goalDirection == .gaining ? "total_surplus".localized : "total_deficit_label".localized,
                value: "\(abs(summary.totalDeficitKcal))",
                unit: "kcal"
            )
            statCell(icon: "📊", title: "avg_daily_calories".localized, value: "\(summary.avgDailyCalories)", unit: "kcal")
            statCell(icon: "💪", title: "workout_days".localized, value: "\(summary.totalWorkoutDays) / \(summary.totalDays)", unit: "day_suffix".localized)
            statCell(icon: "📅", title: "adherence_rate".localized, value: "%\(summary.adherencePercent)", unit: "")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
    }

    // MARK: - Best / Worst Day

    private func bestDayLabel(date: Date, value: Int) -> String {
        let dateStr = date.formatted(.dateTime.day().month(.abbreviated))
        switch summary.goalDirection {
        case .losing: return String(format: "best_day_deficit".localized, dateStr, value)
        case .gaining: return String(format: "best_day_surplus".localized, dateStr, value)
        case .maintenance: return String(format: "best_day_deviation".localized, dateStr, value)
        }
    }

    private func worstDayLabel(date: Date, value: Int) -> String {
        let dateStr = date.formatted(.dateTime.day().month(.abbreviated))
        switch summary.goalDirection {
        case .losing:
            return value >= 0
                ? String(format: "worst_day_deficit".localized, dateStr, value)
                : String(format: "worst_day_surplus".localized, dateStr, abs(value))
        case .gaining:
            return value >= 0
                ? String(format: "worst_day_surplus".localized, dateStr, value)
                : String(format: "worst_day_short".localized, dateStr, abs(value))
        case .maintenance:
            return String(format: "worst_day_deviation".localized, dateStr, value)
        }
    }

    private var bestWorstCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text(L.highlights.localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            if let best = summary.bestDay {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Theme.green)
                        .font(.system(size: 12))
                    Text(bestDayLabel(date: best.date, value: best.value))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.green)
                }
            }

            if let worst = summary.worstDay {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.warning)
                        .font(.system(size: 12))
                    Text(worstDayLabel(date: worst.date, value: worst.value))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.warning)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
    }

    // MARK: - Streak

    private var streakCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.indioOrange)
                .font(.system(size: 28))
                .frame(width: 50, height: 50)
                .background(Theme.indioOrange.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "current_streak_days".localized, summary.currentStreak))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(String(format: "best_streak_days".localized, summary.bestStreak))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
    }

    // MARK: - Macro Averages

    private var macroAveragesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("macro_averages".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            macroBar(L.protein.localized, avg: Int(summary.avgDailyProtein), target: targetProtein, color: Theme.blue)
            macroBar(L.carbs.localized, avg: Int(summary.avgDailyCarbs), target: targetCarbs, color: Theme.macroCarb)
            macroBar(L.fat.localized, avg: Int(summary.avgDailyFat), target: targetFat, color: Theme.fatColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
        )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text("program_coach".localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            if insightLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.accent)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if let insight = insightText {
                Text(insight)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            } else {
                Text("assessment_loading".localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
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

    private func loadProgramInsight() async {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)
        let isCompleted = summary.daysRemaining == 0
        let branchTag = isCompleted ? "completed" : "ongoing"
        let cacheKey = "programInsight_v\(GroqService.programInsightPromptVersion)_\(branchTag)_\(year)_\(weekOfYear)_\(groqService.appLanguage)"

        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            insightText = cached
            return
        }

        guard summary.totalDays >= 3 else { return }

        insightLoading = true
        do {
            let insight = try await groqService.generateProgramInsight(
                summary: summary,
                isCompleted: isCompleted,
                coachStyle: coachStyle,
                personalContext: personalContext
            )
            insightText = insight
            UserDefaults.standard.set(insight, forKey: cacheKey)
        } catch {
            FeedbackService.shared.addErrorLog("ProgramInsight: \(error.localizedDescription)")
            insightText = "assessment_failed".localized
        }
        insightLoading = false
    }
}
