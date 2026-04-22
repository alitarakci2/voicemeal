//
//  DailySnapshot.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class DailySnapshot {
    var id: UUID
    var date: Date
    var tdee: Double
    var dailyCalorieTarget: Int
    var proteinTarget: Int
    var carbTarget: Int
    var fatTarget: Int
    var consumedCalories: Int
    var consumedProtein: Double
    var consumedCarbs: Double
    var consumedFat: Double
    var usedHealthKit: Bool
    var weightKg: Double
    var sleepMinutes: Int?
    var deepSleepMinutes: Int?
    var sleepQuality: String?
    var todayHRV: Double?
    var hrvBaseline: Double?
    var hrvStatus: String?
    var dailyInsight: String?
    var insightGeneratedAt: Date?
    var targetDeficit: Int = 0
    var actualDeficitAtClose: Int = 0
    var totalWaterMl: Int = 0
    var waterGoalMl: Int = 0
    var morningTDEE: Double = 0
    var insightGeneratedWithTarget: Int = 0
    var trackingModeRaw: String = TrackingMode.goal.rawValue
    var savedAt: Date

    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .goal }
        set { trackingModeRaw = newValue.rawValue }
    }

    init(
        date: Date,
        tdee: Double,
        dailyCalorieTarget: Int,
        proteinTarget: Int,
        carbTarget: Int,
        fatTarget: Int,
        consumedCalories: Int,
        consumedProtein: Double,
        consumedCarbs: Double,
        consumedFat: Double,
        usedHealthKit: Bool,
        weightKg: Double,
        sleepMinutes: Int? = nil,
        deepSleepMinutes: Int? = nil,
        sleepQuality: String? = nil,
        todayHRV: Double? = nil,
        hrvBaseline: Double? = nil,
        hrvStatus: String? = nil,
        dailyInsight: String? = nil,
        insightGeneratedAt: Date? = nil,
        targetDeficit: Int = 0,
        actualDeficitAtClose: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.tdee = tdee
        self.dailyCalorieTarget = dailyCalorieTarget
        self.proteinTarget = proteinTarget
        self.carbTarget = carbTarget
        self.fatTarget = fatTarget
        self.consumedCalories = consumedCalories
        self.consumedProtein = consumedProtein
        self.consumedCarbs = consumedCarbs
        self.consumedFat = consumedFat
        self.usedHealthKit = usedHealthKit
        self.weightKg = weightKg
        self.sleepMinutes = sleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.sleepQuality = sleepQuality
        self.todayHRV = todayHRV
        self.hrvBaseline = hrvBaseline
        self.hrvStatus = hrvStatus
        self.dailyInsight = dailyInsight
        self.insightGeneratedAt = insightGeneratedAt
        self.targetDeficit = targetDeficit
        self.actualDeficitAtClose = actualDeficitAtClose
        self.savedAt = .now
    }
}
