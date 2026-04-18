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
            // Only update consumed values — target values were set when the day started
            snapshot.consumedCalories = consumedCalories
            snapshot.consumedProtein = consumedProtein
            snapshot.consumedCarbs = consumedCarbs
            snapshot.consumedFat = consumedFat
            snapshot.actualDeficitAtClose = Int(snapshot.tdee) - consumedCalories
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
            snapshot.morningTDEE = goalEngine.tdee
            snapshot.totalWaterMl = totalWaterMl
            snapshot.waterGoalMl = waterGoalMl
            modelContext.insert(snapshot)
        }
        FeedbackService.shared.addLog("Snapshot saved: \(consumedCalories) kcal")
    }

    static func fetchSnapshot(for date: Date, modelContext: ModelContext) -> DailySnapshot? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            FeedbackService.shared.addLog("Warning: date calculation returned nil")
            return nil
        }

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
