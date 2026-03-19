//
//  SnapshotService.swift
//  VoiceMeal
//

import Foundation
import SwiftData

struct SnapshotService {

    static func saveSnapshot(
        date: Date,
        goalEngine: GoalEngine,
        consumedCalories: Int,
        consumedProtein: Double,
        consumedCarbs: Double,
        consumedFat: Double,
        modelContext: ModelContext,
        totalWaterMl: Int = 0,
        waterGoalMl: Int = 0
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        let existing = fetchSnapshot(for: startOfDay, modelContext: modelContext)

        if let snapshot = existing {
            snapshot.tdee = goalEngine.tdee
            snapshot.dailyCalorieTarget = goalEngine.dailyCalorieTarget
            snapshot.proteinTarget = goalEngine.proteinTarget
            snapshot.carbTarget = goalEngine.carbTarget
            snapshot.fatTarget = goalEngine.fatTarget
            snapshot.consumedCalories = consumedCalories
            snapshot.consumedProtein = consumedProtein
            snapshot.consumedCarbs = consumedCarbs
            snapshot.consumedFat = consumedFat
            snapshot.usedHealthKit = goalEngine.usingHealthKit || goalEngine.isUsingExtrapolatedTDEE
            snapshot.weightKg = goalEngine.profile?.currentWeightKg ?? 0
            snapshot.targetDeficit = Int(goalEngine.cappedDailyDeficit)
            snapshot.actualDeficitAtClose = Int(goalEngine.tdee) - consumedCalories
            snapshot.totalWaterMl = totalWaterMl
            snapshot.waterGoalMl = waterGoalMl
            snapshot.savedAt = .now
        } else {
            let snapshot = DailySnapshot(
                date: startOfDay,
                tdee: goalEngine.tdee,
                dailyCalorieTarget: goalEngine.dailyCalorieTarget,
                proteinTarget: goalEngine.proteinTarget,
                carbTarget: goalEngine.carbTarget,
                fatTarget: goalEngine.fatTarget,
                consumedCalories: consumedCalories,
                consumedProtein: consumedProtein,
                consumedCarbs: consumedCarbs,
                consumedFat: consumedFat,
                usedHealthKit: goalEngine.usingHealthKit || goalEngine.isUsingExtrapolatedTDEE,
                weightKg: goalEngine.profile?.currentWeightKg ?? 0,
                targetDeficit: Int(goalEngine.cappedDailyDeficit),
                actualDeficitAtClose: Int(goalEngine.tdee) - consumedCalories
            )
            snapshot.totalWaterMl = totalWaterMl
            snapshot.waterGoalMl = waterGoalMl
            modelContext.insert(snapshot)
        }
    }

    static func fetchSnapshot(for date: Date, modelContext: ModelContext) -> DailySnapshot? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: #Predicate<DailySnapshot> { snapshot in
                snapshot.date >= startOfDay && snapshot.date < nextDay
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    static func snapshotNeedsUpdate(for date: Date, modelContext: ModelContext) -> Bool {
        guard let snapshot = fetchSnapshot(for: date, modelContext: modelContext) else {
            return true
        }
        return Date.now.timeIntervalSince(snapshot.savedAt) > 3600
    }
}
