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
    var createdAt: Date
    var updatedAt: Date

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
        self.createdAt = .now
        self.updatedAt = .now
    }
}
