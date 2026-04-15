//
//  GoalEngine.swift
//  VoiceMeal
//

import Foundation

@Observable
class GoalEngine {
    private(set) var profile: UserProfile?
    var healthKitBurn: Double = 0
    var todayMorningTDEE: Double?
    var vo2Max: Double?
    var latestWeightFromHealth: Double?
    var latestWeightDate: Date?
    var isUsingExtrapolatedTDEE: Bool = false
    var isEarlyMorning: Bool = false
    var weightUpdatedBanner: String?

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

    var baseActivityMultiplier: Double {
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

    var vo2MaxAdjustment: Double {
        guard let vo2 = vo2Max else { return 0 }
        switch vo2 {
        case ..<35:
            return -0.05
        case 35..<45:
            return 0
        case 45..<55:
            return 0.05
        default:
            return 0.10
        }
    }

    var activityMultiplier: Double {
        baseActivityMultiplier + vo2MaxAdjustment
    }

    var vo2MaxLevel: String {
        guard let vo2 = vo2Max else { return "Bilinmiyor" }
        switch vo2 {
        case ..<35: return "D\u{00FC}\u{015F}\u{00FC}k"
        case 35..<45: return "Orta"
        case 45..<55: return "\u{0130}yi"
        default: return "M\u{00FC}kemmel"
        }
    }

    var tdeeConfidence: String {
        if isEarlyMorning {
            return "Orta (sabah erken)"
        }
        let hasHealthKit = usingHealthKit || isUsingExtrapolatedTDEE
        let hasVO2 = vo2Max != nil
        if hasHealthKit && hasVO2 {
            return "Y\u{00FC}ksek"
        } else if hasHealthKit || hasVO2 {
            return "Orta"
        } else {
            return "D\u{00FC}\u{015F}\u{00FC}k"
        }
    }

    var calculatedTDEE: Double {
        bmr * activityMultiplier
    }

    var tdee: Double {
        if isUsingExtrapolatedTDEE && healthKitBurn > 0 {
            return healthKitBurn
        }
        return usingHealthKit ? healthKitBurn : calculatedTDEE
    }

    /// Raw daily deficit before safety caps (positive = loss, negative = gain/surplus)
    var rawDailyDeficit: Double {
        guard let p = profile, p.goalDays > 0 else { return 0 }
        let weightDiff = p.currentWeightKg - p.goalWeightKg
        let totalCaloriesNeeded = weightDiff * 7700
        return totalCaloriesNeeded / Double(p.goalDays)
    }

    /// Daily deficit after safety caps
    var cappedDailyDeficit: Double {
        let maxDeficit = tdee * 0.35
        let maxSurplus = tdee * 0.20
        return max(-maxSurplus, min(maxDeficit, rawDailyDeficit))
    }

    var isCapped: Bool {
        abs(rawDailyDeficit - cappedDailyDeficit) > 1
    }

    var capReason: String? {
        guard isCapped else { return nil }
        if rawDailyDeficit > cappedDailyDeficit {
            return "Maksimum a\u{00E7}\u{0131}k s\u{0131}n\u{0131}r\u{0131}na ula\u{015F}\u{0131}ld\u{0131}"
        } else {
            return "Maksimum fazla s\u{0131}n\u{0131}r\u{0131}na ula\u{015F}\u{0131}ld\u{0131}"
        }
    }

    var deficit: Double {
        cappedDailyDeficit
    }

    private var minimumCalorieTarget: Double {
        bmr * 0.85
    }

    var isCalorieClamped: Bool {
        let raw = tdee - deficit
        return deficit > 0 && raw < minimumCalorieTarget && minimumCalorieTarget > 0
    }

    var dailyCalorieTarget: Int {
        let raw = tdee - deficit
        if deficit > 0 {
            return Int(max(raw, minimumCalorieTarget))
        }
        return Int(raw)
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
        (cappedDailyDeficit * 7) / 7700
    }

    var isInBannerWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 17 && hour < 20
    }

    var hasWorkoutToday: Bool {
        let workoutTypes: Set<String> = ["weights", "running", "cycling"]
        return !workoutTypes.isDisjoint(with: todayActivityNames)
    }

    var tdeeDropWarning: Bool {
        guard let morningTDEE = todayMorningTDEE,
              morningTDEE > 0 else { return false }
        let drop = (morningTDEE - tdee) / morningTDEE
        return drop > 0.15 && isInBannerWindow
    }

    var tdeeDropPercent: Int {
        guard let morning = todayMorningTDEE, morning > 0 else { return 0 }
        return Int(((morning - tdee) / morning) * 100)
    }

    var updatedEatingGoalIfAccepted: Int {
        return Int(max(tdee - cappedDailyDeficit, bmr * 0.85))
    }

    func update(with profile: UserProfile?) {
        self.profile = profile
    }

    func updateProfile(_ profile: UserProfile) {
        // Force @Observable notification by clearing and re-setting
        self.profile = nil
        self.profile = profile
        FeedbackService.shared.addLog("TDEE updated: \(Int(tdee)) kcal")
    }

    func updateHealthKitBurn(_ burn: Double) {
        self.healthKitBurn = burn
    }

    func updateExtrapolatedBurn(_ burn: Double) {
        if burn > 0 {
            self.healthKitBurn = burn
            self.isUsingExtrapolatedTDEE = true
        } else {
            self.isUsingExtrapolatedTDEE = false
        }
    }

    func updateVO2Max(_ value: Double?) {
        self.vo2Max = value
    }

    func syncWeight(healthWeight: Double?, healthWeightDate: Date?, profile: UserProfile?) {
        latestWeightFromHealth = healthWeight
        latestWeightDate = healthWeightDate

        guard let weight = healthWeight,
              let weightDate = healthWeightDate,
              let p = profile else {
            return
        }

        if weightDate > p.updatedAt && abs(weight - p.currentWeightKg) > 0.01 {
            let formatted = String(format: "%.1f", weight)
            p.currentWeightKg = weight
            p.updatedAt = .now
            weightUpdatedBanner = "\u{2696}\u{FE0F} Kilonuz g\u{00FC}ncellendi: \(formatted) kg"
        }
    }

    func dismissWeightBanner() {
        weightUpdatedBanner = nil
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

    static var activityDisplayNames: [String: String] {
        [
            "weights": "activity_weights".localized,
            "running": "activity_running".localized,
            "cycling": "activity_cycling".localized,
            "walking": "activity_walking".localized,
            "rest": "activity_rest".localized,
        ]
    }
}
