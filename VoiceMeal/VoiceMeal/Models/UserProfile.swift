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
    var weeklySchedule: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        gender: String,
        age: Int,
        heightCm: Double,
        currentWeightKg: Double,
        goalWeightKg: Double,
        goalDays: Int,
        intensityLevel: Double,
        weeklySchedule: [String]
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
        self.weeklySchedule = weeklySchedule
        self.createdAt = .now
        self.updatedAt = .now
    }
}
