//
//  StatisticsService.swift
//  VoiceMeal
//

import Foundation
import SwiftData

struct DayStat: Identifiable {
    var id: Date { date }
    let date: Date
    let consumedCalories: Int
    let targetCalories: Int
    let tdee: Int
    let deficit: Int          // real deficit: tdee - consumed
    let eatingGoalDiff: Int   // target - consumed (how far from eating goal)
    let cumulativeDeficit: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let activities: [String]
    let hasData: Bool
    let hasSnapshot: Bool
}

enum TrendDirection: String {
    case losing = "Kilo Veriyor"
    case gaining = "Kilo Al\u{0131}yor"
    case stable = "Stabil"
}

enum GoalDirection {
    case losing
    case gaining
    case maintenance
}

struct ProgramSummary {
    let startDate: Date
    let totalDays: Int
    let daysWithData: Int
    let adherencePercent: Int

    let totalConsumedCalories: Int
    let totalTargetCalories: Int
    let totalDeficitKcal: Int
    let estimatedWeightChangeKg: Double

    let avgDailyCalories: Int
    let avgDailyProtein: Double
    let avgDailyCarbs: Double
    let avgDailyFat: Double

    let avgDailyDeficit: Int
    let bestDay: (date: Date, value: Int)?
    let worstDay: (date: Date, value: Int)?

    let currentStreak: Int
    let bestStreak: Int
    let totalWorkoutDays: Int
    let mostCommonActivity: String

    let onTrack: Bool
    let onTrackLevel: Int // 0=behind, 1=near, 2=ahead
    let progressPercent: Int
    let daysRemaining: Int
    let goalDirection: GoalDirection

    let startWeight: Double
    let currentWeight: Double
    let goalWeight: Double
    let expectedChangeByNow: Double
}

@Observable
class StatisticsService {

