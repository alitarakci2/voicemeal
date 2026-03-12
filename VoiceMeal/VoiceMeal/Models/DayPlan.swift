//
//  DayPlan.swift
//  VoiceMeal
//

import Foundation

enum DayStatus {
    case completed   // 85%-110% of target
    case exceeded    // > 110% of target
    case underate    // < 85% of target
    case missed      // no food entries
    case today
    case planned
}

struct DayPlan: Identifiable {
    var id: Date { date }
    let date: Date
    let activities: [String]
    let tdee: Int
    let targetCalories: Int
    let targetProtein: Int
    let targetCarbs: Int
    let targetFat: Int
    let consumedCalories: Int
    let consumedProtein: Double
    let consumedCarbs: Double
    let consumedFat: Double
    let status: DayStatus

    var caloriePercentage: Int {
        guard targetCalories > 0 else { return 0 }
        return Int(round(Double(consumedCalories) / Double(targetCalories) * 100))
    }
}
