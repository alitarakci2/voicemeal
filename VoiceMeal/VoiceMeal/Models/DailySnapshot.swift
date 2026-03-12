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
    var savedAt: Date

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
        weightKg: Double
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
        self.savedAt = .now
    }
}