    private static var localCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }

    private(set) var weeklyStats: [DayStat] = []
    private(set) var monthlyStats: [DayStat] = []

    func refresh(snapshots: [DailySnapshot], entries: [FoodEntry], profile: UserProfile?) {
        weeklyStats = buildStats(snapshots: snapshots, entries: entries, profile: profile, days: 7)
        monthlyStats = buildStats(snapshots: snapshots, entries: entries, profile: profile, days: 30)
    }

    private func buildStats(snapshots: [DailySnapshot], entries: [FoodEntry], profile: UserProfile?, days: Int) -> [DayStat] {
        let calendar = Self.localCalendar
        let today = calendar.startOfDay(for: .now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let snapshotsByDay = Dictionary(grouping: snapshots) { calendar.startOfDay(for: $0.date) }
        let entriesByDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }

        var stats: [DayStat] = []
        var cumulative = 0
        var current = startDate

        while current <= today {
            let snapshot = snapshotsByDay[current]?.first
            let dayEntries = entriesByDay[current] ?? []
            let hasData = !dayEntries.isEmpty || snapshot != nil

            let consumed = snapshot?.consumedCalories ?? dayEntries.reduce(0) { $0 + $1.calories }
            let target = snapshot?.dailyCalorieTarget ?? calculateTargetForDate(current, profile: profile)
            let dayTDEE = snapshot != nil ? Int(snapshot!.tdee) : calculateTDEEForDate(current, profile: profile)
            let deficit = hasData && dayTDEE > 0 ? dayTDEE - consumed : 0  // real deficit, only for days with data
            let eatingGoalDiff = hasData && target > 0 ? target - consumed : 0
            if hasData { cumulative += deficit }

            let protein = snapshot?.consumedProtein ?? dayEntries.reduce(0.0) { $0 + $1.protein }
            let carbs = snapshot?.consumedCarbs ?? dayEntries.reduce(0.0) { $0 + $1.carbs }
            let fat = snapshot?.consumedFat ?? dayEntries.reduce(0.0) { $0 + $1.fat }

            // Derive activities from weekday + profile schedule
            var activities: [String] = ["rest"]
            if let p = profile {
                let weekday = calendar.component(.weekday, from: current)
                let index: Int
                switch weekday {
                case 1: index = 6
                case 2: index = 0
                case 3: index = 1
                case 4: index = 2
                case 5: index = 3
                case 6: index = 4
                case 7: index = 5
                default: index = 0
                }
                let schedule = p.weeklySchedule
                if schedule.count == 7 {
                    let dayActivities = schedule[index]
                    activities = dayActivities.isEmpty ? ["rest"] : dayActivities
                }
            }

            stats.append(DayStat(
                date: current,
                consumedCalories: consumed,
                targetCalories: target,
                tdee: dayTDEE,
                deficit: deficit,
                eatingGoalDiff: eatingGoalDiff,
                cumulativeDeficit: cumulative,
                protein: protein,
                carbs: carbs,
                fat: fat,
                activities: activities,
                hasData: hasData,
                hasSnapshot: snapshot != nil
            ))

            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return stats
    }

    // MARK: - Summary Properties

    var totalDeficitThisWeek: Int {
        weeklyStats.filter { $0.hasData }.reduce(0) { $0 + $1.deficit }
    }

    var totalDeficitThisMonth: Int {
        monthlyStats.filter { $0.hasData }.reduce(0) { $0 + $1.deficit }
    }

    var estimatedWeightLostWeekKg: Double {
        Double(totalDeficitThisWeek) / 7700.0
    }

    var estimatedWeightLostMonthKg: Double {
        Double(totalDeficitThisMonth) / 7700.0
    }

    var averageCaloriesThisWeek: Int {
        let withData = weeklyStats.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + $1.consumedCalories } / withData.count
    }

    var averageProteinThisWeek: Double {
        let withData = weeklyStats.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0.0) { $0 + $1.protein } / Double(withData.count)
    }

    var currentStreak: Int {
        let calendar = Self.localCalendar
        let todayStart = calendar.startOfDay(for: .now)
        var streak = 0
        for stat in weeklyStats.reversed() {
            if calendar.startOfDay(for: stat.date) == todayStart { continue }
            guard stat.hasData, stat.targetCalories > 0 else { break }
            let ratio = Double(stat.consumedCalories) / Double(stat.targetCalories)
            if ratio >= 0.9 && ratio <= 1.1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var bestStreak: Int {
        var best = 0
        var current = 0
        for stat in monthlyStats {
            guard stat.hasData, stat.targetCalories > 0 else {
                current = 0
                continue
            }
            let ratio = Double(stat.consumedCalories) / Double(stat.targetCalories)
            if ratio >= 0.9 && ratio <= 1.1 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    var mostCommonActivity: String {
        var counts: [String: Int] = [:]
        for stat in monthlyStats {
            for activity in stat.activities where activity != "rest" {
                counts[activity, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "rest"
    }

    var activityCounts: [(activity: String, count: Int)] {
        var counts: [String: Int] = [:]
        for stat in monthlyStats {
            for activity in stat.activities {
                counts[activity, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (activity: $0.key, count: $0.value) }
    }

    var trend: TrendDirection {
        let last3 = weeklyStats.suffix(3).filter { $0.hasData }
        guard !last3.isEmpty else { return .stable }
        let avgDeficit = Double(last3.reduce(0) { $0 + $1.deficit }) / Double(last3.count)
        if avgDeficit > 100 { return .losing }
        if avgDeficit < -100 { return .gaining }
        return .stable
    }

    var last3DaysAvgDeficit: Int {
        let last3 = weeklyStats.suffix(3).filter { $0.hasData }
        guard !last3.isEmpty else { return 0 }
        return last3.reduce(0) { $0 + $1.deficit } / last3.count
    }

    var weeklyAverageProtein: Double { averageProteinThisWeek }

    var weeklyAverageCarbs: Double {
        let withData = weeklyStats.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0.0) { $0 + $1.carbs } / Double(withData.count)
    }

    var weeklyAverageFat: Double {
        let withData = weeklyStats.filter { $0.hasData }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0.0) { $0 + $1.fat } / Double(withData.count)
    }

    // MARK: - Program Data

    static func goalDirection(profile: UserProfile) -> GoalDirection {
        let start = profile.programStartWeightKg > 0 ? profile.programStartWeightKg : profile.currentWeightKg
        if profile.goalWeightKg > start {
            return .gaining
        } else if profile.goalWeightKg < start {
            return .losing
        } else {
            return .maintenance
        }
    }

    func programData(profile: UserProfile, snapshots: [DailySnapshot], entries: [FoodEntry]) -> ProgramSummary {
        let calendar = Self.localCalendar
        let startDate = calendar.startOfDay(for: profile.createdAt)
        let today = calendar.startOfDay(for: .now)
        let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: today).day! + 1)

        // Determine start weight from earliest snapshot or profile
        let earliestSnapshot = snapshots
            .filter { $0.date >= startDate && $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
            .first
        let programStart = earliestSnapshot?.weightKg
            ?? (profile.programStartWeightKg > 0 ? profile.programStartWeightKg : profile.currentWeightKg)

        // Derive direction from program start weight, not current weight
        let direction: GoalDirection
        if profile.goalWeightKg > programStart {
            direction = .gaining
        } else if profile.goalWeightKg < programStart {
            direction = .losing
        } else {
            direction = .maintenance
        }

        // Build all stats from program start
        let allStats = buildStats(snapshots: snapshots, entries: entries, profile: profile, days: totalDays)
        let withData = allStats.filter { $0.hasData }
        let daysWithData = withData.count
        let adherence = totalDays > 0 ? (daysWithData * 100) / totalDays : 0

        let totalConsumed = withData.reduce(0) { $0 + $1.consumedCalories }
        let totalTarget = withData.reduce(0) { $0 + $1.targetCalories }
        let totalDeficit = withData.reduce(0) { $0 + $1.deficit }
        let estimatedChange = Double(totalDeficit) / 7700.0

        let avgCalories = daysWithData > 0 ? totalConsumed / daysWithData : 0
        let avgProtein = daysWithData > 0 ? withData.reduce(0.0) { $0 + $1.protein } / Double(daysWithData) : 0
        let avgCarbs = daysWithData > 0 ? withData.reduce(0.0) { $0 + $1.carbs } / Double(daysWithData) : 0
        let avgFat = daysWithData > 0 ? withData.reduce(0.0) { $0 + $1.fat } / Double(daysWithData) : 0
        let avgDeficit = daysWithData > 0 ? totalDeficit / daysWithData : 0

        // Best/worst day depends on goal direction
        let bestDay: (date: Date, value: Int)?
        let worstDay: (date: Date, value: Int)?

        switch direction {
        case .losing:
            // Best = highest deficit, worst = most over target (lowest deficit / highest surplus)
            if let best = withData.max(by: { $0.deficit < $1.deficit }) {
                bestDay = (best.date, best.deficit)
            } else { bestDay = nil }
            if let worst = withData.min(by: { $0.deficit < $1.deficit }) {
                worstDay = (worst.date, worst.deficit)
            } else { worstDay = nil }
        case .gaining:
            // Best = most surplus (most negative deficit), worst = most deficit
            if let best = withData.min(by: { $0.deficit < $1.deficit }) {
                bestDay = (best.date, -best.deficit)
            } else { bestDay = nil }
            if let worst = withData.max(by: { $0.deficit < $1.deficit }) {
                worstDay = (worst.date, -worst.deficit)
            } else { worstDay = nil }
        case .maintenance:
            // Best = closest to target, worst = furthest
            if let best = withData.min(by: { abs($0.deficit) < abs($1.deficit) }) {
                bestDay = (best.date, abs(best.deficit))
            } else { bestDay = nil }
            if let worst = withData.max(by: { abs($0.deficit) < abs($1.deficit) }) {
                worstDay = (worst.date, abs(worst.deficit))
            } else { worstDay = nil }
        }

        // Streaks — skip today (still in progress)
        let todayStart = calendar.startOfDay(for: .now)
        var currentStrk = 0
        for stat in allStats.reversed() {
            if calendar.startOfDay(for: stat.date) == todayStart { continue }
            guard stat.hasData, stat.targetCalories > 0 else { break }
            let ratio = Double(stat.consumedCalories) / Double(stat.targetCalories)
            if ratio >= 0.9 && ratio <= 1.1 { currentStrk += 1 } else { break }
        }
        var bestStrk = 0
        var runStrk = 0
        for stat in allStats {
            guard stat.hasData, stat.targetCalories > 0 else { runStrk = 0; continue }
            let ratio = Double(stat.consumedCalories) / Double(stat.targetCalories)
            if ratio >= 0.9 && ratio <= 1.1 {
                runStrk += 1
                bestStrk = max(bestStrk, runStrk)
            } else { runStrk = 0 }
        }

        // Workout days + most common activity
        let workoutDays = allStats.filter { $0.hasData && $0.activities != ["rest"] }.count
        var actCounts: [String: Int] = [:]
        for stat in allStats where stat.hasData {
            for a in stat.activities where a != "rest" { actCounts[a, default: 0] += 1 }
        }
        let mostCommon = actCounts.max(by: { $0.value < $1.value })?.key ?? "rest"

        // Use real weight (from HealthKit/profile) if it differs from start, else estimated
        let realWeight = profile.currentWeightKg
        let estimatedCurrentWeight = programStart - estimatedChange
        let effectiveCurrentWeight = (realWeight > 0 && abs(realWeight - programStart) > 0.01)
            ? realWeight : estimatedCurrentWeight

        // On track — use effective weight with 85% tolerance
        let totalToChange = programStart - profile.goalWeightKg
        let actualLost = programStart - effectiveCurrentWeight
        let expectedByNow = (Double(totalDays) / Double(max(1, profile.goalDays))) * abs(totalToChange)
        let onTrack: Bool
        let onTrackLevel: Int
        switch direction {
        case .losing:
            onTrack = actualLost >= expectedByNow * 0.85
            if actualLost >= expectedByNow * 1.10 {
                onTrackLevel = 2 // ahead
            } else if actualLost >= expectedByNow * 0.85 {
                onTrackLevel = 1 // near
            } else {
                onTrackLevel = 0 // behind
            }
        case .gaining:
            let actualGained = effectiveCurrentWeight - programStart
            onTrack = actualGained >= expectedByNow * 0.85
            if actualGained >= expectedByNow * 1.10 {
                onTrackLevel = 2
            } else if actualGained >= expectedByNow * 0.85 {
                onTrackLevel = 1
            } else {
                onTrackLevel = 0
            }
        case .maintenance:
            onTrack = abs(actualLost) < 0.5
            onTrackLevel = onTrack ? 1 : 0
        }

        // Progress percent — based on effective weight
        let progressPercent: Int
        if abs(totalToChange) < 0.01 {
            progressPercent = 100
        } else {
            progressPercent = min(100, max(0, Int((abs(actualLost) / abs(totalToChange)) * 100)))
        }

        let daysRemaining = max(0, profile.goalDays - totalDays)

        return ProgramSummary(
            startDate: startDate,
            totalDays: totalDays,
            daysWithData: daysWithData,
            adherencePercent: adherence,
            totalConsumedCalories: totalConsumed,
            totalTargetCalories: totalTarget,
            totalDeficitKcal: totalDeficit,
            estimatedWeightChangeKg: estimatedChange,
            avgDailyCalories: avgCalories,
            avgDailyProtein: avgProtein,
            avgDailyCarbs: avgCarbs,
            avgDailyFat: avgFat,
            avgDailyDeficit: avgDeficit,
            bestDay: bestDay,
            worstDay: worstDay,
            currentStreak: currentStrk,
            bestStreak: bestStrk,
            totalWorkoutDays: workoutDays,
            mostCommonActivity: mostCommon,
            onTrack: onTrack,
            onTrackLevel: onTrackLevel,
            progressPercent: progressPercent,
            daysRemaining: daysRemaining,
            goalDirection: direction,
            startWeight: programStart,
            currentWeight: profile.currentWeightKg, // best approximation
            goalWeight: profile.goalWeightKg,
            expectedChangeByNow: expectedByNow
        )
    }

    // MARK: - TDEE & Target Fallback

    private func calculateTDEEForDate(_ date: Date, profile: UserProfile?) -> Int {
        guard let p = profile else { return 0 }

        // BMR (Mifflin-St Jeor)
        let bmr: Double
        if p.gender == "male" {
            bmr = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) + 5
        } else {
            bmr = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) - 161
        }

        // Activity multiplier from schedule
        let calendar = Self.localCalendar
        let weekday = calendar.component(.weekday, from: date)
        let index: Int
        switch weekday {
        case 1: index = 6
        case 2: index = 0
        case 3: index = 1
        case 4: index = 2
        case 5: index = 3
        case 6: index = 4
        case 7: index = 5
        default: index = 0
        }

        let schedule = p.weeklySchedule
        var activities = ["rest"]
        if schedule.count == 7 {
            let dayActivities = schedule[index]
            activities = dayActivities.isEmpty ? ["rest"] : dayActivities
        }

        let multipliers: [String: Double] = [
            "walking": 1.375,
            "weights": 1.55,
            "cycling": 1.55,
            "running": 1.725,
        ]

        let activityMultiplier: Double
        if activities == ["rest"] {
            activityMultiplier = 1.2
        } else {
            let highest = activities.compactMap { multipliers[$0] }.max() ?? 1.2
            let bonus = activities.filter({ $0 != "rest" }).count > 1 ? 0.1 : 0.0
            activityMultiplier = highest + bonus
        }

        return Int(bmr * activityMultiplier)
    }

    private func calculateTargetForDate(_ date: Date, profile: UserProfile?) -> Int {
        guard let p = profile else { return 0 }

        let tdee = Double(calculateTDEEForDate(date, profile: p))

        // BMR for minimum target
        let bmr: Double
        if p.gender == "male" {
            bmr = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) + 5
        } else {
            bmr = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) - 161
        }

        // Deficit (same formula as GoalEngine)
        guard p.goalDays > 0 else { return Int(tdee) }
        let weightDiff = p.currentWeightKg - p.goalWeightKg
        let rawDeficit = (weightDiff * 7700) / Double(p.goalDays)
        let maxDeficit = tdee * 0.35
        let maxSurplus = tdee * 0.20
        let cappedDeficit = max(-maxSurplus, min(maxDeficit, rawDeficit))

        let raw = tdee - cappedDeficit
        let minimumTarget = bmr * 0.85
        if cappedDeficit > 0 {
            return Int(max(raw, minimumTarget))
        }
        return Int(raw)
    }
}
