//
//  GoalEngine.swift
//  VoiceMeal
//

import Foundation

@Observable
class GoalEngine {
    private(set) var profile: UserProfile?
    var healthKitBurn: Double = 0

    var healthKitSufficient: Bool {
        healthKitBurn > bmr && bmr > 0
    }

    var usingHealthKit: Bool {
        healthKitSufficient
    }

    var bmr: Double {
        guard let p = profile else { return 0 }
        if p.gender == "male" {
            return 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) + 5
        } else {
            return 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) - 161
        }
    }

    var todayActivityNames: [String] {
        guard let p = profile else { return ["rest"] }
        return todayActivities(for: p)
    }

    var activityMultiplier: Double {
        let activities = todayActivityNames

        if activities == ["rest"] {
            return 1.2
        }

        let multipliers: [String: Double] = [
            "walking": 1.375,
            "weights": 1.55,
            "cycling": 1.55,
            "running": 1.725,
        ]

        let highest = activities.compactMap { multipliers[$0] }.max() ?? 1.2
        let bonus = activities.filter({ $0 != "rest" }).count > 1 ? 0.1 : 0.0
        return highest + bonus
    }

    var calculatedTDEE: Double {
        bmr * activityMultiplier
    }

    var tdee: Double {
        usingHealthKit ? healthKitBurn : calculatedTDEE
    }

    var deficit: Double {
        guard let p = profile else { return 0 }
        switch p.intensityLevel {
        case ...0.3:
            return tdee * 0.10
        case 0.3...0.7:
            return tdee * 0.20
        default:
            return tdee * 0.28
        }
    }

    private var minimumCalorieTarget: Double {
        bmr * 0.85
    }

    var isCalorieClamped: Bool {
        let raw = tdee - deficit
        return raw < minimumCalorieTarget && minimumCalorieTarget > 0
    }

    var dailyCalorieTarget: Int {
        let raw = tdee - deficit
        return Int(max(raw, minimumCalorieTarget))
    }

    var proteinTarget: Int {
        guard let p = profile else { return 0 }
        return Int(2.0 * p.currentWeightKg)
    }

    var fatTarget: Int {
        Int(Double(dailyCalorieTarget) * 0.25 / 9.0)
    }

    var carbTarget: Int {
        let proteinCal = Double(proteinTarget) * 4.0
        let fatCal = Double(fatTarget) * 9.0
        let remaining = Double(dailyCalorieTarget) - proteinCal - fatCal
        return max(0, Int(remaining / 4.0))
    }

    var projectedWeeklyLossKg: Double {
        (deficit * 7) / 7700
    }

    func update(with profile: UserProfile?) {
        self.profile = profile
    }

    func updateHealthKitBurn(_ burn: Double) {
        self.healthKitBurn = burn
    }

    func todayActivities(for profile: UserProfile) -> [String] {
        let schedule = profile.weeklySchedule
        guard schedule.count == 7 else { return ["rest"] }

        let weekday = Calendar.current.component(.weekday, from: .now)
        let index: Int
        switch weekday {
        case 1: index = 6   // Sunday
        case 2: index = 0   // Monday
        case 3: index = 1
        case 4: index = 2
        case 5: index = 3
        case 6: index = 4
        case 7: index = 5   // Saturday
        default: index = 0
        }
        let activities = schedule[index]
        return activities.isEmpty ? ["rest"] : activities
    }

    static let activityDisplayNames: [String: String] = [
        "weights": "Ağırlık",
        "running": "Koşu",
        "cycling": "Bisiklet",
        "walking": "Yürüyüş",
        "rest": "Dinlenme",
    ]
}
