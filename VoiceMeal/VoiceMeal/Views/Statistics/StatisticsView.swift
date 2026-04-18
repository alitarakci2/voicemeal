//
//  StatisticsView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query(sort: \DailySnapshot.date) private var snapshots: [DailySnapshot]
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Environment(GoalEngine.self) private var goalEngine
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var statisticsService = StatisticsService()
    @State private var selectedRange = 0 // 0 = weekly, 1 = monthly, 2 = program
    @State private var weeklyInsight: String?
    @State private var insightLoading = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasAppeared = false

    @Environment(GroqService.self) private var groqService

    private var isEN: Bool { groqService.appLanguage == "en" }

    private var monthlyHasEnoughData: Bool {
        statisticsService.monthlyStats.filter { $0.hasData }.count >= 14
    }

    private var currentStats: [DayStat] {
        if selectedRange == 1 && !monthlyHasEnoughData {
            return statisticsService.weeklyStats
        }
        return selectedRange == 0 ? statisticsService.weeklyStats : statisticsService.monthlyStats
    }

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    /// Entries within the currently selected stats window.
    /// Weekly uses calendar week (Mon-Sun), monthly uses rolling 30 days.
    private var periodEntries: [FoodEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start: Date
        if selectedRange == 0 {
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            components.weekday = 2 // Monday
            start = calendar.date(from: components) ?? today
        } else {
            start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        }
        return allEntries.filter { $0.date >= start }
    }

    /// DayStats for the period immediately preceding the current window (for trend comparison).
    private var previousPeriodStats: [DayStat] {
        if selectedRange == 0 {
            return statisticsService.previousWeekStats
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let prevEnd = calendar.date(byAdding: .day, value: -30, to: today),
              let prevStart = calendar.date(byAdding: .day, value: -29, to: prevEnd) else {
            return []
        }
        return statisticsService.buildStats(
            snapshots: snapshots,
            entries: allEntries,
            profile: profiles.first,
            startDate: prevStart,
            endDate: prevEnd
        )
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky header
                HStack {
                    Text(L.statistics.localized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation {
                            scrollProxy?.scrollTo("top", anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Theme.gradientTop.opacity(0.95))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            Color.clear.frame(height: 0).id("top")

                            // Custom segmented picker
                            customSegmentedPicker

                            if selectedRange == 2 {
                                // Program view
                                if let profile = profiles.first {
                                    ProgramSummaryView(
                                        summary: statisticsService.programData(
                                            profile: profile,
                                            snapshots: snapshots,
                                            entries: allEntries
                                        ),
                                        targetProtein: goalEngine.proteinTarget,
                                        targetCarbs: goalEngine.carbTarget,
                                        targetFat: goalEngine.fatTarget,
                                        realWeightDate: goalEngine.latestWeightDate,
                                        coachStyle: profile.coachStyle,
                                        personalContext: profile.fullAIContext
                                    )
                                }
                            } else {
                                if selectedRange == 1 && !monthlyHasEnoughData {
                                    Text("monthly_min_data".localized)
                                        .font(Theme.bodyFont)
                                        .foregroundStyle(Theme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 4)
                                }

                                // Summary cards
                                summaryCards

                                // Charts
                                CalorieChartView(stats: currentStats)

                                DeficitChartView(
                                    stats: currentStats,
                                    goalDays: profiles.first?.goalDays ?? 90,
                                    totalNeededDeficit: totalNeededDeficit
                                )

                                MacroChartView(
                                    avgProtein: statisticsService.weeklyAverageProtein,
                                    avgCarbs: statisticsService.weeklyAverageCarbs,
                                    avgFat: statisticsService.weeklyAverageFat,
                                    targetProtein: goalEngine.proteinTarget,
                                    targetCarbs: goalEngine.carbTarget,
                                    targetFat: goalEngine.fatTarget,
                                    todayProtein: todayEntries.reduce(0.0) { $0 + $1.protein },
                                    todayCarbs: todayEntries.reduce(0.0) { $0 + $1.carbs },
                                    todayFat: todayEntries.reduce(0.0) { $0 + $1.fat }
                                )

                                ActivityChartView(stats: currentStats)

                                MealInsightsCard(
                                    entries: periodEntries,
                                    appLanguage: groqService.appLanguage
                                )
                                .environmentObject(themeManager)

                                ConsistencyCard(
                                    stats: currentStats,
                                    previousStats: previousPeriodStats,
                                    appLanguage: groqService.appLanguage
                                )
                                .environmentObject(themeManager)

                                ProteinTrackingCard(
                                    stats: currentStats,
                                    proteinTarget: Double(goalEngine.proteinTarget),
                                    appLanguage: groqService.appLanguage
                                )
                                .environmentObject(themeManager)

                                BestDayCard(
                                    stats: currentStats,
                                    appLanguage: groqService.appLanguage
                                )
                                .environmentObject(themeManager)

                                // Weekly Groq insight
                                weeklyInsightCard
                            }

                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .onAppear { scrollProxy = proxy }
                }
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                let rangeLabel = selectedRange == 0 ? "weekly" : selectedRange == 1 ? "monthly" : "program"
                FeedbackService.shared.addLog("Statistics tab opened: \(rangeLabel)")
            }
            refreshStats()
        }
        .onChange(of: snapshots.count) {
            refreshStats()
        }
        .task {
            await loadWeeklyInsight()
        }
    }

    // MARK: - Custom Segmented Picker

    private var customSegmentedPicker: some View {
        let labels = [L.weekly.localized, L.monthly.localized, L.program.localized]
        return HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = i
                    }
                } label: {
                    Text(labels[i])
                        .font(.subheadline.weight(selectedRange == i ? .semibold : .regular))
                        .foregroundStyle(selectedRange == i ? Color.white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedRange == i
                                ? AnyView(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                                : AnyView(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var trendEmoji: String {
        switch statisticsService.trend {
        case .losing: return "\u{1F4C9}"
        case .gaining: return "\u{1F4C8}"
        case .stable: return "\u{2796}"
        }
    }

    private var trendIcon: String {
        switch statisticsService.trend {
        case .losing: return "arrow.down.right"
        case .gaining: return "arrow.up.right"
        case .stable: return "minus"
        }
    }

    private var trendColor: Color {
        switch statisticsService.trend {
        case .losing: return Theme.green
        case .gaining: return Theme.orange
        case .stable: return Theme.textSecondary
        }
    }

    private var totalNeededDeficit: Double {
        guard let p = profiles.first, p.goalDays > 0 else { return 0 }
        return (p.currentWeightKg - p.goalWeightKg) * 7700
    }

    private func refreshStats() {
        statisticsService.refresh(
            snapshots: snapshots,
            entries: allEntries,
            profile: profiles.first
        )
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        VStack(spacing: 12) {
            // Top row: Streak + Trend side by side
            HStack(spacing: 12) {
                MetricSummaryCard(
                    icon: "flame.fill",
                    iconColor: Theme.orange,
                    title: L.streak.localized,
                    value: "\(statisticsService.currentStreak)",
                    subtitle: L.daysLabelShort.localized,
                    detail: statisticsService.bestStreak > 0
                        ? String(format: L.bestFormat.localized, statisticsService.bestStreak)
                        : ""
                )

                let avgDef = statisticsService.last3DaysAvgDeficit
                MetricSummaryCard(
                    icon: trendIcon,
                    iconColor: trendColor,
                    title: L.trend.localized,
                    value: avgDef != 0 ? "\(abs(avgDef))" : "—",
                    subtitle: "kcal",
                    detail: statisticsService.trend.localized + " " + trendEmoji
                )
            }

            // Weight estimate card (full width)
            weightEstimateCard
        }
    }

    private var weightEstimateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text(L.weightEstimate.localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 0) {
                let weekKg = statisticsService.estimatedWeightLostWeekKg
                let weekDays = statisticsService.completedDaysThisWeek
                VStack(spacing: 4) {
                    Text("weekly".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(weekKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(weekKg)))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(weekKg >= 0 ? Theme.green : Theme.orange)
                        Text("kg")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(String(format: "%d " + "days_label".localized, weekDays))
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Theme.cardBorder)
                    .frame(width: 1, height: 40)

                let monthKg = statisticsService.estimatedWeightLostMonthKg
                let monthDays = statisticsService.completedDaysThisMonth
                VStack(spacing: 4) {
                    Text("monthly".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(monthKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(monthKg)))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(monthKg >= 0 ? Theme.green : Theme.orange)
                        Text("kg")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(String(format: "%d " + "days_label".localized, monthDays))
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Weekly Insight

    private var weeklyInsightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                Text(L.weeklyInsight.localized)
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
                .padding(.vertical, 16)
            } else if let insight = weeklyInsight {
                Text(insight)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if let cached = cachedInsightDate {
                    Text(cached.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                Text("not_enough_data".localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textTertiary)
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

    private var cachedInsightDate: Date? {
        UserDefaults.standard.object(forKey: "weeklyInsightDate") as? Date
    }

    private func loadWeeklyInsight() async {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)

        let withData = statisticsService.weeklyStats.filter { $0.hasData }
        guard withData.count >= 3 else { return }

        let fingerprint = "\(withData.count)_\(statisticsService.totalDeficitThisWeek)_\(statisticsService.averageCaloriesThisWeek)"
        let cacheKey = "weeklyInsight_\(year)_\(weekOfYear)_\(groqService.appLanguage)_\(fingerprint)"

        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            weeklyInsight = cached
            return
        }

        insightLoading = true
        do {
            let insight = try await groqService.generateWeeklyInsight(
                stats: statisticsService.weeklyStats,
                streak: statisticsService.currentStreak,
                trend: statisticsService.trend,
                avgCalories: statisticsService.averageCaloriesThisWeek,
                avgProtein: statisticsService.averageProteinThisWeek,
                totalDeficit: statisticsService.totalDeficitThisWeek,
                targetDeficit: Int(goalEngine.deficit),
                currentWeight: profiles.first?.currentWeightKg ?? 0,
                goalWeight: profiles.first?.goalWeightKg ?? 0,
                previousWeekAvgCalories: statisticsService.previousWeekAvgCalories,
                previousWeekTotalDeficit: statisticsService.previousWeekTotalDeficit,
                previousWeekDaysWithData: statisticsService.previousWeekDaysWithData,
                coachStyle: profiles.first?.coachStyle ?? .supportive,
                personalContext: profiles.first?.fullAIContext ?? ""
            )
            weeklyInsight = insight
            UserDefaults.standard.set(insight, forKey: cacheKey)
            UserDefaults.standard.set(Date.now, forKey: "weeklyInsightDate")
        } catch {
            FeedbackService.shared.addErrorLog("WeeklyInsight: \(error.localizedDescription)")
        }
        insightLoading = false
    }
}

// MARK: - Metric Summary Card

struct MetricSummaryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(detail)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    StatisticsView()
        .environment(GoalEngine())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
