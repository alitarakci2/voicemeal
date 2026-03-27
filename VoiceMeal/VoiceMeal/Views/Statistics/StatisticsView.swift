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

    @State private var statisticsService = StatisticsService()
    @State private var selectedRange = 0 // 0 = weekly, 1 = monthly, 2 = program
    @State private var weeklyInsight: String?
    @State private var insightLoading = false

    @Environment(GroqService.self) private var groqService

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented control
                    Picker("range".localized, selection: $selectedRange) {
                        Text(L.weekly.localized).tag(0)
                        Text(L.monthly.localized).tag(1)
                        Text(L.program.localized).tag(2)
                    }
                    .pickerStyle(.segmented)

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
                                coachStyle: profile.coachStyle
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

                        // Weekly Groq insight
                        weeklyInsightCard
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle(L.statistics.localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshStats()
            }
            .onChange(of: snapshots.count) {
                refreshStats()
            }
            .task {
                await loadWeeklyInsight()
            }
        }
    }

    private var trendEmoji: String {
        switch statisticsService.trend {
        case .losing: return "\u{1F4C9}"
        case .gaining: return "\u{1F4C8}"
        case .stable: return "\u{2796}"
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
                // Streak
                VStack(spacing: 8) {
                    Text("\u{1F525}")
                        .font(.system(size: 28))
                    Text("\(statisticsService.currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("current_streak".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textSecondary)
                    if statisticsService.bestStreak > 0 {
                        Text(String(format: "best_streak_days_format".localized, statisticsService.bestStreak))
                            .font(Theme.microFont)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Trend
                VStack(spacing: 8) {
                    Text(trendEmoji)
                        .font(.system(size: 28))
                    Text(statisticsService.trend.localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    let avgDef = statisticsService.last3DaysAvgDeficit
                    if avgDef != 0 {
                        Text("\(abs(avgDef)) kcal")
                            .font(Theme.captionFont)
                            .foregroundStyle(avgDef > 0 ? Theme.green : Theme.red)
                    }
                    Text("avg_label".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            // Weight estimate card
            VStack(spacing: 12) {
                HStack {
                    Text("\u{2696}\u{FE0F} \("weight_estimate".localized)")
                        .font(Theme.headlineFont)
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
                        Text("\(weekKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(weekKg))) kg")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(weekKg >= 0 ? Theme.green : Theme.orange)
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
                        Text("\(monthKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(monthKg))) kg")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(monthKg >= 0 ? Theme.green : Theme.orange)
                        Text(String(format: "%d " + "days_label".localized, monthDays))
                            .font(Theme.microFont)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Weekly Insight

    private var weeklyInsightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\u{1F9E0} \("weekly_insight".localized)")
                .font(Theme.headlineFont)
                .foregroundStyle(.white)

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
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var cachedInsightDate: Date? {
        UserDefaults.standard.object(forKey: "weeklyInsightDate") as? Date
    }

    private func loadWeeklyInsight() async {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)
        let cacheKey = "weeklyInsight_\(year)_\(weekOfYear)_\(groqService.appLanguage)"

        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            weeklyInsight = cached
            return
        }

        let withData = statisticsService.weeklyStats.filter { $0.hasData }
        guard withData.count >= 3 else { return }

        insightLoading = true
        do {
            let insight = try await groqService.generateWeeklyInsight(
                stats: statisticsService.weeklyStats,
                streak: statisticsService.currentStreak,
                trend: statisticsService.trend,
                avgCalories: statisticsService.averageCaloriesThisWeek,
                avgProtein: statisticsService.averageProteinThisWeek,
                totalDeficit: statisticsService.totalDeficitThisWeek,
                currentWeight: profiles.first?.currentWeightKg ?? 0,
                goalWeight: profiles.first?.goalWeightKg ?? 0,
                coachStyle: profiles.first?.coachStyle ?? .supportive
            )
            weeklyInsight = insight
            UserDefaults.standard.set(insight, forKey: cacheKey)
            UserDefaults.standard.set(Date.now, forKey: "weeklyInsightDate")
        } catch {
            // Weekly insight error
        }
        insightLoading = false
    }
}

#Preview {
    StatisticsView()
        .environment(GoalEngine())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
