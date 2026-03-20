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
                    Picker("Aral\u{0131}k", selection: $selectedRange) {
                        Text("Haftal\u{0131}k").tag(0)
                        Text("Ayl\u{0131}k").tag(1)
                        Text("Program").tag(2)
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
                                realWeightDate: goalEngine.latestWeightDate
                            )
                        }
                    } else {
                        if selectedRange == 1 && !monthlyHasEnoughData {
                            Text("Ayl\u{0131}k grafik i\u{00E7}in en az 2 hafta veri gerekli")
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
            .background(Theme.background)
            .navigationTitle("\u{0130}statistik")
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
            // Streak card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let streak = statisticsService.currentStreak
                    Text("\u{1F525} \(streak) G\u{00FC}nl\u{00FC}k Seri")
                        .font(Theme.headlineFont)
                    if streak > 0 {
                        Text("Hedefe ula\u{015F}\u{0131}yorsun, devam et!")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Bug\u{00FC}n hedefe ula\u{015F}arak ba\u{015F}la!")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if statisticsService.bestStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("En iyi")
                            .font(Theme.microFont)
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(statisticsService.bestStreak) g\u{00FC}n")
                            .font(Theme.bodyFont)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .themeCard()

            // Estimated weight card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{2696}\u{FE0F} Tahmini Kilo De\u{011F}i\u{015F}imi")
                        .font(Theme.headlineFont)
                    let weekKg = statisticsService.estimatedWeightLostWeekKg
                    Text("Bu hafta: \(weekKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(weekKg))) kg (ger\u{00E7}ek a\u{00E7}\u{0131}k)")
                        .font(Theme.bodyFont)
                    let monthKg = statisticsService.estimatedWeightLostMonthKg
                    Text("Bu ay: \(monthKg >= 0 ? "-" : "+")\(String(format: "%.2f", abs(monthKg))) kg (ger\u{00E7}ek a\u{00E7}\u{0131}k)")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding()
            .themeCard()

            // Trend card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trendEmoji) Trend: \(statisticsService.trend.rawValue)")
                        .font(Theme.headlineFont)
                    let avgDef = statisticsService.last3DaysAvgDeficit
                    let dayCount = statisticsService.last3ValidDayCount
                    if avgDef != 0 && dayCount > 0 {
                        Text("Son \(dayCount) g\u{00FC}nde ortalama \(abs(avgDef)) kcal \(avgDef > 0 ? "a\u{00E7}\u{0131}k" : "fazla")")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding()
            .themeCard()
        }
    }

    // MARK: - Weekly Insight

    private var weeklyInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\u{1F9E0} Haftal\u{0131}k De\u{011F}erlendirme")
                .font(Theme.headlineFont)

            if insightLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if let insight = weeklyInsight {
                Text(insight)
                    .font(Theme.bodyFont)
                    .fixedSize(horizontal: false, vertical: true)

                if let cached = cachedInsightDate {
                    Text(cached.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text("Hen\u{00FC}z yeterli veri yok")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .themeCard()
    }

    private var cachedInsightDate: Date? {
        UserDefaults.standard.object(forKey: "weeklyInsightDate") as? Date
    }

    private func loadWeeklyInsight() async {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: .now)
        let year = calendar.component(.yearForWeekOfYear, from: .now)
        let cacheKey = "weeklyInsight_\(year)_\(weekOfYear)"

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
                goalWeight: profiles.first?.goalWeightKg ?? 0
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
