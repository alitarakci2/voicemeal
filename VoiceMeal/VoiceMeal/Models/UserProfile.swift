//
//  UserProfile.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var gender: String
    var age: Int
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var goalDays: Int
    var intensityLevel: Double
    var weeklyScheduleJSON: String
    var notification1Enabled: Bool
    var notification1Hour: Int
    var notification1Minute: Int
    var notification2Enabled: Bool
    var notification2Hour: Int
    var notification2Minute: Int
    var preferredProteinsJSON: String
    var programStartWeightKg: Double = 0
    var waterGoalOverrideMl: Int?
    var isWaterTrackingEnabled: Bool = false
    var useMetric: Bool = true
    var preferredLanguage: String = ""
    var weightReminderEnabled: Bool = true
    var weightReminderDays: Int = 1
    var weightReminderHour: Int = 9
    var coachStyleRaw: String = CoachStyle.supportive.rawValue
    var createdAt: Date
    var updatedAt: Date

    var coachStyle: CoachStyle {
        get { CoachStyle(rawValue: coachStyleRaw) ?? .supportive }
        set { coachStyleRaw = newValue.rawValue }
    }

    var preferredProteins: [String] {
        get {
            guard let data = preferredProteinsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                preferredProteinsJSON = json
            }
        }
    }

    var weeklySchedule: [[String]] {
        get {
            guard let data = weeklyScheduleJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([[String]].self, from: data) else {
                return Array(repeating: ["rest"], count: 7)
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                weeklyScheduleJSON = json
            }
        }
    }

    init(
        name: String,
        gender: String,
        age: Int,
        heightCm: Double,
        currentWeightKg: Double,
        goalWeightKg: Double,
        goalDays: Int,
        intensityLevel: Double,
        weeklySchedule: [[String]]
    ) {
        self.id = UUID()
        self.name = name
        self.gender = gender
        self.age = age
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.goalDays = goalDays
        self.intensityLevel = intensityLevel
        if let data = try? JSONEncoder().encode(weeklySchedule),
           let json = String(data: data, encoding: .utf8) {
            self.weeklyScheduleJSON = json
        } else {
            self.weeklyScheduleJSON = "[[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"]]"
        }
        self.notification1Enabled = true
        self.notification1Hour = 16
        self.notification1Minute = 0
        self.notification2Enabled = true
        self.notification2Hour = 21
        self.notification2Minute = 30
        let defaultProteins = ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]
        if let data = try? JSONEncoder().encode(defaultProteins),
           let json = String(data: data, encoding: .utf8) {
            self.preferredProteinsJSON = json
        } else {
            self.preferredProteinsJSON = "[]"
        }
        self.createdAt = .now
        self.updatedAt = .now
    }
}
